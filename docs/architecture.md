# Local native architecture

![Local native runtime and request sequence](architecture.svg)

Everything runs directly on one developer machine. The browser reaches
Streamlit on port `8501`; `ollama_client.py` calls Ollama over loopback on port
`11434`; Ollama loads the selected model from local storage and streams tokens
back through the same path. The Python virtual environment isolates application
dependencies, but there is no container, network, or cloud boundary.
