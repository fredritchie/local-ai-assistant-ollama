# Local AI Assistant with Ollama

A Streamlit chat application backed by Ollama, organized as focused Git
branches so each branch contains one deployment approach instead of a mixture
of unrelated infrastructure and setup code.

The `main` branch is intentionally documentation-only. Choose a branch below
for runnable code and deployment instructions.

## Deployment branches

| Branch | Streamlit runtime | Ollama runtime | Infrastructure | Best for |
|---|---|---|---|---|
| [`feature/local-native`](../../tree/feature/local-native) | Local Python | Local Ollama | None | Development and learning |
| [`feature/local-docker`](../../tree/feature/local-docker) | Local Docker | Host Ollama | Docker | Container testing |
| [`feature/aws-terraform-native`](../../tree/feature/aws-terraform-native) | Native systemd on public T-family EC2 | Native Ollama on private `g4dn.xlarge` | Terraform and EC2 user data | Simple AWS deployment |
| [`feature/aws-terraform-docker`](../../tree/feature/aws-terraform-docker) | Docker on public T-family EC2 | Native Ollama on private `g4dn.xlarge` | Terraform and EC2 user data | Containerized AWS deployment |
| [`feature/aws-ansible`](../../tree/feature/aws-ansible) | Native or Docker on public EC2 | Native Ollama on private EC2 | Terraform and Ansible | Repeatable configuration management |
| [`feature/aws-microservices`](../../tree/feature/aws-microservices) | Configurable native or Docker | Private GPU service | Terraform, cloud-init, and optional Ansible | Complete reference implementation |

## Start locally

Native Python:

```bash
git clone --branch feature/local-native \
  https://github.com/fredritchie/local-ai-assistant-ollama.git
cd local-ai-assistant-ollama
./server_script.sh
```

Docker:

```bash
git clone --branch feature/local-docker \
  https://github.com/fredritchie/local-ai-assistant-ollama.git
cd local-ai-assistant-ollama
./docker_setup.sh
```

## AWS architecture

The AWS branches separate the web and inference workloads:

```text
Internet
   |
Internet Gateway
   |
Public subnet
   |-- Streamlit on t3 / t3a / ARM64 t4g, port 8501
   `-- NAT Gateway
             |
       Private subnet
          Ollama on g4dn.xlarge, port 11434
```

Ollama has no public IP. Its security group accepts port `11434` only from the
Streamlit security group. The private subnet uses a NAT gateway for package and
model downloads. Both instances use encrypted root volumes, IMDSv2, and AWS
Systems Manager Session Manager.

## Switch an existing clone

```bash
git fetch origin
git switch feature/aws-terraform-native
```

Each branch has its own README, CI checks, prerequisites, configuration, and
deployment commands. Avoid merging deployment branches together; create shared
application fixes on one branch and cherry-pick the focused commit where it is
needed.

## Suggested progression

1. Start with `feature/local-native` to understand the application.
2. Use `feature/local-docker` to validate container behavior.
3. Choose one Terraform branch for AWS.
4. Use `feature/aws-ansible` when configuration management is required.
5. Treat `feature/aws-microservices` as the comprehensive reference branch.

AWS deployments create billable EC2, EBS, NAT Gateway, and public IPv4
resources in `ap-south-1`. Review the selected branch's Terraform plan before
applying it and destroy unused environments.
