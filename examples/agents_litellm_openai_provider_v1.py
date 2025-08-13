
# agents_litellm_openai_provider_v1.py
import os, asyncio
from agents import Agent, Runner, set_tracing_disabled
from agents.extensions.models.litellm_model import LitellmModel
from agents.model_settings import ModelSettings

set_tracing_disabled(True)

BASE_URL = os.getenv("OPENAI_BASE_URL", "http://localhost:11434/v1")
API_KEY  = os.getenv("OPENAI_API_KEY", "ollama")
MODEL    = "openai/" + os.getenv("MODEL", "gpt-oss:latest")
PROMPT   = os.getenv("PROMPT", "what is quantum computing?")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "128"))

async def main():
    model = LitellmModel(
        model=MODEL,            # e.g., openai/gpt-oss:latest
        base_url=BASE_URL,      # /v1
        api_key=API_KEY,
    )
    ms = ModelSettings(temperature=0.2, max_tokens=MAX_TOKENS)

    agent = Agent(
        name="Explain Agent",
        instructions="Be clear and concise.",
        model=model,
        model_settings=ms,
    )

    result = await Runner.run(agent, PROMPT)
    print(result.final_output)

if __name__ == "__main__":
    asyncio.run(main())
