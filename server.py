"""
Claude Code Local Proxy Server
================================
A local proxy that bridges Claude Code CLI with any OpenAI-compatible API,
and integrates with openclaw / workbuddy services.

Usage:
    python server.py

Then run Claude Code with:
    ANTHROPIC_BASE_URL=http://localhost:8082 claude
"""

import os
import json
import time
import uuid
import httpx
import asyncio
import logging
from typing import Any, AsyncIterator, Optional
from fastapi import FastAPI, Request, HTTPException, Header
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import uvicorn

load_dotenv()

# ─── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# ─── Configuration ────────────────────────────────────────────────────────────
PROXY_PORT = int(os.getenv("PROXY_PORT", "8082"))
PROXY_HOST = os.getenv("PROXY_HOST", "0.0.0.0")

# Backend provider: "anthropic" | "openai" | "openclaw" | "workbuddy"
PREFERRED_PROVIDER = os.getenv("PREFERRED_PROVIDER", "anthropic")

# API Keys
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

# OpenClaw integration
OPENCLAW_BASE_URL = os.getenv("OPENCLAW_BASE_URL", "http://localhost:3000")
OPENCLAW_GATEWAY_TOKEN = os.getenv("OPENCLAW_GATEWAY_TOKEN", "")

# WorkBuddy integration
WORKBUDDY_BASE_URL = os.getenv("WORKBUDDY_BASE_URL", "http://localhost:4000")
WORKBUDDY_API_KEY = os.getenv("WORKBUDDY_API_KEY", "")

# Model mapping
BIG_MODEL = os.getenv("BIG_MODEL", "claude-sonnet-4-5")
SMALL_MODEL = os.getenv("SMALL_MODEL", "claude-haiku-4-5")

# OpenAI-compatible endpoint (for local models via Ollama/LM Studio)
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")

# ─── Model Aliases ────────────────────────────────────────────────────────────
CLAUDE_MODEL_ALIASES = {
    # Haiku → small model
    "claude-haiku": SMALL_MODEL,
    "claude-3-haiku-20240307": SMALL_MODEL,
    "claude-3-5-haiku-20241022": SMALL_MODEL,
    "claude-haiku-4-5": SMALL_MODEL,
    # Sonnet → big model
    "claude-sonnet": BIG_MODEL,
    "claude-3-5-sonnet-20241022": BIG_MODEL,
    "claude-3-7-sonnet-20250219": BIG_MODEL,
    "claude-sonnet-4-5": BIG_MODEL,
    # Opus
    "claude-opus": "claude-opus-4-5",
    "claude-3-opus-20240229": "claude-opus-4-5",
}

