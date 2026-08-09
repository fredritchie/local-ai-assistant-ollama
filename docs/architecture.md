# Architecture

This branch provisions AWS infrastructure with Terraform and configures both
microservices with Ansible.

![Repository and AWS architecture](architecture.svg)

GitHub renders the SVG directly in this Markdown file. The SVG is checked into
the repository, so no Mermaid browser extension or external rendering service
is required.

## Request path

1. The browser submits a prompt to Streamlit on port `8501`.
2. `app.py` adds it to session state and sends the most recent configured
   history window to `ollama_client.py`.
3. Locally, the client calls `localhost:11434`; on AWS it calls Ollama's private
   VPC address on port `11434`.
4. Ollama runs the selected model on the local CPU/GPU and streams chunks back.
5. Streamlit renders chunks as they arrive and stores the completed response.

## Provisioning path

Terraform creates a public subnet for a small T-family Streamlit instance and a
private subnet for a `g4dn.xlarge` Ollama instance. A NAT gateway gives the
private service outbound-only access for packages and models. Ollama port
`11434` accepts traffic only from the Streamlit security group.

The Ansible playbook then:

1. Configures and verifies the private Ollama host.
2. Connects to that host through the public Streamlit bastion when deployed by
   Terraform.
3. Configures Streamlit with the private Ollama URL and verifies its health.

The `deploy_with_ansible.sh` wrapper enables CIDR-restricted SSH, generates an
ignored inventory from Terraform outputs, and makes Ansible the sole server
configuration mechanism.

## Trust boundaries

| Boundary | Control |
|---|---|
| Browser to Streamlit | TCP `8501`, restricted by `allowed_app_cidr` |
| Administrator to EC2 | Session Manager by default; optional CIDR-restricted SSH |
| Streamlit to Ollama | Private VPC traffic; Ollama SG trusts only Streamlit SG |
| Private Ollama egress | NAT gateway; the GPU instance has no public IP |
| EC2 metadata | IMDSv2 tokens required |
| Data at rest | Encrypted gp3 root volume |
| Terraform secrets | Runtime files ignored; remote encrypted state recommended |

The application itself has no authentication or TLS. A production deployment
should add an authenticated HTTPS reverse proxy or private access path.
