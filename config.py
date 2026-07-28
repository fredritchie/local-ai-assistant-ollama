import os

OLLAMA_BASE_URL = os.getenv(
    "OLLAMA_BASE_URL",
    "http://localhost:11434",
)

DEFAULT_MODEL = os.getenv(
    "DEFAULT_MODEL",
    "llama3.2:3b",
)

REQUEST_TIMEOUT_SECONDS = max(
    1.0,
    float(os.getenv("REQUEST_TIMEOUT_SECONDS", "120")),
)

DEFAULT_TEMPERATURE = min(
    1.5,
    max(0.0, float(os.getenv("DEFAULT_TEMPERATURE", "0.7"))),
)

MAX_HISTORY_MESSAGES = max(
    1,
    int(os.getenv("MAX_HISTORY_MESSAGES", "20")),
)
