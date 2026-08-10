import os
import subprocess
import sys
from unittest.mock import MagicMock, patch


def test_environment_configuration() -> None:
    environment = os.environ.copy()
    environment.update(
        {
            "OLLAMA_BASE_URL": "http://ollama.example:11434",
            "DEFAULT_MODEL": "test-model",
            "REQUEST_TIMEOUT_SECONDS": "30",
            "DEFAULT_TEMPERATURE": "0.2",
            "MAX_HISTORY_MESSAGES": "12",
        }
    )

    result = subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import config; "
                "print(config.OLLAMA_BASE_URL); "
                "print(config.DEFAULT_MODEL); "
                "print(config.REQUEST_TIMEOUT_SECONDS); "
                "print(config.DEFAULT_TEMPERATURE); "
                "print(config.MAX_HISTORY_MESSAGES)"
            ),
        ],
        check=True,
        capture_output=True,
        text=True,
        env=environment,
    )

    assert result.stdout.splitlines() == [
        "http://ollama.example:11434",
        "test-model",
        "30.0",
        "0.2",
        "12",
    ]


def test_numeric_configuration_is_bounded() -> None:
    environment = os.environ.copy()
    environment.update(
        {
            "REQUEST_TIMEOUT_SECONDS": "0",
            "DEFAULT_TEMPERATURE": "9",
            "MAX_HISTORY_MESSAGES": "-5",
        }
    )

    result = subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import config; "
                "print(config.REQUEST_TIMEOUT_SECONDS); "
                "print(config.DEFAULT_TEMPERATURE); "
                "print(config.MAX_HISTORY_MESSAGES)"
            ),
        ],
        check=True,
        capture_output=True,
        text=True,
        env=environment,
    )

    assert result.stdout.splitlines() == ["1.0", "1.5", "1"]


def test_managed_configuration_combines_parameters_and_secrets() -> None:
    import config

    paginator = MagicMock()
    paginator.paginate.return_value = [
        {
            "Parameters": [
                {
                    "Name": "/local-ai/prod/app/DEFAULT_MODEL",
                    "Value": "managed-model",
                }
            ]
        }
    ]
    ssm = MagicMock()
    ssm.get_paginator.return_value = paginator
    secrets = MagicMock()
    secrets.get_secret_value.return_value = {
        "SecretString": '{"API_TOKEN":"managed-secret"}'
    }
    session = MagicMock()
    session.client.side_effect = lambda service: {
        "ssm": ssm,
        "secretsmanager": secrets,
    }[service]

    with (
        patch.dict(
            os.environ,
            {
                "CONFIG_PARAMETER_PATH": "/local-ai/prod",
                "CONFIG_SECRET_ARNS": "arn:aws:secretsmanager:example",
            },
            clear=False,
        ),
        patch("config.boto3.session.Session", return_value=session),
    ):
        managed = config._load_remote_configuration()

    assert managed == {
        "DEFAULT_MODEL": "managed-model",
        "API_TOKEN": "managed-secret",
    }
