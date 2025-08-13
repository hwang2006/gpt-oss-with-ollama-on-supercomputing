# Five Ways to Talk to Ollama (Side-by-Side Examples)

This folder contains five **minimal, runnable** examples that all answer the same prompt:
> **"what is quantum computing?"**

They demonstrate the five common paths:

1. **Ollama native – generate** (`/api/generate`)
2. **Ollama native – chat** (`/api/chat`)
3. **OpenAI Python SDK → /v1** (OpenAI-compatible)
4. **LiteLLM (OpenAI provider) → /v1**
5. **LiteLLM (Ollama provider) → native `/api/*`**

## Quick Start

```bash
# 1) make sure the virtual environments (e.g., ollama-hpc) is activated
(ollama-hpc) [glogin01]$ ls
./   agents_litellm_openai_provider_v1.py  Makefile               ollama_generate_raw.py  README.md
../  litellm_ollama_provider_native.py     ollama_chat_simple.py  openai_client_v1.py

# 2) Make sure your Ollama server is running locally
#    and you have a model pulled (e.g., gpt-oss:latest)
(ollama-hpc) [glogin01]$ curl http://localhost:11434/api/tags

# 3) Run any example via Makefile (or run the scripts directly)
(ollama-hpc) [glogin01]$ make chat
(ollama-hpc) [glogin01]$ make generate
(ollama-hpc) [glogin01]$ make openai
(ollama-hpc) [glogin01]$ make agents_openai
(ollama-hpc) [glogin01]$ make litellm_native
```



## Environment Variables (Optional, with Defaults)

```ini
MODEL=gpt-oss:latest
PROMPT="what is quantum computing?"
NUM_CTX=4096
NUM_PREDICT=128

# OpenAI-compatible base (Ollama):
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_API_KEY=ollama

# Native base:
OLLAMA_URL=http://localhost:11434
```

## Files

- `ollama_generate_raw.py` — native /api/generate with raw:true (exact prompt control)
- `ollama_chat_simple.py` — native /api/chat (role-based)
- `openai_client_v1.py` — OpenAI SDK → /v1
- `agents_litellm_openai_provider_v1.py` — Agents SDK via LiteLLM (OpenAI provider) → /v1
- `litellm_ollama_provider_native.py` — LiteLLM (Ollama provider) → native /api/*
- `Makefile` — convenience targets

## The 5 Ways (What/When/How)

| # | Path | Endpoint | Library you call | Input shape | Length cap | Context size | Tools / Function calling | Best for |
|---|------|----------|-----------------|-------------|------------|--------------|-------------------------|----------|
| 1 | Ollama native – generate | /api/generate | requests (HTTP) | `prompt: str` | `num_predict` | `options.num_ctx` | ❌ native API | Exact prompt control (use raw:true), benchmarks, RAG |
| 2 | Ollama native – chat | /api/chat | requests (HTTP) | `messages: [{role, content}]` | `num_predict` | `options.num_ctx` | ❌ native API | Multi-turn chats with roles, still with native knobs |
| 3 | OpenAI Python SDK → /v1 | /v1/* | openai | `messages: [...]` | `max_tokens` | (not exposed; backend default) | ✅ OpenAI schema | Max compatibility with OpenAI-style apps/agents |
| 4 | LiteLLM (OpenAI provider) → /v1 | /v1/* | litellm (or Agents SDK LitellmModel) | `messages: [...]` | `max_tokens` | (not exposed; backend default) | ✅ OpenAI schema | Using frameworks (Agents, LangChain) that speak OpenAI |
| 5 | LiteLLM (Ollama provider) → native | /api/* | litellm | `messages: [...] (mapped)` | `max_tokens → num_predict` | `via extra_body: {"options":{"num_ctx":...}}` | ⚠️ mixed (provider-specific) | OpenAI-like ergonomics plus native knobs |

**Tip:** For tools/function calling, prefer #3 or #4.
For full native controls like `num_ctx`, prefer #1, #2, or #5 (using `extra_body`).

## Parameter Name Mapping (Handy)

### Reply Length
- **Native (#1/#2/#5 native-path):** `num_predict`
- **OpenAI-style (#3/#4):** `max_tokens`

### Context Window
- **Native (#1/#2):** `options.num_ctx`
- **OpenAI-style (#3/#4):** usually not exposed; use native path or a custom Modelfile if you must enforce it
- **LiteLLM Ollama provider (#5):** `extra_body={"options":{"num_ctx": ...}}`

### Templating
- `/api/generate` defaults to applying the model's prompt template; use `"raw": true` to bypass
- `/api/chat` applies the chat template based on roles
- `/v1` follows OpenAI's schema; templating is handled by Ollama's OpenAI-compat layer

## Minimal File Names in This Folder

- **#1** `ollama_generate_raw.py` — native generate w/ raw:true
- **#2** `ollama_chat_simple.py` — native chat
- **#3** `openai_client_v1.py` — OpenAI SDK → /v1
- **#4** `agents_litellm_openai_provider_v1.py` — LiteLLM (OpenAI provider) → /v1
- **#5** `litellm_ollama_provider_native.py` — LiteLLM (Ollama provider) → native /api/*

## Quick Decision Guide

- **I need tools/function calling & plug-and-play with OpenAI-style code.** → #3 or #4
- **I must control `num_ctx`, `keep_alive`, `raw`, or benchmark exact timings.** → #1 (generate+raw) or #2 (chat), or #5 with `extra_body`
- **I want OpenAI ergonomics but still set native options sometimes.** → #5
- **I hit LiteLLM/Ollama quirks.** → Fall back to #3 (OpenAI SDK → /v1) or pure native (#1/#2)

## Notes

- **Reply length cap:** OpenAI-style paths use `max_tokens`; native paths use `num_predict`.
- **Context size:** native paths set `options.num_ctx` per request; OpenAI-style often doesn't expose this knob.
- **Templates:** native `/api/generate` applies the model's prompt template unless you set `"raw": true`.
- **Tools/function calling:** prefer OpenAI-compatible routes (`/v1`).

## Troubleshooting

### Model Not Found (404/400)
Pull it first:
```bash
curl http://localhost:11434/api/pull -d '{"name":"gpt-oss:latest"}'
```

### API Not Reachable
Confirm base URLs and any SSH tunneling/port-forwarding.

### Slow First Reply
Cold load; warm the model and keep it resident:
```bash
curl http://localhost:11434/api/generate -d '{"model":"gpt-oss:latest","prompt":"","raw":true,"keep_alive":"30m","stream":false}'
```

### Check If Model Is Loaded
```bash
curl -s http://localhost:11434/api/ps | jq
```

### GPU Memory Pressure
Lower `NUM_CTX`, use a smaller quant, or stop other models: `ollama stop <model>`
