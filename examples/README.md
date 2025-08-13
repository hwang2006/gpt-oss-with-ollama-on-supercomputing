
# Five Ways to Talk to Ollama (Side‑by‑Side Examples)

This folder contains five **minimal, runnable** examples that all answer the same prompt:
> **"what is quantum computing?"**

They demonstrate the five common paths:
1. **Ollama native – generate** (`/api/generate`)
2. **Ollama native – chat** (`/api/chat`)
3. **OpenAI Python SDK → /v1** (OpenAI‑compatible)
4. **LiteLLM (OpenAI provider) → /v1**
5. **LiteLLM (Ollama provider) → native /api/*`**

---

## Quick start

```bash
# 1) Install deps
pip install -r requirements.txt

# 2) Make sure your Ollama server is running locally
#    and you have a model pulled (e.g., gpt-oss:latest)
curl http://localhost:11434/api/tags

# 3) Run any example via Makefile (or run the scripts directly)
make chat
make generate
make openai
make agents_openai
make litellm_native
```

**Environment variables (optional, with defaults):**
```
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

---

## Files

- `ollama_generate_raw.py` — native `/api/generate` with `raw:true` (exact prompt control)
- `ollama_chat_simple.py` — native `/api/chat` (role-based)
- `openai_client_v1.py` — OpenAI SDK pointed at Ollama `/v1`
- `agents_litellm_openai_provider_v1.py` — Agents SDK via LiteLLM (OpenAI provider) → `/v1`
- `litellm_ollama_provider_native.py` — LiteLLM (Ollama provider) → native `/api/*`
- `requirements.txt` — dependencies for all five
- `Makefile` — convenience targets

---

## Notes

- **Reply length cap**: OpenAI‑style paths use `max_tokens`; native paths use `num_predict`.
- **Context size**: native paths set `options.num_ctx` per request; OpenAI‑style often doesn’t expose this knob.
- **Templates**: native `/api/generate` applies the model’s prompt template unless you set `"raw": true`.
- **Tools/function calling**: prefer OpenAI‑compatible routes (`/v1`).
