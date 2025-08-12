# batch_process.py
import asyncio
from openai import AsyncOpenAI
import aiofiles

async def process_prompt(client, prompt, model="gpt-oss:120b"):
    """Process a single prompt asynchronously."""
    try:
        response = await client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7
        )
        return prompt, response.choices[0].message.content
    except Exception as e:
        return prompt, f"Error: {str(e)}"

async def batch_process(prompts_file, output_file):
    """Process multiple prompts concurrently."""
    client = AsyncOpenAI(
        base_url="http://localhost:11434/v1",
        api_key="ollama"
    )
    
    # Read prompts
    async with aiofiles.open(prompts_file, 'r') as f:
        prompts = [line.strip() for line in await f.readlines()]
    
    # Process concurrently (limit concurrent requests)
    semaphore = asyncio.Semaphore(5)  # Max 5 concurrent requests
    
    async def limited_process(prompt):
        async with semaphore:
            return await process_prompt(client, prompt)
    
    results = await asyncio.gather(*[limited_process(p) for p in prompts])
    
    # Write results
    async with aiofiles.open(output_file, 'w') as f:
        for prompt, response in results:
            await f.write(f"Prompt: {prompt}\n")
            await f.write(f"Response: {response}\n")
            await f.write("-" * 50 + "\n")

if __name__ == "__main__":
    asyncio.run(batch_process("prompts.txt", "responses.txt"))
