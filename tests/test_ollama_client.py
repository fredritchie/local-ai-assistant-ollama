from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from ollama_client import OllamaClientError, list_models, stream_chat


@patch("ollama_client.client.list")
def test_list_models(mock_list: MagicMock) -> None:
    model = MagicMock()
    model.model = "llama3.2:3b"

    response = MagicMock()
    response.models = [model]

    mock_list.return_value = response

    assert list_models() == ["llama3.2:3b"]


@patch("ollama_client.client.list")
def test_list_models_returns_empty_list(mock_list: MagicMock) -> None:
    response = MagicMock()
    response.models = []
    mock_list.return_value = response

    assert list_models() == []


@patch("ollama_client.client.list")
def test_list_models_wraps_client_errors(mock_list: MagicMock) -> None:
    mock_list.side_effect = RuntimeError("connection refused")

    with pytest.raises(OllamaClientError, match="Unable to list"):
        list_models()


@patch("ollama_client.client.chat")
def test_stream_chat_yields_non_empty_chunks(mock_chat: MagicMock) -> None:
    mock_chat.return_value = iter(
        [
            SimpleNamespace(message=SimpleNamespace(content="Hello")),
            SimpleNamespace(message=SimpleNamespace(content="")),
            SimpleNamespace(message=SimpleNamespace(content=" world")),
        ]
    )
    messages = [{"role": "user", "content": "Hi"}]

    assert list(stream_chat(messages, model="test-model", temperature=0.2)) == [
        "Hello",
        " world",
    ]
    mock_chat.assert_called_once_with(
        model="test-model",
        messages=messages,
        stream=True,
        options={"temperature": 0.2},
    )


@patch("ollama_client.client.chat")
def test_stream_chat_wraps_client_errors(mock_chat: MagicMock) -> None:
    mock_chat.side_effect = RuntimeError("model unavailable")

    with pytest.raises(OllamaClientError, match="Unable to generate"):
        list(
            stream_chat(
                [{"role": "user", "content": "Hi"}],
                model="missing-model",
            )
        )
