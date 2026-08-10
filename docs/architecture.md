# Architecture

Terraform creates one public GPU EC2 instance. Ansible installs native Ollama
and a Dockerized Streamlit service on that host. Streamlit calls Ollama over
`127.0.0.1:11434`; Ollama is not exposed by the security group.

![Single EC2 architecture](architecture.svg)

## End-to-end deployment pipeline

![Terraform, Ansible, Docker, and runtime flow](deployment-flow.svg)

This branch makes four ownership layers explicit: Terraform provisions AWS,
the helper establishes trusted SSH inventory, Ansible configures the GPU host,
and systemd keeps the Dockerized Streamlit application running beside native
Ollama.

Streamlit port `8501` and SSH port `22` are restricted to configured CIDRs.
The instance uses encrypted gp3 storage, IMDSv2, and Session Manager.
