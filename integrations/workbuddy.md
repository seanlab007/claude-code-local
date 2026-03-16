# WorkBuddy Integration Guide

This proxy integrates with WorkBuddy — your local AI work assistant service.

## Setup

### 1. Start WorkBuddy

Make sure your WorkBuddy service is running locally (default port: 4000).

WorkBuddy should expose an OpenAI-compatible API endpoint:
```
POST http://localhost:4000/v1/chat/completions
```

### 2. Configure This Proxy

In `.env`:
```env
PREFERRED_PROVIDER=workbuddy
WORKBUDDY_BASE_URL=http://localhost:4000
WORKBUDDY_API_KEY=your-workbuddy-api-key
```

### 3. Start the Proxy

```bash
python server.py
```

### 4. Use Claude Code

```bash
ANTHROPIC_BASE_URL=http://localhost:8082 claude
```

## WorkBuddy API Requirements

WorkBuddy must implement the OpenAI Chat Completions API:

```
POST /v1/chat/completions
Authorization: X-API-Key: <your-key>

{
  "model": "...",
  "messages": [...],
  "stream": true/false
}
```

## Check Status

```bash
curl http://localhost:8082/integrations/workbuddy/status
```
