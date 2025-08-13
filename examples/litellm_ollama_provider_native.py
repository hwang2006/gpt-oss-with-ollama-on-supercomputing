
# litellm_ollama_provider_native.py
import os, litellm

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
MODEL = "ollama/" + os.getenv("MODEL", "gpt-oss:latest")
PROMPT = os.getenv("PROMPT", "what is quantum computing?")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "128"))
NUM_CTX = int(os.getenv("NUM_CTX", "4096"))

resp = litellm.completion(
    model=MODEL,                      # ollama/<tag>
    api_base=OLLAMA_URL,              # native base (no /v1)
    messages=[{"role": "user", "content": PROMPT}],
    max_tokens=MAX_TOKENS,            # maps to num_predict
    # pass native options through to Ollama:
    extra_body={"options": {"num_ctx": NUM_CTX}},
)

print(resp.choices[0].message["content"])
