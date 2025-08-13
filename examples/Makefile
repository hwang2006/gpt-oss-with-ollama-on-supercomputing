
# Simple runners for the five examples

MODEL ?= gpt-oss:latest
PROMPT ?= what is quantum computing?
NUM_CTX ?= 4096
NUM_PREDICT ?= 128

OPENAI_BASE_URL ?= http://localhost:11434/v1
OPENAI_API_KEY ?= ollama

OLLAMA_URL ?= http://localhost:11434

export MODEL PROMPT NUM_CTX NUM_PREDICT OPENAI_BASE_URL OPENAI_API_KEY OLLAMA_URL

.PHONY: all chat generate openai agents_openai litellm_native

all: chat generate openai agents_openai litellm_native

chat:
\tpython ollama_chat_simple.py

generate:
\tpython ollama_generate_raw.py

openai:
\tpython openai_client_v1.py

agents_openai:
\tpython agents_litellm_openai_provider_v1.py

litellm_native:
\tpython litellm_ollama_provider_native.py
