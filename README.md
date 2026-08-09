# Local AI Assistant — AWS EC2 Ansible Docker

This branch provisions one public `g4dn.xlarge` EC2 instance with Terraform,
then uses Ansible to install Ollama and run Streamlit as a Docker container on
the same host.

![Single EC2 architecture](docs/architecture.svg)

## Deploy

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Set allowed_app_cidr and allowed_ssh_cidr to YOUR_PUBLIC_IP/32.
./deploy_with_ansible.sh
```

The wrapper applies Terraform, creates a restricted SSH key, verifies the host
key, generates an ignored inventory, and runs the Docker-only Ansible role.
Ollama remains on loopback and Streamlit is exposed only to the configured
application CIDR.

See [the Ansible guide](ansible/README.md) and
[the Terraform guide](terraform/README.md). See `main` for the hierarchy.
