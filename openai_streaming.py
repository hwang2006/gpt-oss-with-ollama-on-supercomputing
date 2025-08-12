# openai_streaming.py
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="ollama"
)

# Stream responses like with OpenAI
stream = client.chat.completions.create(
    model="gpt-oss:latest",
    messages=[{"role": "user", "content": "Write a story about a supercomputer"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content is not None:
        print(chunk.choices[0].delta.content, end="")
