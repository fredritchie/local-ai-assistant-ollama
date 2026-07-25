# AWS GPU deployment with Terraform

This directory deploys the Local AI Assistant on a GPU-backed EC2 instance in
the AWS Mumbai region (`ap-south-1`).

## What is created

- A new VPC with DNS support
- One public subnet in an Availability Zone that offers `g4dn.xlarge`
- An internet gateway and public route table
- A security group for restricted SSH and Streamlit access
- A Terraform-generated 4096-bit RSA EC2 key pair and local `.pem` file
- One `g4dn.xlarge` EC2 instance
- The latest AWS Ubuntu 24.04 single-CUDA Deep Learning AMI
- An encrypted 100 GiB gp3 root volume
- Automated installation and startup of Ollama and the Streamlit application
- EC2 termination with the OS shutdown step skipped during Terraform destroy

```text
Internet
   |
Internet Gateway
   |
Public subnet in the new VPC
   |
Security group
   |-- TCP 22   <- allowed_ssh_cidr
   `-- TCP 8501 <- allowed_app_cidr
   |
g4dn.xlarge EC2
   |-- Ollama on localhost:11434
   `-- Streamlit on 0.0.0.0:8501
```

Port `11434` is not exposed publicly. The application has no built-in
authentication or TLS, so port `8501` should only be allowed from trusted
addresses.

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and AWS provider requirements |
| `variables.tf` | Configurable deployment inputs and validation |
| `main.tf` | VPC, networking, security group, AMI lookup, and EC2 instance |
| `user_data.sh.tftpl` | EC2 bootstrap and systemd service configuration |
| `outputs.tf` | Instance, network, SSH, and application outputs |
| `terraform.tfvars.example` | Example deployment values |

## Prerequisites

- Terraform 1.6 or later
- AWS CLI credentials with EC2, VPC, and SSM Parameter Store permissions
- AWS CLI available locally for the skip-OS-shutdown destroy hook
- Sufficient `g4dn.xlarge` On-Demand quota in `ap-south-1`
- A public HTTPS repository URL that the instance can clone

Verify the local tools and AWS identity:

```bash
terraform version
aws --version
aws sts get-caller-identity
```

If AWS credentials are not configured:

```bash
aws configure
```

## Configuration

Create the local variables file:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
key_name         = "local_llm_aws_vm_key"
allowed_ssh_cidr = "203.0.113.10/32"
allowed_app_cidr = "203.0.113.10/32"
```

Replace `203.0.113.10` with your public IPv4 address. The configuration only
accepts `/24` or narrower CIDRs; `/32` is recommended.

Required inputs:

| Variable | Description |
|---|---|
| `allowed_ssh_cidr` | Trusted CIDR allowed to access TCP port 22 |
| `allowed_app_cidr` | Trusted CIDR allowed to access TCP port 8501 |

Useful optional inputs:

| Variable | Default |
|---|---|
| `key_name` | `local_llm_aws_vm_key` |
| `aws_region` | `ap-south-1` |
| `instance_type` | `g4dn.xlarge` |
| `root_volume_size` | `100` GiB |
| `repository_url` | This project's public GitHub URL |
| `repository_branch` | `main` |
| `ollama_model` | `llama3.2:3b` |
| `additional_ollama_models` | Five additional compact models |
| `vpc_cidr` | `10.20.0.0/16` |
| `public_subnet_cidr` | `10.20.1.0/24` |

The region and instance type are intentionally validated as `ap-south-1` and
`g4dn.xlarge`.

## Deploy

Initialize and validate the configuration:

```bash
terraform init -upgrade
terraform fmt -check
terraform validate
```

Review the proposed infrastructure:

```bash
terraform plan -out=tfplan
```

Create the resources:

```bash
terraform apply tfplan
```

Terraform creates `<key_name>.pem` in this directory with file mode `0600`.
Do not commit that key, `terraform.tfvars`, state files, or plan files. They are
excluded by the Terraform directory's `.gitignore`.

## Access the application

Display the application URL:

```bash
terraform output -raw streamlit_url
```

Bootstrap can take several minutes because the instance installs Ollama,
installs Python packages, and downloads the configured models.

The default model set is:

```text
llama3.2:3b
qwen3:4b
gemma3:4b
phi4-mini:3.8b
deepseek-r1:7b
mistral:7b
```

These models require roughly 20 GB of storage in total. Download time depends
on the instance's network throughput and the Ollama registry.

Display the public IP:

```bash
terraform output -raw public_ip
```

Display the generated private-key path and SSH command:

```bash
terraform output -raw private_key_path
terraform output -raw ssh_command
```

Connect using the generated private key:

```bash
ssh -i ./local_llm_aws_vm_key.pem ubuntu@$(terraform output -raw public_ip)
```

## Verify the instance

Check cloud-init and the application services:

```bash
sudo tail -f /var/log/cloud-init-output.log
sudo systemctl status ollama
sudo systemctl status local-ai-assistant
sudo journalctl -u local-ai-assistant -f
```

Verify the GPU and installed Ollama model:

```bash
nvidia-smi
ollama list
```

The application service starts automatically after reboots.

## Apply configuration changes

After editing a Terraform file or `terraform.tfvars`:

```bash
terraform fmt
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Changes to EC2 user data replace the instance because
`user_data_replace_on_change` is enabled.

