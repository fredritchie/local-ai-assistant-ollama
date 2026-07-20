from ollama_client import stream_chat

messages = [
    {
        "role": "user",
        "content": "Explain what an inference server does in simple terms.",
    }
]

for token in stream_chat(messages):
    print(token, end="", flush=True)

print()