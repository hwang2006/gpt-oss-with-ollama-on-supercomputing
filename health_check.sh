#!/bin/bash
# health_check.sh

check_ollama() {
    if curl -s --max-time 5 http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "✅ Ollama API is healthy"
        return 0
    else
        echo "❌ Ollama API is not responding"
        return 1
    fi
}

# Run health check
check_ollama