## Troubleshooting

### No matching `g4dn.xlarge` capacity

Check the EC2 service quota for running On-Demand G and VT instances in
`ap-south-1`. A quota increase may be required. Temporary AWS capacity errors
can also require retrying later.

### Key-pair name already exists

Terraform creates the EC2 key pair. If AWS reports
`InvalidKeyPair.Duplicate`, select a different `key_name` and apply again.
List existing regional key pairs with:

```bash
aws ec2 describe-key-pairs --region ap-south-1
```

### Cannot open Streamlit

Confirm that:

- `allowed_app_cidr` contains your current public IP.
- Cloud-init completed successfully.
- `local-ai-assistant.service` is active.
- Port `8501` is listening.

```bash
sudo ss -lntp | grep 8501
```

### Repository clone failed

The default bootstrap supports a public HTTPS Git repository. A private
repository requires a separate secure authentication mechanism; do not place a
personal access token directly in Terraform variables because it would be
stored in Terraform state.

## Cost and security notes

- `g4dn.xlarge`, EBS storage, and public IPv4 usage incur AWS charges.
- Stop or destroy unused GPU instances.
- The generated SSH private key is stored unencrypted in Terraform state.
- Protect the state with encrypted storage and strict access controls.
- The generated TLS key approach is intended for bootstrapping; use your
  organization's managed SSH key process for a production environment.
- Do not change either ingress CIDR to `0.0.0.0/0`.
- Add authentication, TLS, and a reverse proxy before supporting broader use.

## Destroy

Preview the deletion:

```bash
terraform plan -destroy
```

The EC2 instance has a destroy-time hook that runs:

```bash
aws ec2 terminate-instances \
  --region ap-south-1 \
  --instance-ids <instance-id> \
  --force \
  --skip-os-shutdown \
  --no-cli-pager
```

This uses EC2 force termination together with the new skip-OS-shutdown mode.
It bypasses the instance's graceful operating-system shutdown and can discard
unflushed data or in-flight I/O. The AWS CLI command must succeed before
Terraform continues destroying the remaining infrastructure.

Terraform still waits for AWS to report the instance as fully terminated
before deleting dependent networking resources. Force termination can reduce
that wait, but it cannot eliminate AWS control-plane and dependency cleanup
time.

Delete all infrastructure created by this stack:

```bash
terraform destroy
```

This removes the instance, root volume, security group, subnet, route table,
internet gateway, and VPC.
