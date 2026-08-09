# Local AI Assistant — AWS with Ansible

This branch uses Terraform for AWS infrastructure and Ansible for configuring
the two EC2 microservices. Streamlit can run natively or in Docker; Ollama runs
on the private GPU host.

![AWS architecture](docs/architecture.svg)

## Architecture

- Public `t3`, `t3a`, or ARM64 `t4g` instance: Streamlit on port `8501`
- Private `g4dn.xlarge` instance: Ollama on port `11434`
- Streamlit acts as the SSH bastion for Ansible to reach private Ollama
- Session Manager, IMDSv2, encrypted volumes, and restricted security groups

## Deploy

Install the development requirements, which include Ansible:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
```

Create `terraform/terraform.tfvars`:

```hcl
allowed_app_cidr = "203.0.113.10/32"
allowed_ssh_cidr = "203.0.113.10/32"
deployment_mode  = "native" # or "docker"
```

Deploy from the repository root:

```bash
./deploy_with_ansible.sh
```

The wrapper applies Terraform, records both SSH host keys, generates an ignored
inventory, connects to private Ollama through the public Streamlit bastion, and
runs the playbook. Terraform retains its normal approval prompt.

See [the Ansible guide](ansible/README.md) and
[the Terraform guide](terraform/README.md). See `main` for other variants.
