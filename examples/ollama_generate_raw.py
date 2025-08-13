
# ollama_generate_raw.py
import os, requests

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
MODEL = os.getenv("MODEL", "gpt-oss:latest")
PROMPT = os.getenv("PROMPT", "what is quantum computing?")
NUM_CTX = int(os.getenv("NUM_CTX", "4096"))
NUM_PREDICT = int(os.getenv("NUM_PREDICT", "128"))

resp = requests.post(
    f"{OLLAMA_URL}/api/generate",
    json={
        "model": MODEL,
        "prompt": PROMPT,
        "num_predict": NUM_PREDICT,
        "options": {"num_ctx": NUM_CTX},
        "raw": True,     # skip model's prompt template
        "stream": False
    },
    timeout=600,
)
resp.raise_for_status()
print(resp.json()["response"])
