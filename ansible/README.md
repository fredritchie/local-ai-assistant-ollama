# Docker server configuration with Ansible

The playbook configures a private Ollama inference host followed by a public
Streamlit host running as a Docker container under systemd.

## Prerequisites

- Ansible Core on the control machine
- Two Ubuntu or Debian servers; the private host may use the public host as a
  bastion
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

Replace both example addresses, the bastion address, user, and key path.
Host-key checking is enabled, so connect once with SSH or add the server key to
`known_hosts` before running the playbook.

Edit `group_vars/all.yml` to select the repository revision, image name,
Ollama version, models, and the private API URL used by Streamlit. Set an
immutable revision when required:

```yaml
app_repository_version: 0123456789abcdef0123456789abcdef01234567
app_image_name: local-ai-assistant:latest
ollama_private_url: http://10.20.2.10:11434
```

## Apply

Run from the `ansible` directory so Ansible loads the included configuration:

```bash
ansible-playbook playbook.yml
```

After a successful run, open `http://STREAMLIT_PUBLIC_IP:8501`.

```bash
sudo local-ai-assistant-health
sudo systemctl status local-ai-assistant
sudo journalctl -u local-ai-assistant -f
```

On the private host, use `ollama list` and `systemctl status ollama`.

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

The wrapper enables restricted SSH for the Ansible-only infrastructure. It
creates an inventory for both instances, uses ProxyJump
through Streamlit for the private host, records both host keys, and passes the
Terraform deployment variables to the playbook.

Terraform prompts before creating resources. Pass `-auto-approve` only when an
unattended, billable deployment is intended:

```bash
./deploy_with_ansible.sh -auto-approve
```

The generated private key, inventory, host-key file, Terraform state, and
variable file are excluded from version control.
