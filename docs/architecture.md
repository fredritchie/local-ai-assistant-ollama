# Architecture

The same application runs locally, inside Docker, on an Ansible-managed
pair of Debian-family hosts, or on Terraform-managed AWS microservices.

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

## AWS provisioning path

Terraform creates a public subnet for a small T-family Streamlit instance and a
private subnet for a `g4dn.xlarge` Ollama instance. A NAT gateway gives the
private service outbound-only access for packages and models. Ollama port
`11434` accepts traffic only from the Streamlit security group.

In the default `server_configuration = "cloud-init"` mode, cloud-init then:

1. The private GPU bootstrap installs Ollama, binds it to the private network,
   and pulls the configured models.
2. The public app bootstrap waits for the private API, clones the configured
   revision, and starts Streamlit natively or in Docker.
3. Each service writes independent completion or failure markers.

## Ansible configuration path

The Ansible playbook applies the same contract to two hosts:

1. Configures and verifies the private Ollama host.
2. Connects to that host through the public Streamlit bastion when deployed by
   Terraform.
3. Configures Streamlit with the private Ollama URL and verifies its health.

The role is independently usable. The `deploy_with_ansible.sh` path asks
Terraform to omit application user data, enables CIDR-restricted SSH, generates
an ignored inventory from Terraform outputs, and makes Ansible the sole server
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