app = FastAPI(
    title="Claude Code Local Proxy",
    description="Local proxy for Claude Code CLI — bridges Anthropic API with OpenClaw, WorkBuddy, and any OpenAI-compatible backend.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Helpers ──────────────────────────────────────────────────────────────────

def resolve_model(model: str) -> str:
    """Resolve Claude model alias to actual model name."""
    return CLAUDE_MODEL_ALIASES.get(model, model)


def anthropic_to_openai_messages(messages: list[dict]) -> list[dict]:
    """Convert Anthropic message format to OpenAI format."""
    openai_messages = []
    for msg in messages:
        role = msg.get("role", "user")
        content = msg.get("content", "")
        if isinstance(content, str):
            openai_messages.append({"role": role, "content": content})
        elif isinstance(content, list):
            # Handle content blocks (text, image, tool_use, tool_result)
            text_parts = []
            for block in content:
                if isinstance(block, dict):
                    if block.get("type") == "text":
                        text_parts.append(block.get("text", ""))
                    elif block.get("type") == "tool_result":
                        text_parts.append(f"[Tool result: {json.dumps(block.get('content', ''))}]")
                    elif block.get("type") == "tool_use":
                        text_parts.append(f"[Tool call: {block.get('name', '')}({json.dumps(block.get('input', {}))})]")
            openai_messages.append({"role": role, "content": "\n".join(text_parts)})
    return openai_messages


def openai_to_anthropic_response(openai_resp: dict, model: str) -> dict:
    """Convert OpenAI response to Anthropic format."""
    choice = openai_resp.get("choices", [{}])[0]
    message = choice.get("message", {})
    content_text = message.get("content", "")
    usage = openai_resp.get("usage", {})
    return {
        "id": f"msg_{uuid.uuid4().hex[:24]}",
        "type": "message",
        "role": "assistant",
        "content": [{"type": "text", "text": content_text}],
        "model": model,
        "stop_reason": "end_turn",
        "stop_sequence": None,
        "usage": {
            "input_tokens": usage.get("prompt_tokens", 0),
            "output_tokens": usage.get("completion_tokens", 0),
        },
    }


async def stream_openai_to_anthropic(response: httpx.Response, model: str) -> AsyncIterator[str]:
    """Stream OpenAI SSE response converted to Anthropic SSE format."""
    msg_id = f"msg_{uuid.uuid4().hex[:24]}"
    input_tokens = 0
    output_tokens = 0

    # message_start
    yield f"event: message_start\ndata: {json.dumps({'type': 'message_start', 'message': {'id': msg_id, 'type': 'message', 'role': 'assistant', 'content': [], 'model': model, 'stop_reason': None, 'stop_sequence': None, 'usage': {'input_tokens': 0, 'output_tokens': 0}}})}\n\n"
    # content_block_start
    yield f"event: content_block_start\ndata: {json.dumps({'type': 'content_block_start', 'index': 0, 'content_block': {'type': 'text', 'text': ''}})}\n\n"
    # ping
    yield f"event: ping\ndata: {json.dumps({'type': 'ping'})}\n\n"

    async for line in response.aiter_lines():
        if not line.startswith("data: "):
            continue
        data_str = line[6:]
        if data_str.strip() == "[DONE]":
            break
        try:
            data = json.loads(data_str)
        except json.JSONDecodeError:
            continue

        choice = data.get("choices", [{}])[0]
        delta = choice.get("delta", {})
        text = delta.get("content", "")
        finish_reason = choice.get("finish_reason")

        if text:
            output_tokens += 1
            yield f"event: content_block_delta\ndata: {json.dumps({'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'text_delta', 'text': text}})}\n\n"

        if finish_reason:
            usage_data = data.get("usage", {})
            input_tokens = usage_data.get("prompt_tokens", input_tokens)
            output_tokens = usage_data.get("completion_tokens", output_tokens)

    yield f"event: content_block_stop\ndata: {json.dumps({'type': 'content_block_stop', 'index': 0})}\n\n"
    yield f"event: message_delta\ndata: {json.dumps({'type': 'message_delta', 'delta': {'stop_reason': 'end_turn', 'stop_sequence': None}, 'usage': {'output_tokens': output_tokens}})}\n\n"
    yield f"event: message_stop\ndata: {json.dumps({'type': 'message_stop'})}\n\n"


# ─── Route: Health Check ──────────────────────────────────────────────────────

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "provider": PREFERRED_PROVIDER,
        "version": "1.0.0",
        "integrations": {
            "openclaw": bool(OPENCLAW_GATEWAY_TOKEN),
            "workbuddy": bool(WORKBUDDY_API_KEY),
        },
    }


@app.get("/")
async def root():
    return {
        "name": "Claude Code Local Proxy",
        "description": "Local proxy for Claude Code CLI",
        "endpoints": {
            "messages": "POST /v1/messages",
            "models": "GET /v1/models",
            "health": "GET /health",
            "openclaw_status": "GET /integrations/openclaw/status",
            "workbuddy_status": "GET /integrations/workbuddy/status",
        },
    }


# ─── Route: Models ────────────────────────────────────────────────────────────

@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [
            {"id": "claude-sonnet-4-5", "object": "model", "created": 1700000000, "owned_by": "anthropic"},
            {"id": "claude-haiku-4-5", "object": "model", "created": 1700000000, "owned_by": "anthropic"},
            {"id": "claude-opus-4-5", "object": "model", "created": 1700000000, "owned_by": "anthropic"},
            {"id": "claude-3-5-sonnet-20241022", "object": "model", "created": 1700000000, "owned_by": "anthropic"},
            {"id": "claude-3-5-haiku-20241022", "object": "model", "created": 1700000000, "owned_by": "anthropic"},
        ],
    }


# ─── Route: Messages (Main Proxy) ─────────────────────────────────────────────

