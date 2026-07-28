# AWS GPU deployment with Terraform

This stack deploys the application on a `g4dn.xlarge` EC2 instance in Mumbai
(`ap-south-1`). It creates a new VPC, public subnet, internet gateway, route
table, restricted security group, encrypted root disk, and an IAM role for AWS
Systems Manager Session Manager.

The Streamlit application is public only to `allowed_app_cidr`. Ollama remains
bound to `localhost:11434`.

## Prerequisites

- Terraform 1.6 or later
- AWS credentials with permissions for EC2, VPC, IAM, SSM, and the resources in
  this stack
- `g4dn.xlarge` On-Demand quota in `ap-south-1`
- A public HTTPS Git repository that the instance can clone
- AWS CLI and the Session Manager plugin for shell access
- Ansible Core and OpenSSH when using the combined Ansible deployment

Check your identity before deploying:

```bash
aws sts get-caller-identity
```

## Configure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Set the application CIDR to your public IP:

```hcl
allowed_app_cidr = "203.0.113.10/32"
```

The validation accepts `/24` or narrower IPv4 CIDRs; `/32` is recommended.
Important optional settings are:

| Variable | Default | Purpose |
|---|---:|---|
| `server_configuration` | `"cloud-init"` | Configure with cloud-init or external Ansible |
| `deployment_mode` | `"native"` | Run in a Python venv or set `"docker"` |
| `ollama_version` | `"0.32.0"` | Pin the bootstrap Ollama version |
| `ollama_model` | `"llama3.2:3b"` | Required primary model |
| `additional_ollama_models` | five models | Optional models pulled with retries |
| `repository_branch` | `"main"` | Branch cloned by cloud-init |
| `repository_commit` | `null` | Optional immutable Git SHA to deploy |
| `root_volume_size` | `100` | Encrypted gp3 size in GiB |
| `enable_ssh` | `false` | Create a key and open restricted TCP 22 |
| `force_destroy_skip_os_shutdown` | `false` | Opt in to fast, unsafe termination |

The region and instance type are deliberately restricted to `ap-south-1` and
`g4dn.xlarge`.

## One-command Terraform and Ansible deployment

From the repository root, install the development requirements and create the
Terraform variable file once:

```bash
python -m pip install -r requirements-dev.txt
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Set trusted `/32` CIDRs for the application and Ansible SSH connection:

```hcl
allowed_app_cidr = "203.0.113.10/32"
allowed_ssh_cidr = "203.0.113.10/32"
```

Launch the VM and configure it:

```bash
./deploy_with_ansible.sh
```

The script forces `server_configuration = "ansible"` and `enable_ssh = true`,
applies Terraform, generates ignored Ansible connection files, waits for SSH,
and runs the role. Terraform retains its normal interactive approval. Use this
only when unattended creation is intended:

```bash
./deploy_with_ansible.sh -auto-approve
```

The first SSH host key seen for the newly allocated address is stored in the
ignored `ansible/known_hosts.terraform` file and is required for the subsequent
Ansible connection.

## Optional remote state

Local state is appropriate only for an individual test deployment. For shared
or durable environments, create an S3 state bucket with versioning enabled,
copy `backend.tf.example` to `backend.tf`, replace the bucket name, and run:

```bash
terraform init -migrate-state
```

The example enables encryption and S3 native state locking. `backend.tf` and
`backend.hcl` are ignored so environment-specific settings are not committed.

## Deploy

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
./wait_for_application.sh
```

Cloud-init installs Ollama, downloads the primary model and five optional
models, clones this repository, installs the application, and starts a systemd
service when `server_configuration = "cloud-init"`, which is the default.
This normally takes several minutes; model registry speed is the largest
variable. `wait_for_application.sh` waits for Streamlit's health endpoint for
up to 30 minutes by default and reports an explicit bootstrap failure found in
EC2 console output. Supply a different timeout in seconds when needed:

```bash
./wait_for_application.sh 2400
```

Watch bootstrap progress after the instance registers with Session Manager:

```bash
$(terraform output -raw ssm_session_command)
sudo tail -f /var/log/cloud-init-output.log
```

Then open:

```bash
terraform output -raw streamlit_url
```

Useful checks on the instance:

```bash
sudo cat /var/lib/local-ai-assistant/bootstrap-complete
sudo local-ai-assistant-health
nvidia-smi
ollama list
sudo systemctl status ollama local-ai-assistant
sudo journalctl -u local-ai-assistant -f
```

The bootstrap writes one of these markers:

- `/var/lib/local-ai-assistant/bootstrap-complete` after the application health
  endpoint succeeds.
- `/var/lib/local-ai-assistant/bootstrap-failed` when cloud-init exits with an
  error. The complete command output remains in
  `/var/log/cloud-init-output.log`.

From the Terraform host, the copy-paste health command is:

```bash
terraform output -raw application_health_check_command
$(terraform output -raw application_health_check_command)
```

## Runtime modes

`native` creates a Python virtual environment and runs Streamlit directly.
`docker` builds the repository Dockerfile and runs the container with host
networking so it can reach Ollama without exposing port `11434`.

```hcl
deployment_mode = "docker"
```

Changing user data, including the runtime mode, replaces the EC2 instance.
Changing `server_configuration` also replaces the instance.

## Optional SSH

Session Manager is the default and does not require inbound port 22 or an SSH
private key in Terraform state. If SSH is necessary:

```hcl
enable_ssh       = true
allowed_ssh_cidr = "203.0.113.10/32"
key_name         = "local_llm_aws_vm_key"
```

Terraform then creates `local_llm_aws_vm_key.pem` with mode `0600`:

```bash
terraform output -raw ssh_command
```

The key is ignored by Git but its private material is still present in
Terraform state. Protect and encrypt the state backend.

## Destroy

Graceful EC2 termination is the safe default:

```bash
terraform destroy
```

AWS can take several minutes to finish instance and network cleanup. To bypass
the OS shutdown on a disposable instance, set:

```hcl
force_destroy_skip_os_shutdown = true
```

The destroy hook then calls `terminate-instances --force
--skip-os-shutdown`. This may lose in-flight writes or skip shutdown handlers,
and Terraform may still wait briefly for AWS to report resource deletion.

## Security notes

- Port `8501` has no application authentication or TLS; restrict its CIDR.
- Port `22` is closed unless explicitly enabled.
- IMDSv2 is required.
- The root EBS volume is encrypted and deleted with the instance.
- Model and package downloads require outbound internet access.
- `terraform.tfvars`, state, plans, generated keys, and backend settings are
  excluded from Git.
