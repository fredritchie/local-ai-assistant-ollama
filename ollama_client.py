from __future__ import annotations

import time
from collections.abc import Generator

from ollama import Client

from config import (
    DEFAULT_MODEL,
    DEFAULT_TEMPERATURE,
    OLLAMA_BASE_URL,
    REQUEST_TIMEOUT_SECONDS,
)
from observability import logger, tracer

client = Client(
    host=OLLAMA_BASE_URL,
    timeout=REQUEST_TIMEOUT_SECONDS,
)


class OllamaClientError(RuntimeError):
    """Raised when communication with Ollama fails."""


def list_models() -> list[str]:
    """Return names of locally installed Ollama models."""
    with tracer.start_as_current_span("ollama.list_models") as span:
        span.set_attribute("ollama.endpoint", OLLAMA_BASE_URL)
        try:
            response = client.list()
            models = [model.model for model in response.models]
            span.set_attribute("ollama.model_count", len(models))
            return models
        except Exception as exc:
            logger.exception("Unable to list Ollama models")
            span.record_exception(exc)
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

    with tracer.start_as_current_span("ollama.chat") as span:
        span.set_attribute("ollama.model", model)
        span.set_attribute("ollama.message_count", len(messages))
        try:
            stream = client.chat(
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

            logger.info(
                "Ollama chat completed",
                extra={
                    "model": model,
                    "elapsed_seconds": time.perf_counter() - start_time,
                },
            )
        except Exception as exc:
            logger.exception("Ollama chat failed")
            span.record_exception(exc)
            raise OllamaClientError(
                "Unable to generate a response. Confirm that Ollama is running "
                "and the selected model is installed."
            ) from exc

    return time.perf_counter() - start_time
