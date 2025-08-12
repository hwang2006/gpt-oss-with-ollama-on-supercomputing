# agents_with_litellm.py
import asyncio
from agents import Agent, Runner, function_tool, set_tracing_disabled
from agents.extensions.models.litellm_model import LitellmModel

set_tracing_disabled(True)

@function_tool
def get_weather(city: str):
    """Get the current weather for a city."""
    return f"The weather in {city} is sunny, 22°C."

async def main():
    agent = Agent(
        name="Weather Assistant",
        instructions="You are a helpful weather assistant. Always be concise.",
        model=LitellmModel(
            # Use OpenAI provider against Ollama's OpenAI-compatible API
            model="openai/gpt-oss:latest",          # or "openai/gpt-oss:latest"
            api_key="ollama",                     # dummy
            base_url="http://localhost:11434/v1"  # <-- /v1 matters
        ),
        tools=[get_weather],
    )

    result = await Runner.run(agent, "What's the weather in Seoul and Tokyo?")
    print(result.final_output)

if __name__ == "__main__":
    asyncio.run(main())

