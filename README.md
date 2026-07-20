# Local AI Assistant with Ollama

A local, privacy-friendly AI chat application built with **Python**, **Streamlit**, and **Ollama**.

This project demonstrates how a frontend application communicates with a locally running large language model, streams generated responses, preserves conversation history for the active session, switches between installed models, measures response time, and handles common runtime failures.

---

## Table of Contents

- [Overview](#overview)
- [What This Repository Serves](#what-this-repository-serves)
- [Architecture](#architecture)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Running the Application](#running-the-application)
- [Using the Application](#using-the-application)
- [Configuration](#configuration)
- [Running with Docker](#running-with-docker)
- [Testing](#testing)
- [How Conversation Memory Works](#how-conversation-memory-works)
- [How Streaming Works](#how-streaming-works)
- [Performance Notes](#performance-notes)
- [Error Handling](#error-handling)
- [Security and Privacy](#security-and-privacy)
- [Troubleshooting](#troubleshooting)
- [Known Limitations](#known-limitations)
- [Learning Outcomes](#learning-outcomes)
- [Future Improvements](#future-improvements)
- [Completion Checklist](#completion-checklist)
- [Resume-Ready Description](#resume-ready-description)
- [License](#license)

---

## Overview

The application provides a browser-based chat interface for interacting with locally installed Ollama models.

The model runs on your own machine. The Streamlit application sends messages to the Ollama API, receives the generated response as a stream, and displays it incrementally in the browser.

The project is intentionally focused on the fundamentals of local LLM inference before moving to advanced topics such as RAG, vector databases, vLLM, Kubernetes, observability, and AI operations.

---

## What This Repository Serves

This repository serves a local AI assistant accessible through a web browser.

It provides:

- A Streamlit chat interface
- Local LLM inference through Ollama
- Streaming responses
- Session-based conversation history
- Dynamic model selection
- Temperature control
- Response-time display
- Graceful error handling
- Basic automated tests
- Optional Docker packaging

This project does **not** include:

- RAG
- PDF or document upload
- Vector search
- Persistent user accounts
- Persistent chat storage
- Authentication
- Multi-user isolation
- Distributed inference
- Kubernetes deployment
- Production-grade observability

---

## Architecture

```text
+----------------------+
|      Web Browser     |
|    Streamlit Chat    |
+----------+-----------+
           |
           | User prompt and chat history
           v
+----------------------+
|      app.py          |
| Streamlit UI logic   |
+----------+-----------+
           |
           | Calls model client
           v
+----------------------+
| ollama_client.py     |
| Ollama API wrapper   |
+----------+-----------+
           |
           | HTTP/API request
           v
+----------------------+
|   Ollama Server      |
| localhost:11434      |
+----------+-----------+
           |
           | Loads selected model
           v
+----------------------+
|      Local LLM       |
| Llama / Qwen / Gemma |
| Mistral / other      |
+----------------------+
```

### Request flow

```text
User message
    ↓
Streamlit captures the prompt
    ↓
The application stores the message in session history
    ↓
The full relevant history is sent to Ollama
    ↓
Ollama generates a streamed response
    ↓
Streamlit displays text incrementally
    ↓
The final assistant response is stored in session history
```

---

## Features

### Core features

- Local chat interface
- Local model inference
- Streaming responses
- Conversation history
- Clear-chat button
- Model selection
- Temperature control
- Response-time display
- Human-readable error messages

### Engineering features

- Modular Ollama client
- Centralized configuration
- Environment variable support
- Virtual environment support
- Pytest-based tests
- Dockerfile
- Clean repository structure

---

## Technology Stack

| Component | Technology |
|---|---|
| Language | Python |
| Web UI | Streamlit |
| Model runtime | Ollama |
| Model communication | Ollama Python client |
| Testing | Pytest |
| Containerization | Docker |
| Version control | Git |

---

## Repository Structure

```text
local-ai-assistant-ollama/
├── app.py
├── ollama_client.py
├── config.py
├── requirements.txt
├── Dockerfile
├── README.md
├── .gitignore
├── tests/
│   └── test_ollama_client.py
└── screenshots/
    ├── chat-interface.png
    ├── model-selection.png
    ├── response-time.png
    └── ollama-offline-error.png
```

### File responsibilities

#### `app.py`

Responsible for:

- Rendering the Streamlit interface
- Accepting user prompts
- Displaying previous messages
- Streaming assistant responses
- Handling model and temperature settings
- Clearing chat history
- Displaying timing information
- Showing user-friendly errors

#### `ollama_client.py`

Responsible for:

- Listing installed models
- Sending chat messages to Ollama
- Streaming generated response chunks
- Converting low-level exceptions into readable application errors

#### `config.py`

Stores configurable values such as:

- Ollama API address
- Default model
- Request timeout
- Default temperature

#### `tests/test_ollama_client.py`

Contains unit tests for the Ollama client.

#### `screenshots/`

Stores images used in this README.

---

## Prerequisites

Install the following before running the project:

- Python 3.11 or later
- Git
- Ollama
- At least one Ollama model

Optional:

- Docker
- Docker Desktop

Check installed versions:

```bash
python3 --version
git --version
ollama --version
docker --version
```

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/local-ai-assistant-ollama.git
cd local-ai-assistant-ollama
```

Replace `<your-username>` with your GitHub username.

### 2. Create a virtual environment

#### Linux or macOS

```bash
python3 -m venv .venv
source .venv/bin/activate
```

#### Windows PowerShell

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
```

#### Windows Command Prompt

```cmd
python -m venv .venv
.venv\Scripts\activate.bat
```

### 3. Upgrade pip

```bash
python -m pip install --upgrade pip
```

### 4. Install dependencies

```bash
pip install -r requirements.txt
```

### 5. Pull a model

Recommended starter model:

```bash
ollama pull llama3.2:3b
```

Other examples:

```bash
ollama pull qwen2.5:3b
ollama pull gemma3:4b
ollama pull mistral
```

List installed models:

```bash
ollama list
```

### 6. Test Ollama from the terminal

```bash
ollama run llama3.2:3b
```

Example prompt:

```text
Explain Kubernetes in three lines.
```

Exit:

```text
/bye
```

---

## Running the Application

### 1. Start Ollama

Ollama usually starts automatically.

When needed, run:

```bash
ollama serve
```

Default API endpoint:

```text
http://localhost:11434
```

### 2. Start Streamlit

From the repository root:

```bash
streamlit run app.py
```

The application normally opens at:

```text
http://localhost:8501
```

If the browser does not open automatically, copy the local URL shown in the terminal.

---

## Using the Application

### Send a prompt

Example:

```text
What is model inference?
```

### Test conversation memory

Send:

```text
My name is Fredrick.
```

Then send:

```text
What is my name?
```

The model should answer correctly because the application sends the earlier conversation along with the new request.

### Switch models

Install another model:

```bash
ollama pull qwen2.5:3b
```

Refresh the app and select it from the sidebar.

### Adjust temperature

Lower temperature:

```text
0.1 to 0.3
```

Usually gives more consistent responses.

Higher temperature:

```text
0.8 to 1.2
```

Usually gives more varied responses.

### Clear chat

Use the **Clear chat** button in the sidebar.

---

## Configuration

Example `config.py`:

```python
import os

OLLAMA_BASE_URL = os.getenv(
    "OLLAMA_BASE_URL",
    "http://localhost:11434",
)

DEFAULT_MODEL = os.getenv(
    "DEFAULT_MODEL",
    "llama3.2:3b",
)

REQUEST_TIMEOUT_SECONDS = int(
    os.getenv("REQUEST_TIMEOUT_SECONDS", "120")
)

DEFAULT_TEMPERATURE = float(
    os.getenv("DEFAULT_TEMPERATURE", "0.7")
)
```

### Supported environment variables

| Variable | Default | Purpose |
|---|---|---|
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API endpoint |
| `DEFAULT_MODEL` | `llama3.2:3b` | Default selected model |
| `REQUEST_TIMEOUT_SECONDS` | `120` | Request timeout |
| `DEFAULT_TEMPERATURE` | `0.7` | Default generation temperature |

Example:

```bash
export DEFAULT_MODEL=qwen2.5:3b
export DEFAULT_TEMPERATURE=0.3
streamlit run app.py
```

---

## Running with Docker

### Important networking note

Inside a container, `localhost` refers to the container itself.

If Ollama runs on your host machine:

- macOS and Windows typically use `host.docker.internal`
- Linux can use host networking

### Build the image

```bash
docker build -t local-ai-assistant .
```

### Run on macOS or Windows

```bash
docker run --rm   -p 8501:8501   -e OLLAMA_BASE_URL=http://host.docker.internal:11434   local-ai-assistant
```

### Run on Linux

```bash
docker run --rm   --network host   -e OLLAMA_BASE_URL=http://localhost:11434   local-ai-assistant
```

Open:

```text
http://localhost:8501
```

---

## Testing

Run all tests:

```bash
pytest -v
```

Suggested test coverage:

- Installed model listing
- Ollama connection errors
- Model-not-found behavior
- Response streaming logic
- Configuration values

Example test:

```python
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
```

---

## How Conversation Memory Works

The model does not permanently remember previous application requests.

The application stores messages in Streamlit session state:

```python
[
    {
        "role": "user",
        "content": "My name is Fredrick."
    },
    {
        "role": "assistant",
        "content": "Nice to meet you, Fredrick."
    },
    {
        "role": "user",
        "content": "What is my name?"
    }
]
```

The relevant history is sent with every new request.

This means:

- Memory exists only because the app resends previous messages
- Restarting the app clears in-memory history
- Long histories increase context size
- Very long histories may later require trimming or summarization

---

## How Streaming Works

Without streaming:

```text
Prompt
→ wait for full generation
→ display complete response
```

With streaming:

```text
Prompt
→ receive partial chunks
→ display chunks incrementally
→ complete response
```

Streaming improves perceived responsiveness.

The displayed response time is not the same as:

- Time to first token
- Tokens per second
- Queue time
- Model load time

Those metrics can be added later.

---

## Performance Notes

Compare models using a simple table:

| Model | First response time | Total response time | Quality | Memory observation |
|---|---:|---:|---|---|
| `llama3.2:3b` | Add result | Add result | Add result | Add result |
| `qwen2.5:3b` | Add result | Add result | Add result | Add result |
| `gemma3:4b` | Add result | Add result | Add result | Add result |

Common observations:

- Larger models usually need more memory
- Longer prompts increase processing time
- Longer responses increase total latency
- The first request may be slower because the model is loading
- Quantized models reduce memory usage
- Temperature affects output variation, not model knowledge

---

## Error Handling

The application should handle:

- Ollama not running
- No models installed
- Selected model missing
- Request timeout
- Empty input
- Unexpected API response
- Very long conversation history

Example message:

```text
Unable to connect to Ollama. Confirm that the Ollama service is running.
```

The UI should show the error without crashing.

---

## Security and Privacy

### Privacy advantages

- Prompts can remain on the local machine
- No hosted inference API is required
- Model execution is local
- Useful for private experimentation

### Current security limitations

- No authentication
- No authorization
- No TLS
- No multi-user isolation
- No audit logging
- No secrets manager integration

Do not expose the current application directly to the public internet.

---

## Troubleshooting

### `ollama: command not found`

Check installation:

```bash
ollama --version
```

Restart the terminal after installing Ollama.

### Cannot connect to Ollama

Check the API:

```bash
curl http://localhost:11434/api/tags
```

Start Ollama:

```bash
ollama serve
```

### Model not found

List models:

```bash
ollama list
```

Pull the required model:

```bash
ollama pull llama3.2:3b
```

### `streamlit: command not found`

Activate the virtual environment:

```bash
source .venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

### Docker cannot reach Ollama

On macOS or Windows:

```text
http://host.docker.internal:11434
```

On Linux:

```bash
docker run --network host ...
```

### First response is slow

Possible reasons:

- Model loading
- CPU-only inference
- Model too large for available memory
- Long prompt
- Resource pressure

Try a smaller model.

### Long chats become slow

Possible improvements:

- Limit stored history
- Remove older turns
- Summarize older messages
- Enforce a context budget

---

## Known Limitations

- Session-only chat history
- No persistent database
- No authentication
- No RAG
- No document upload
- No token count
- No production metrics
- No tracing
- No rate limiting
- No autoscaling
- No multi-user support
- No guardrails
- No evaluation framework

---

## Learning Outcomes

After completing the project, you should be able to explain:

1. Ollama is a local model runtime and API server.
2. Ollama is not the LLM itself.
3. Streamlit is the application layer.
4. Conversation history must be sent again for context.
5. LLM memory is application-managed.
6. Streaming improves perceived responsiveness.
7. Temperature affects output randomness.
8. Model size affects memory, latency, and quality.
9. The first request may include model-loading overhead.
10. Ollama hides low-level tokenization and inference details.
11. This project is not RAG.
12. Total latency differs from time to first token.

---

## Future Improvements

### Application

- Persistent conversations
- Chat export
- Stop-generation button
- Prompt templates
- System prompt editor
- Token statistics
- Context-window management

### Platform

- FastAPI backend
- Prometheus metrics
- Structured JSON logs
- Request IDs
- OpenTelemetry tracing
- Authentication
- Rate limiting
- Health and readiness endpoints
- Docker Compose
- Kubernetes deployment

### AI

- RAG with Qdrant
- Document upload
- Embedding model integration
- Source citations
- RAG evaluation
- Guardrails
- Model routing
- vLLM
- KServe
- Triton Inference Server

---

## Completion Checklist

- [ ] Ollama runs locally
- [ ] At least one model is installed
- [ ] Streamlit UI works
- [ ] Responses stream correctly
- [ ] Conversation history works
- [ ] Clear-chat works
- [ ] Model selection works
- [ ] Temperature control works
- [ ] Response time is displayed
- [ ] Errors are handled
- [ ] Tests pass
- [ ] Docker image builds
- [ ] README is complete
- [ ] Architecture diagram is included
- [ ] Screenshots are included
- [ ] Repository is published to GitHub

---

## Resume-Ready Description

> Built a local AI assistant using Python, Streamlit, and Ollama with streamed model responses, session-based conversation history, dynamic model selection, configurable generation settings, latency reporting, automated tests, Docker support, and resilient error handling.

---

## License

Add your preferred license before publishing.

For a learning project, the MIT License is a common choice.
