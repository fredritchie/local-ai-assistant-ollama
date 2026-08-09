# Architecture

This branch runs Streamlit and Ollama natively on one Terraform-managed AWS GPU
instance.

![Repository and AWS architecture](architecture.svg)

GitHub renders the SVG directly in this Markdown file. The SVG is checked into
the repository, so no Mermaid browser extension or external rendering service
is required.

## Request path

1. The browser submits a prompt to Streamlit on port `8501`.
2. `app.py` adds it to session state and sends the most recent configured
   history window to `ollama_client.py`.
3. The client calls Ollama on `localhost:11434`.
4. Ollama runs the selected model on the local CPU/GPU and streams chunks back.
5. Streamlit renders chunks as they arrive and stores the completed response.

## AWS provisioning path

Terraform creates a new VPC, public subnet, route, internet gateway, restricted
security group, IAM instance profile, encrypted gp3 volume, and a
`g4dn.xlarge`. The instance uses AWS's current Ubuntu 24.04 CUDA Deep Learning
AMI from the public SSM parameter.

Cloud-init then:

1. Installs base packages and the pinned Ollama version.
2. Starts Ollama and pulls the required model with retries.
3. Pulls additional models with retries without failing the entire bootstrap if
   an optional model is temporarily unavailable.
4. Clones the configured branch and optionally checks out an immutable commit.
5. Creates a Python virtual environment and starts the native systemd service.
6. Waits for Streamlit's health endpoint and writes a completion marker. Any
   failed bootstrap writes a failure marker and an identifiable console-log
   message.

## Trust boundaries

| Boundary | Control |
|---|---|
| Browser to Streamlit | TCP `8501`, restricted by `allowed_app_cidr` |
| Administrator to EC2 | Session Manager by default; optional CIDR-restricted SSH |
| Streamlit to Ollama | Loopback only; port `11434` is not publicly exposed |
| EC2 metadata | IMDSv2 tokens required |
| Data at rest | Encrypted gp3 root volume |
| Terraform secrets | Runtime files ignored; remote encrypted state recommended |

The application itself has no authentication or TLS. A production deployment
should add an authenticated HTTPS reverse proxy or private access path.
