#!/usr/bin/env python3
# openai_agents_with_litellm.py
# Requires: openai-agents, litellm, requests
# Usage:
#   python openai_agents_with_litellm.py --prompt "What's the weather in Seoul and Tokyo?"

import asyncio
import argparse
import requests
from typing import Dict, Any, Optional
from agents import Agent, Runner, function_tool, set_tracing_disabled
from agents.extensions.models.litellm_model import LitellmModel

# Keep Agents internal tracing quiet
set_tracing_disabled(True)

# --- Simple code -> text map for Open-Meteo weather codes ---
WEATHER_CODE_MAP: Dict[int, str] = {
    0: "Clear", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Depositing rime fog",
    51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
    56: "Light freezing drizzle", 57: "Dense freezing drizzle",
    61: "Light rain", 63: "Moderate rain", 65: "Heavy rain",
    66: "Light freezing rain", 67: "Heavy freezing rain",
    71: "Light snow", 73: "Moderate snow", 75: "Heavy snow",
    77: "Snow grains",
    80: "Light rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
    85: "Light snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm", 96: "Thunderstorm with hail", 99: "Thunderstorm with heavy hail",
}

def _geocode_city(city: str, timeout: int = 10) -> Optional[Dict[str, float]]:
    """Return {'lat': float, 'lon': float, 'name': str, 'country': str} or None."""
    r = requests.get(
        "https://geocoding-api.open-meteo.com/v1/search",
        params={"name": city, "count": 1, "language": "en", "format": "json"},
        timeout=timeout,
    )
    r.raise_for_status()
    data = r.json()
    if not data.get("results"):
        return None
    item = data["results"][0]
    return {
        "lat": item["latitude"],
        "lon": item["longitude"],
        "name": item.get("name", city),
        "country": item.get("country", ""),
    }

def _fetch_current_weather(lat: float, lon: float, timeout: int = 10) -> Dict[str, Any]:
    """Return {'temp_c': float|None, 'code': int|None, 'condition': str}."""
    r = requests.get(
        "https://api.open-meteo.com/v1/forecast",
        params={
            "latitude": lat,
            "longitude": lon,
            "current": "temperature_2m,weather_code",
            "timezone": "auto",
        },
        timeout=timeout,
    )
    r.raise_for_status()
    w = r.json().get("current", {})
    temp = w.get("temperature_2m")
    code = w.get("weather_code")
    return {
        "temp_c": temp,
        "code": code,
        "condition": WEATHER_CODE_MAP.get(code, f"code {code}" if code is not None else "Unknown"),
    }

# --- Tool: get live weather for one city ---
@function_tool
def get_weather(city: str) -> Dict[str, Any]:
    """
    Get current weather for a city (via Open-Meteo).
    Returns a JSON-serializable dict with fields: city, name, country, temp_c, condition, error (optional).
    """
    try:
        geo = _geocode_city(city)
        if not geo:
            return {"city": city, "error": "city not found"}
        wx = _fetch_current_weather(geo["lat"], geo["lon"])
        return {
            "city": city,
            "name": geo["name"],
            "country": geo["country"],
            "temp_c": wx["temp_c"],
            "condition": wx["condition"],
        }
    except requests.Timeout:
        return {"city": city, "error": "timeout"}
    except requests.RequestException as e:
        return {"city": city, "error": f"network error: {e.__class__.__name__}"}
    except Exception as e:
        return {"city": city, "error": f"unexpected error: {e.__class__.__name__}"}

async def main(prompt: str):
    # Point LiteLLM's OpenAI provider at Ollama's OpenAI-compatible endpoint
    model = LitellmModel(
        model="openai/gpt-oss:latest",    # ensure this tag exists in `curl /api/tags`
        base_url="http://localhost:11434/v1",
        api_key="ollama",
        #temperature=0.2,
        #max_tokens=400,                   # optional cap
    )

    agent = Agent(
        name="Weather Assistant",
        instructions=(
            "You are a concise weather assistant. "
            "When asked about weather for one or more cities, ALWAYS call get_weather(city) "
            "for each distinct city mentioned. Then produce a short, readable summary like:\n"
            "- Seoul: 27°C, Partly cloudy\n- Tokyo: 29°C, Clear"
        ),
        model=model,
        tools=[get_weather],
    )

    result = await Runner.run(agent, prompt)
    print(result.final_output)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--prompt",
        type=str,
        default="What's the weather in Seoul and Tokyo right now?",
        help="User prompt to send to the agent.",
    )
    args = parser.parse_args()
    asyncio.run(main(args.prompt))

