# Terraform infrastructure for the Docker Ansible variant

Terraform creates the VPC, public Streamlit instance, private Ollama GPU
instance, NAT gateway, security groups, IAM role, generated SSH key, and
encrypted storage in `ap-south-1`. It deliberately does not configure either
application service; `deploy_with_ansible.sh` does that after creation.

Set these values in `terraform.tfvars`:

```hcl
allowed_app_cidr = "203.0.113.10/32"
allowed_ssh_cidr = "203.0.113.10/32"
```

Use the repository-level wrapper for deployment:

```bash
../deploy_with_ansible.sh
```

It forces `enable_ssh=true`, creates the Terraform-managed key pair, and routes
private-host SSH through Streamlit. Ollama port `11434` accepts only Streamlit
security-group traffic; its SSH port accepts only the bastion.

Session Manager remains enabled. The NAT gateway, public IPv4 address,
instances, and EBS volumes incur charges. Destroy unused infrastructure with:

```bash
terraform destroy
```
