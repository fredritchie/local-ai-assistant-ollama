# Architecture

The same application runs locally, inside Docker, on an Ansible-managed
Debian-family server, or on a Terraform-managed AWS GPU instance.

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

In the default `server_configuration = "cloud-init"` mode, cloud-init then:

1. Installs base packages and the pinned Ollama version.
2. Starts Ollama and pulls the required model with retries.
3. Pulls additional models with retries without failing the entire bootstrap if
   an optional model is temporarily unavailable.
4. Clones the configured branch and optionally checks out an immutable commit.
5. Starts either the native Python or Docker systemd service.
6. Waits for Streamlit's health endpoint and writes a completion marker. Any
   failed bootstrap writes a failure marker and an identifiable console-log
   message.

## Ansible configuration path

The Ansible role applies the same server contract to an existing
Debian-family systemd host:

1. Installs base packages and the configured Ollama version.
2. Starts Ollama and pulls the requested models.
3. Checks out a branch, tag, or immutable commit under `/opt`.
4. Configures either a dedicated-user Python virtual environment or a Docker
   container.
5. Installs and starts the `local-ai-assistant` systemd service.
6. Verifies Streamlit through its loopback health endpoint.

The role is independently usable. The `deploy_with_ansible.sh` path asks
Terraform to omit application user data, enables CIDR-restricted SSH, generates
an ignored inventory from Terraform outputs, and makes Ansible the sole server
configuration mechanism.

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
