#!/bin/bash
# batch_inference.sh

MODEL="gpt-oss:latest"
API_URL="http://localhost:11434/api/generate"

# Read prompts from file
while IFS= read -r prompt; do
  echo "Processing: $prompt"
  response=$(curl -s $API_URL -d "{
    \"model\": \"$MODEL\",
    \"prompt\": \"$prompt\",
    \"stream\": false
  }" | jq -r '.response')
  echo "Response: $response"
  echo "---"
done < prompts.txt
