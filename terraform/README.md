# Single EC2 Docker deployment

Terraform creates a new VPC, public subnet, internet gateway, restricted
security group, IAM role, encrypted volume, generated optional SSH key, and one
`g4dn.xlarge` in `ap-south-1`. EC2 user data installs Ollama and runs Streamlit
as a Docker container on that host.

```bash
cp terraform.tfvars.example terraform.tfvars
# Set allowed_app_cidr to YOUR_PUBLIC_IP/32.
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
./wait_for_application.sh
```

The waiter reports bootstrap failures and waits for the Streamlit health
endpoint. Model downloads and the Docker build continue after Terraform
finishes creating the EC2 resource.

The EC2 instance, EBS storage, and public IPv4 address incur AWS charges:

```bash
terraform destroy
```
