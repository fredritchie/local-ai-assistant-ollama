# Local AI Assistant — AWS EC2 user-data native

This branch deploys Streamlit and Ollama together on one public
`g4dn.xlarge` EC2 instance. Terraform creates the AWS infrastructure and EC2
user data installs both services as native systemd processes.

![Single EC2 architecture](docs/architecture.svg)

## Deploy

```bash
git clone --branch feature/aws-ec2-userdata-native \
  https://github.com/fredritchie/local-ai-assistant-ollama.git
cd local-ai-assistant-ollama/terraform
cp terraform.tfvars.example terraform.tfvars
# Set allowed_app_cidr to YOUR_PUBLIC_IP/32.
terraform init
terraform plan -out=tfplan
terraform apply tfplan
./wait_for_application.sh
```

The instance uses an Ubuntu CUDA Deep Learning AMI, encrypted gp3 storage,
IMDSv2, and Session Manager. Ollama listens only on loopback, while Streamlit
port `8501` is restricted by `allowed_app_cidr`.

See [the Terraform guide](terraform/README.md) for configuration and operation
details. See `main` for the complete branch hierarchy.
