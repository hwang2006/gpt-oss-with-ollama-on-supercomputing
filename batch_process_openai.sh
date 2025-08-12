#!/bin/bash
# batch_process_openai.sh

MODEL="gpt-oss:latest"
API_URL="http://localhost:11434/v1/chat/completions"

# Read prompts from file
while IFS= read -r prompt; do
    echo "Processing: $prompt"
    
    response=$(curl -s $API_URL \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$MODEL\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
            \"stream\": false
        }" | jq -r '.choices[0].message.content')
    
    echo "Response: $response"
    echo "---"
done < prompts.txt
