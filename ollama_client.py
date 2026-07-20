from __future__ import annotations

import time
from collections.abc import Generator

import ollama

from config import DEFAULT_MODEL, DEFAULT_TEMPERATURE


class OllamaClientError(RuntimeError):
    """Raised when communication with Ollama fails."""


def list_models() -> list[str]:
    """Return names of locally installed Ollama models."""
    try:
        response = ollama.list()
        return [model.model for model in response.models]
    except Exception as exc:
        raise OllamaClientError(
            "Unable to list Ollama models. Confirm that Ollama is running."
        ) from exc


def stream_chat(
    messages: list[dict[str, str]],
    model: str = DEFAULT_MODEL,
    temperature: float = DEFAULT_TEMPERATURE,
) -> Generator[str, None, float]:
    """
    Stream a chat response.

    Yields text chunks and returns total elapsed time when complete.
    """
    start_time = time.perf_counter()

    try:
        stream = ollama.chat(
            model=model,
            messages=messages,
            stream=True,
            options={
                "temperature": temperature,
            },
        )

        for chunk in stream:
            text = chunk.message.content
            if text:
                yield text

    except Exception as exc:
        raise OllamaClientError(
            "Unable to generate a response. Confirm that Ollama is running "
            "and the selected model is installed."
        ) from exc

    return time.perf_counter() - start_time