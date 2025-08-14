# ===== Config =====
MODEL := gpt-oss:latest
PROMPT := what is quantum computing?
NUM_CTX := 4096
NUM_PREDICT := 128

# OpenAI-compatible (Ollama /v1)
OPENAI_BASE_URL := http://localhost:11434/v1
OPENAI_API_KEY := ollama

# Ollama native
OLLAMA_URL := http://localhost:11434

export MODEL PROMPT NUM_CTX NUM_PREDICT OPENAI_BASE_URL OPENAI_API_KEY OLLAMA_URL

# ===== Phony targets =====
.PHONY: help all chat generate openai agents_openai litellm_native

# Set the default target when `make` is run without arguments.
# In this case, running just `make` will execute the `help` target,
# which prints usage info, environment variables, and available targets. 
.DEFAULT_GOAL := help

help: ## Show this help message (list targets & descriptions)
	@echo "Usage: make <target>"
	@echo
	@echo "Environment (exported):"
	@printf "  %-18s = %s\n" "MODEL" "$(MODEL)"
	@printf "  %-18s = %s\n" "PROMPT" "$(PROMPT)"
	@printf "  %-18s = %s\n" "NUM_CTX" "$(NUM_CTX)"
	@printf "  %-18s = %s\n" "NUM_PREDICT" "$(NUM_PREDICT)"
	@printf "  %-18s = %s\n" "OPENAI_BASE_URL" "$(OPENAI_BASE_URL)"
	@printf "  %-18s = %s\n" "OPENAI_API_KEY" "$(OPENAI_API_KEY)"
	@printf "  %-18s = %s\n" "OLLAMA_URL" "$(OLLAMA_URL)"
	@echo
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*##"; ORS="";} \
          /^[a-zA-Z0-9_\-]+:.*##/ { \
            printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 \
          }' $(MAKEFILE_LIST)
	@echo

all: chat generate openai agents_openai litellm_native ## Run all example targets

chat: ## Run simple chat example via Ollama native API
	python ollama_chat_simple.py

generate: ## Run raw generate example via Ollama native API
	python ollama_generate_raw.py

openai: ## Run OpenAI SDK example against Ollama /v1 endpoint
	python openai_client_v1.py

agents_openai: ## Run litellm (OpenAI provider) OpenAI agent example against /v1
	python agents_litellm_openai_provider_v1.py

litellm_native: ## Run litellm (Ollama provider) example against native API
	python litellm_ollama_provider_native.py
