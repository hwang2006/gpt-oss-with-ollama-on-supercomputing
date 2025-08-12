# openai_basic.py
from openai import OpenAI

# Configure client to use local Ollama endpoint
client = OpenAI(
    base_url="http://localhost:11434/v1",  # Local Ollama API
    api_key="ollama"                        # Dummy key (required but not used)
)

# Use exactly like OpenAI API
response = client.chat.completions.create(
    model="gpt-oss:latest",  # or "gpt-oss:latest", "gpt-oss:20b"
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain what MXFP4 quantization is."}
    ]
)

print(response.choices[0].message.content)
