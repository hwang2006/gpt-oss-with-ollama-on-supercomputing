import requests
import json

# API endpoint
url = "http://localhost:11434/api/generate"

# Request payload
payload = {
    "model": "gpt-oss:latest",
    "prompt": "What are the benefits of using HPC for AI research?",
    "stream": False
}

# Send request
response = requests.post(url, json=payload)

# Parse and print response
if response.status_code == 200:
    result = response.json()
    print(result['response'])
else:
    print(f"Error: {response.status_code}")
