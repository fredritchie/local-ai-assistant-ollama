# Server configuration with Ansible

The playbook configures a Debian-family systemd server with Ollama and the
Local AI Assistant. It supports the same `native` and `docker` runtime modes as
the Terraform bootstrap.

## Prerequisites

- Ansible Core on the control machine
- An Ubuntu or Debian server reachable over SSH
- A remote user with passwordless `sudo`
- Outbound access from the server for system packages, the Git repository, and
  Ollama models

Install the development tools from the repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
```

## Configure inventory and variables

```bash
cd ansible
cp inventory.ini.example inventory.ini
```

Replace the example address, user, and private-key path in `inventory.ini`.
Host-key checking is enabled, so connect once with SSH or add the server key to
`known_hosts` before running the playbook.

Edit `group_vars/all.yml` to select the repository revision, runtime mode,
Ollama version, and models. Set an immutable revision when required:

```yaml
app_repository_version: 0123456789abcdef0123456789abcdef01234567
app_deployment_mode: native
```

Use `app_deployment_mode: docker` to build and run the repository Dockerfile.

## Apply

Run from the `ansible` directory so Ansible loads the included configuration:

```bash
ansible-playbook playbook.yml
```

After a successful run, open `http://SERVER_IP:8501`. On the server:

```bash
sudo local-ai-assistant-health
sudo systemctl status ollama local-ai-assistant
sudo journalctl -u local-ai-assistant -f
```

The playbook is safe to rerun. It updates the selected Git revision, installs
missing dependencies and models, renders the systemd unit, and waits for the
Streamlit health endpoint.

## Using a Terraform host

The repository includes a wrapper that provisions the AWS resources and
configures the new host with this role. From the repository root, copy the
Terraform example and set both trusted CIDRs:

```hcl
allowed_app_cidr = "203.0.113.10/32"
allowed_ssh_cidr = "203.0.113.10/32"
```

Run:

```bash
./deploy_with_ansible.sh
```

The wrapper forces Terraform's `server_configuration` to `ansible` and enables
restricted SSH. It creates `inventory.terraform.ini` and
`known_hosts.terraform`, waits for the instance, then passes Terraform's
repository, runtime, Ollama, and model variables to the playbook.

Terraform prompts before creating resources. Pass `-auto-approve` only when an
unattended, billable deployment is intended:

```bash
./deploy_with_ansible.sh -auto-approve
```

The generated private key, inventory, host-key file, Terraform state, and
variable file are excluded from version control.
