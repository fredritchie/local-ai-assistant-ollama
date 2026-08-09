# AWS Streamlit and Ollama microservices

This stack deploys two EC2 services in `ap-south-1`:

- Streamlit on a public T-family Ubuntu instance (`t3.small` by default).
- Ollama on a private `g4dn.xlarge` Ubuntu CUDA DLAMI.

Ollama has no public IP. Its security group accepts port `11434` only from the
Streamlit security group. A NAT gateway supplies outbound access for packages
and model downloads.

```text
Internet
   |
Internet gateway
   |
Public subnet
   |-- Streamlit t3/t3a/t4g :8501
   `-- NAT gateway
             |
       Private subnet
          Ollama g4dn.xlarge :11434
```

## Prerequisites

- Terraform 1.6 or later
- AWS credentials with EC2, VPC, EIP, NAT Gateway, IAM, and SSM permissions
- `g4dn.xlarge` quota in Mumbai
- AWS CLI and Session Manager plugin for administration
- A public HTTPS Git repository for the Streamlit source

## Configure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

At minimum, restrict Streamlit to your address:

```hcl
allowed_app_cidr = "203.0.113.10/32"
```

Important variables:

| Variable | Default | Purpose |
|---|---:|---|
| `app_instance_type` | `t3.small` | Streamlit host; supports t3, t3a, or ARM64 t4g |
| `instance_type` | `g4dn.xlarge` | Private Ollama GPU host |
| `app_root_volume_size` | `20` | Streamlit encrypted gp3 volume |
| `root_volume_size` | `100` | Ollama encrypted gp3 volume and models |
| `private_subnet_cidr` | `10.20.2.0/24` | Ollama subnet |
| `deployment_mode` | `native` | Streamlit native or Docker runtime |
| `server_configuration` | `cloud-init` | Cloud-init or Ansible configuration |
| `ollama_model` | `llama3.2:3b` | Required primary model |

Choosing `t4g` automatically selects the ARM64 Ubuntu AMI; t3 and t3a use
AMD64. The GPU DLAMI remains AMD64.

## Deploy with cloud-init

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
./wait_for_application.sh
```

The private service configures first. Streamlit then waits for Ollama's private
API before starting. The waiter checks both instances for explicit bootstrap
failure messages and polls the public Streamlit health endpoint.

Use a longer custom timeout when downloading many models:

```bash
./wait_for_application.sh 5400
```

## Deploy with Ansible

From the repository root, set both trusted CIDRs and run:

```hcl
allowed_app_cidr = "203.0.113.10/32"
allowed_ssh_cidr = "203.0.113.10/32"
```

```bash
./deploy_with_ansible.sh
```

The wrapper enables the optional key, connects directly to Streamlit, then
uses it as a bastion to configure private Ollama. Port 22 on Ollama accepts
traffic only from the Streamlit security group and exists only in Ansible mode.

## Operations

```bash
terraform output -raw streamlit_url
$(terraform output -raw ssm_session_command)
$(terraform output -raw ollama_ssm_session_command)
```

On Streamlit:

```bash
sudo local-ai-assistant-health
sudo systemctl status local-ai-assistant
sudo cat /var/lib/local-ai-assistant/bootstrap-complete
```

On Ollama:

```bash
sudo local-ollama-health
sudo systemctl status ollama
ollama list
sudo cat /var/lib/local-ai-assistant-ollama/bootstrap-complete
```

## Remote state

For shared environments, create a versioned S3 state bucket, copy
`backend.tf.example` to `backend.tf`, update the bucket, and run:

```bash
terraform init -migrate-state
```

## Cost and security

- NAT gateways, the public IPv4 address, both instances, and EBS volumes incur
  charges. Destroy unused environments.
- Port `11434` is not internet-accessible.
- Port `8501` has no built-in TLS or authentication; keep its CIDR narrow.
- Session Manager is enabled for both instances and is the default access path.
- IMDSv2 and encrypted root volumes are required on both instances.
- Terraform state, variable files, plans, generated keys, and backend settings
  are ignored by Git.

## Destroy

```bash
terraform destroy
```

Graceful shutdown is the default. Set
`force_destroy_skip_os_shutdown = true` only for disposable deployments where
the faster but unsafe EC2 termination behavior is acceptable.