@app.post("/v1/messages")
async def create_message(request: Request):
    body = await request.json()
    model = resolve_model(body.get("model", BIG_MODEL))
    stream = body.get("stream", False)
    messages = body.get("messages", [])
    system = body.get("system", "")
    max_tokens = body.get("max_tokens", 8096)
    temperature = body.get("temperature", 1.0)
    tools = body.get("tools", [])

    logger.info(f"[{PREFERRED_PROVIDER}] model={model} stream={stream} messages={len(messages)}")

    if PREFERRED_PROVIDER == "anthropic":
        return await _proxy_to_anthropic(body, stream, request)
    elif PREFERRED_PROVIDER == "openclaw":
        return await _proxy_to_openclaw(body, model, messages, system, max_tokens, temperature, stream)
    elif PREFERRED_PROVIDER == "workbuddy":
        return await _proxy_to_workbuddy(body, model, messages, system, max_tokens, temperature, stream)
    else:
        # Default: OpenAI-compatible
        return await _proxy_to_openai(body, model, messages, system, max_tokens, temperature, stream, tools)


async def _proxy_to_anthropic(body: dict, stream: bool, request: Request):
    """Pass through to Anthropic API directly."""
    if not ANTHROPIC_API_KEY:
        raise HTTPException(status_code=401, detail="ANTHROPIC_API_KEY not configured")

    headers = {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
        "anthropic-beta": "interleaved-thinking-2025-05-14,max-tokens-3-5-sonnet-2024-07-15",
    }

    async with httpx.AsyncClient(timeout=300) as client:
        if stream:
            async def gen():
                async with client.stream(
                    "POST",
                    "https://api.anthropic.com/v1/messages",
                    headers=headers,
                    json=body,
                ) as resp:
                    async for chunk in resp.aiter_bytes():
                        yield chunk
            return StreamingResponse(gen(), media_type="text/event-stream")
        else:
            resp = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers=headers,
                json=body,
            )
            return JSONResponse(content=resp.json(), status_code=resp.status_code)


async def _proxy_to_openai(
    body: dict, model: str, messages: list, system: str,
    max_tokens: int, temperature: float, stream: bool, tools: list
):
    """Proxy to OpenAI-compatible API (also works with Ollama, LM Studio)."""
    if not OPENAI_API_KEY and "localhost" not in OPENAI_BASE_URL:
        raise HTTPException(status_code=401, detail="OPENAI_API_KEY not configured")

    openai_messages = []
    if system:
        openai_messages.append({"role": "system", "content": system})
    openai_messages.extend(anthropic_to_openai_messages(messages))

    openai_body = {
        "model": model,
        "messages": openai_messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": stream,
    }

    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=300) as client:
        if stream:
            async def gen():
                async with client.stream(
                    "POST",
                    f"{OPENAI_BASE_URL}/chat/completions",
                    headers=headers,
                    json=openai_body,
                ) as resp:
                    async for chunk in stream_openai_to_anthropic(resp, model):
                        yield chunk.encode()
            return StreamingResponse(gen(), media_type="text/event-stream")
        else:
            resp = await client.post(
                f"{OPENAI_BASE_URL}/chat/completions",
                headers=headers,
                json=openai_body,
            )
            return JSONResponse(content=openai_to_anthropic_response(resp.json(), model))


async def _proxy_to_openclaw(
    body: dict, model: str, messages: list, system: str,
    max_tokens: int, temperature: float, stream: bool
):
    """Proxy to OpenClaw gateway API."""
    if not OPENCLAW_GATEWAY_TOKEN:
        raise HTTPException(status_code=401, detail="OPENCLAW_GATEWAY_TOKEN not configured")

    headers = {
        "Authorization": f"Bearer {OPENCLAW_GATEWAY_TOKEN}",
        "Content-Type": "application/json",
    }

    # OpenClaw uses OpenAI-compatible API format
    openai_messages = []
    if system:
        openai_messages.append({"role": "system", "content": system})
    openai_messages.extend(anthropic_to_openai_messages(messages))

    openclaw_body = {
        "model": model,
        "messages": openai_messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": stream,
    }

    async with httpx.AsyncClient(timeout=300) as client:
        if stream:
            async def gen():
                async with client.stream(
                    "POST",
                    f"{OPENCLAW_BASE_URL}/v1/chat/completions",
                    headers=headers,
                    json=openclaw_body,
                ) as resp:
                    async for chunk in stream_openai_to_anthropic(resp, model):
                        yield chunk.encode()
            return StreamingResponse(gen(), media_type="text/event-stream")
        else:
            resp = await client.post(
                f"{OPENCLAW_BASE_URL}/v1/chat/completions",
                headers=headers,
                json=openclaw_body,
            )
            return JSONResponse(content=openai_to_anthropic_response(resp.json(), model))


