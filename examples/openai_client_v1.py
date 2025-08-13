
# openai_client_v1.py
import os
from openai import OpenAI

BASE_URL = os.getenv("OPENAI_BASE_URL", "http://localhost:11434/v1")
API_KEY = os.getenv("OPENAI_API_KEY", "ollama")
MODEL = os.getenv("MODEL", "gpt-oss:latest")
PROMPT = os.getenv("PROMPT", "what is quantum computing?")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "128"))

client = OpenAI(base_url=BASE_URL, api_key=API_KEY)

resp = client.chat.completions.create(
    model=MODEL,
    messages=[{"role": "user", "content": PROMPT}],
    max_tokens=MAX_TOKENS,
)
print(resp.choices[0].message.content)
