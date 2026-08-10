# Local Docker architecture

![Docker runtime, host networking, and request sequence](architecture.svg)

Streamlit and its Python dependencies run as a non-root container. Ollama and
the model cache remain native host services. Linux uses host networking;
Docker Desktop routes from the container through `host.docker.internal`.
Only the application runtime is containerized in this branch.
