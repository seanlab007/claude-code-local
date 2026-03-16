# OpenClaw Integration Guide

This proxy integrates with [OpenClaw](https://github.com/seanlab007/open-claw) — your personal AI assistant gateway.

## How It Works

```
Claude Code CLI
      │
      ▼  (ANTHROPIC_BASE_URL=http://localhost:8082)
Claude Code Local Proxy  ←──── this project
      │
      ├─── PREFERRED_PROVIDER=anthropic ──► Anthropic API
      ├─── PREFERRED_PROVIDER=openai ─────► OpenAI / Ollama / LM Studio
      ├─── PREFERRED_PROVIDER=openclaw ───► OpenClaw Gateway (port 3000)
      └─── PREFERRED_PROVIDER=workbuddy ──► WorkBuddy (port 4000)
```

## Setup

### 1. Configure OpenClaw

In your OpenClaw `.env` or `~/.openclaw/.env`:

```env
ANTHROPIC_API_KEY=sk-ant-your-key
# or
OPENAI_API_KEY=sk-your-openai-key
```

Make sure OpenClaw gateway is running:
```bash
cd /path/to/open-claw
pnpm install
pnpm start
# Gateway runs at http://localhost:3000
```

### 2. Configure This Proxy

In `.env`:
```env
PREFERRED_PROVIDER=openclaw
OPENCLAW_BASE_URL=http://localhost:3000
OPENCLAW_GATEWAY_TOKEN=your-openclaw-gateway-token
```

### 3. Start the Proxy

```bash
# Python
python server.py

# Docker
docker compose up -d
```

### 4. Use Claude Code

```bash
ANTHROPIC_BASE_URL=http://localhost:8082 claude
```

## Webhook Integration

The proxy exposes a webhook endpoint for OpenClaw to push messages:

```
POST http://localhost:8082/webhooks/openclaw
```

Configure in OpenClaw's `openclaw.json`:
```json
{
  "webhooks": [
    {
      "url": "http://localhost:8082/webhooks/openclaw",
      "events": ["message", "tool_call"]
    }
  ]
}
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/messages` | POST | Claude Code messages (Anthropic format) |
| `/v1/models` | GET | List available models |
| `/health` | GET | Proxy health check |
| `/integrations/openclaw/status` | GET | OpenClaw connectivity |
| `/integrations/workbuddy/status` | GET | WorkBuddy connectivity |
| `/webhooks/openclaw` | POST | Receive OpenClaw events |
| `/webhooks/workbuddy` | POST | Receive WorkBuddy events |
