# Local AI Assistant — native local setup

This branch contains only the local, native Python deployment of the Streamlit
chat application and Ollama. It does not include Docker, Terraform, AWS, or
Ansible configuration.

## What it runs

- Streamlit at `http://localhost:8501`
- Ollama at `http://localhost:11434`
- A Python virtual environment in `.venv`

## Quick start

```bash
git clone --branch feature/local-native \
  https://github.com/fredritchie/local-ai-assistant-ollama.git
cd local-ai-assistant-ollama
./server_script.sh
```

The script installs Python and Ollama when needed, creates the virtual
environment, installs dependencies, downloads the default model, and starts
Streamlit. Git clone or pull remains an operator action.

## Manual start

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
ollama serve
ollama pull llama3.2:3b
streamlit run app.py
```

Run `ollama serve` in another terminal if it is not already managed as a
background service.

## Configuration

| Variable | Default | Purpose |
|---|---:|---|
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API endpoint |
| `DEFAULT_MODEL` | `llama3.2:3b` | Initially selected model |
| `DEFAULT_TEMPERATURE` | `0.7` | Sampling temperature |
| `REQUEST_TIMEOUT_SECONDS` | `120` | Inference request timeout |
| `MAX_HISTORY_MESSAGES` | `20` | Recent messages sent to Ollama |
| `OLLAMA_VERSION` | `0.32.0` | Ollama version installed on Linux |

Example:

```bash
export DEFAULT_MODEL=qwen3:4b
./server_script.sh
```

## Development checks

```bash
python -m pip install -r requirements-dev.txt
ruff check .
pytest -v
shellcheck server_script.sh
```

See the repository `main` branch for all available deployment variants.
