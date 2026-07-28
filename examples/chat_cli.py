"""Minimal command-line example for testing a live Ollama model."""

from ollama_client import stream_chat


def main() -> None:
    messages = [
        {
            "role": "user",
            "content": "Explain what an inference server does in simple terms.",
        }
    ]

    for token in stream_chat(messages):
        print(token, end="", flush=True)

    print()


if __name__ == "__main__":
    main()
