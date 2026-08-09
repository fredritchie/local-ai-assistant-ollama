# Single EC2 infrastructure for Docker Ansible

Terraform creates a VPC, public subnet, restricted security group, IAM role,
encrypted storage, generated SSH key, and one `g4dn.xlarge` in `ap-south-1`.
It does not configure the application; the repository-level Ansible wrapper
does that after EC2 creation.

Set both trusted CIDRs in `terraform.tfvars`:

```hcl
allowed_app_cidr = "203.0.113.10/32"
allowed_ssh_cidr = "203.0.113.10/32"
```

Deploy from the repository root with `./deploy_with_ansible.sh`. Destroy unused
resources with `terraform destroy`.