async def _proxy_to_workbuddy(
    body: dict, model: str, messages: list, system: str,
    max_tokens: int, temperature: float, stream: bool
):
    """Proxy to WorkBuddy API."""
    if not WORKBUDDY_API_KEY:
        raise HTTPException(status_code=401, detail="WORKBUDDY_API_KEY not configured")

    headers = {
        "X-API-Key": WORKBUDDY_API_KEY,
        "Content-Type": "application/json",
    }

    openai_messages = []
    if system:
        openai_messages.append({"role": "system", "content": system})
    openai_messages.extend(anthropic_to_openai_messages(messages))

    workbuddy_body = {
        "model": model,
        "messages": openai_messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": stream,
    }

    async with httpx.AsyncClient(timeout=300) as client:
        if stream:
            async def gen():
                async with client.stream(
                    "POST",
                    f"{WORKBUDDY_BASE_URL}/v1/chat/completions",
                    headers=headers,
                    json=workbuddy_body,
                ) as resp:
                    async for chunk in stream_openai_to_anthropic(resp, model):
                        yield chunk.encode()
            return StreamingResponse(gen(), media_type="text/event-stream")
        else:
            resp = await client.post(
                f"{WORKBUDDY_BASE_URL}/v1/chat/completions",
                headers=headers,
                json=workbuddy_body,
            )
            return JSONResponse(content=openai_to_anthropic_response(resp.json(), model))


# ─── Integration Status Routes ────────────────────────────────────────────────

@app.get("/integrations/openclaw/status")
async def openclaw_status():
    """Check OpenClaw gateway connectivity."""
    if not OPENCLAW_GATEWAY_TOKEN:
        return {"status": "not_configured", "message": "OPENCLAW_GATEWAY_TOKEN not set"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"{OPENCLAW_BASE_URL}/health",
                headers={"Authorization": f"Bearer {OPENCLAW_GATEWAY_TOKEN}"},
            )
            return {"status": "connected", "url": OPENCLAW_BASE_URL, "response": resp.status_code}
    except Exception as e:
        return {"status": "error", "url": OPENCLAW_BASE_URL, "error": str(e)}


@app.get("/integrations/workbuddy/status")
async def workbuddy_status():
    """Check WorkBuddy API connectivity."""
    if not WORKBUDDY_API_KEY:
        return {"status": "not_configured", "message": "WORKBUDDY_API_KEY not set"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"{WORKBUDDY_BASE_URL}/health",
                headers={"X-API-Key": WORKBUDDY_API_KEY},
            )
            return {"status": "connected", "url": WORKBUDDY_BASE_URL, "response": resp.status_code}
    except Exception as e:
        return {"status": "error", "url": WORKBUDDY_BASE_URL, "error": str(e)}


# ─── OpenClaw Webhook (receive messages from OpenClaw) ────────────────────────

@app.post("/webhooks/openclaw")
async def openclaw_webhook(request: Request):
    """Receive webhook events from OpenClaw gateway."""
    body = await request.json()
    logger.info(f"OpenClaw webhook received: {json.dumps(body)[:200]}")
    # Process incoming messages from OpenClaw channels
    event_type = body.get("type", "")
    if event_type == "message":
        channel = body.get("channel", "")
        text = body.get("text", "")
        logger.info(f"Message from OpenClaw [{channel}]: {text[:100]}")
    return {"status": "ok", "received": True}


# ─── WorkBuddy Webhook ────────────────────────────────────────────────────────

@app.post("/webhooks/workbuddy")
async def workbuddy_webhook(request: Request):
    """Receive webhook events from WorkBuddy."""
    body = await request.json()
    logger.info(f"WorkBuddy webhook received: {json.dumps(body)[:200]}")
    return {"status": "ok", "received": True}


# ─── Entry Point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    logger.info(f"Starting Claude Code Local Proxy on {PROXY_HOST}:{PROXY_PORT}")
    logger.info(f"Provider: {PREFERRED_PROVIDER}")
    logger.info(f"OpenClaw: {OPENCLAW_BASE_URL} (token: {'set' if OPENCLAW_GATEWAY_TOKEN else 'not set'})")
    logger.info(f"WorkBuddy: {WORKBUDDY_BASE_URL} (key: {'set' if WORKBUDDY_API_KEY else 'not set'})")
    uvicorn.run(app, host=PROXY_HOST, port=PROXY_PORT, log_level="info")
