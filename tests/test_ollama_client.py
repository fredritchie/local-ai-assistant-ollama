from unittest.mock import MagicMock, patch

from ollama_client import list_models


@patch("ollama_client.ollama.list")
def test_list_models(mock_list: MagicMock) -> None:
    model = MagicMock()
    model.model = "llama3.2:3b"

    response = MagicMock()
    response.models = [model]

    mock_list.return_value = response

    assert list_models() == ["llama3.2:3b"]