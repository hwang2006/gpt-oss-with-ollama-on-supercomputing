# openai_tool_use.py
from openai import OpenAI
import json

client = OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="ollama"
)

# Define available tools
tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather in a given city",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "City name"}
                },
                "required": ["city"]
            },
        },
    }
]

# Make request with tools
response = client.chat.completions.create(
    model="gpt-oss:latest",
    messages=[{"role": "user", "content": "What's the weather in Seoul right now?"}],
    tools=tools,
    tool_choice="auto"
)

# Check if the model wants to call a function
message = response.choices[0].message
if message.tool_calls:
    for tool_call in message.tool_calls:
        if tool_call.function.name == "get_weather":
            # Parse arguments and call your function
            args = json.loads(tool_call.function.arguments)
            # weather_result = get_weather(args["city"])
            
            # Send the result back to the model
            follow_up = client.chat.completions.create(
                model="gpt-oss:latest",
                messages=[
                    {"role": "user", "content": "What's the weather in Seoul right now?"},
                    message,
                    {
                        "role": "tool",
                        "tool_call_id": tool_call.id,
                        "content": "The weather in Seoul is sunny, 22°C"
                    }
                ]
            )
            print(follow_up.choices[0].message.content)
