#!/usr/bin/env python3
# health_check.py

import requests
import time
from datetime import datetime

def check_ollama_health():
    """Check if Ollama services are healthy."""
    checks = {
        "Ollama API": "http://localhost:11434/api/tags",
        "OpenAI Compatibility": "http://localhost:11434/v1/models"
    }
    
    for service, url in checks.items():
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                print(f"✅ {service}: Healthy")
            else:
                print(f"⚠️ {service}: Status {response.status_code}")
        except requests.exceptions.RequestException as e:
            print(f"❌ {service}: {str(e)}")
    
    # Test model responsiveness
    try:
        response = requests.post(
            "http://localhost:11434/v1/chat/completions",
            json={
                "model": "gpt-oss:120b",
                "messages": [{"role": "user", "content": "test"}],
                "max_tokens": 1
            },
            timeout=10
        )
        if response.status_code == 200:
            print(f"✅ Model Response: Working")
        else:
            print(f"⚠️ Model Response: Status {response.status_code}")
    except Exception as e:
        print(f"❌ Model Response: {str(e)}")

if __name__ == "__main__":
    print(f"Health Check - {datetime.now()}")
    print("-" * 40)
    check_ollama_health()
