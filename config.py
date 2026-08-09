from __future__ import annotations

import json
import os
from typing import Any

import boto3


def _load_remote_configuration() -> dict[str, str]:
    """Load runtime configuration from SSM and optional Secrets Manager."""
    parameter_path = os.getenv("CONFIG_PARAMETER_PATH", "").rstrip("/")
    secret_arns = [
        value.strip()
        for value in os.getenv("CONFIG_SECRET_ARNS", "").split(",")
        if value.strip()
    ]
    if not parameter_path and not secret_arns:
        return {}

    region = os.getenv("AWS_REGION", "ap-south-1")
    session = boto3.session.Session(region_name=region)
    configuration: dict[str, str] = {}

    if parameter_path:
        paginator = session.client("ssm").get_paginator("get_parameters_by_path")
        for page in paginator.paginate(
            Path=f"{parameter_path}/",
            Recursive=True,
            WithDecryption=True,
        ):
            for parameter in page.get("Parameters", []):
                key = parameter["Name"].rsplit("/", 1)[-1].upper()
                configuration[key] = parameter["Value"]

    secrets_client = session.client("secretsmanager")
    for secret_arn in secret_arns:
        response = secrets_client.get_secret_value(SecretId=secret_arn)
        secret_value = response.get("SecretString")
        if not secret_value:
            raise RuntimeError(
                f"Secret {secret_arn} does not contain SecretString data"
            )
        payload: dict[str, Any] = json.loads(secret_value)
        configuration.update(
            {str(key).upper(): str(value) for key, value in payload.items()}
        )

    return configuration


REMOTE_CONFIGURATION = _load_remote_configuration()


def _setting(name: str, default: str) -> str:
    """Resolve local overrides first, then managed runtime configuration."""
    return os.getenv(name, REMOTE_CONFIGURATION.get(name, default))


OLLAMA_BASE_URL = _setting("OLLAMA_BASE_URL", "http://localhost:11434")
DEFAULT_MODEL = _setting("DEFAULT_MODEL", "llama3.2:3b")

REQUEST_TIMEOUT_SECONDS = max(
    1.0,
    float(_setting("REQUEST_TIMEOUT_SECONDS", "120")),
)

DEFAULT_TEMPERATURE = min(
    1.5,
    max(0.0, float(_setting("DEFAULT_TEMPERATURE", "0.7"))),
)

MAX_HISTORY_MESSAGES = max(
    1,
    int(_setting("MAX_HISTORY_MESSAGES", "20")),
)
