# Local AI Assistant — local Docker setup

This branch contains the local Docker deployment. Streamlit runs in a
non-root container and connects to Ollama on the host. It does not include AWS,
Terraform, or Ansible configuration.

![Local Docker architecture](docs/architecture.svg)

See [Architecture](docs/architecture.md) for the container boundary, host
networking variants, and request sequence.

## Quick start

```bash
git clone --branch feature/local-docker \
  https://github.com/fredritchie/local-ai-assistant-ollama.git
cd local-ai-assistant-ollama
./docker_setup.sh
```

The setup script installs Docker and Ollama when needed, pulls the default
model, builds the image, and starts the Streamlit container at
`http://localhost:8501`. Git clone or pull remains an operator action.

## Manual Docker commands

On Linux:

```bash
docker build -t local-ai-assistant .
docker run --rm --network host \
  -e OLLAMA_BASE_URL=http://localhost:11434 \
  -e DEFAULT_MODEL=llama3.2:3b \
  local-ai-assistant
```

On Docker Desktop:

```bash
docker build -t local-ai-assistant .
docker run --rm -p 8501:8501 \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -e DEFAULT_MODEL=llama3.2:3b \
  local-ai-assistant
```

The image includes a Streamlit health check and runs as an unprivileged user.

## Configuration

The main settings are `OLLAMA_BASE_URL`, `DEFAULT_MODEL`,
`DEFAULT_TEMPERATURE`, `REQUEST_TIMEOUT_SECONDS`, and `MAX_HISTORY_MESSAGES`.
They can be supplied with additional `docker run -e` options.

## Development checks

```bash
python -m pip install -r requirements-dev.txt
ruff check .
pytest -v
shellcheck docker_setup.sh
docker build -t local-ai-assistant:test .
```

See the repository `main` branch for all available deployment variants.
