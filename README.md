# Local AI Assistant with Ollama

A Streamlit chat application backed by Ollama, organized as focused Git
branches so each branch contains one deployment approach instead of a mixture
of unrelated infrastructure and setup code.

The `main` branch is intentionally documentation-only. Choose a branch below
for runnable code and deployment instructions.

## Branch progression

Start at the bottom and move upward. Each branch adds the next deployment or
operational capability over the branch immediately below it.

| Branch | Short description | Advantage over the previous branch |
|---|---|---|
| [`feature/aws-ec2-ansible-microservices-docker`](../../tree/feature/aws-ec2-ansible-microservices-docker) | Ansible manages Dockerized Streamlit publicly and Ollama on a private GPU EC2. | Over Ansible microservices native: adds container isolation and image-based Streamlit deployment. |
| [`feature/aws-ec2-ansible-microservices-native`](../../tree/feature/aws-ec2-ansible-microservices-native) | Ansible manages native Streamlit and Ollama on separate public/private EC2 instances. | Over single-EC2 Ansible Docker: isolates inference, removes Ollama's public IP, and enables independent workload sizing. |
| [`feature/aws-ec2-ansible-docker`](../../tree/feature/aws-ec2-ansible-docker) | Ansible manages Ollama and Dockerized Streamlit together on one GPU EC2. | Over single-EC2 Ansible native: adds a reproducible container image and runtime isolation. |
| [`feature/aws-ec2-ansible-native`](../../tree/feature/aws-ec2-ansible-native) | Ansible manages native Ollama and Streamlit together on one GPU EC2. | Over EC2 user-data Docker: adds repeatable, idempotent in-place configuration and updates. |
| [`feature/aws-ec2-userdata-docker`](../../tree/feature/aws-ec2-userdata-docker) | EC2 user data installs Ollama and Dockerized Streamlit on one GPU EC2. | Over EC2 user-data native: adds container packaging and application isolation. |
| [`feature/aws-ec2-userdata-native`](../../tree/feature/aws-ec2-userdata-native) | EC2 user data installs native Ollama and Streamlit on one GPU EC2. | Over local Docker: adds Terraform-managed AWS hosting, GPU capacity, encrypted storage, and Session Manager. |
| [`feature/local-docker`](../../tree/feature/local-docker) | Streamlit runs in Docker and connects to Ollama on the local host. | Over `local-native`: provides an isolated, reproducible application runtime and image-based packaging. |
| [`feature/local-native`](../../tree/feature/local-native) | Streamlit and Ollama run directly on one local machine. | Foundation: simplest setup, fastest feedback, and lowest cost. |

```text
AWS EC2 Ansible microservices Docker
                  ↑
AWS EC2 Ansible microservices native
                  ↑
AWS EC2 Ansible Docker
                  ↑
AWS EC2 Ansible native
                  ↑
AWS EC2 user-data Docker
                  ↑
AWS EC2 user-data native
                  ↑
Local Docker
                  ↑
Local native — START HERE
```

## Branch descriptions

- [`feature/local-native`](../../tree/feature/local-native) runs Ollama and the
  Streamlit application directly on the local machine with Python.
- [`feature/local-docker`](../../tree/feature/local-docker) keeps Ollama on the
  host and packages the Streamlit application in a local Docker container.
- [`feature/aws-ec2-userdata-native`](../../tree/feature/aws-ec2-userdata-native)
  uses Terraform and EC2 user data to install native Ollama and Streamlit on a
  single public `g4dn.xlarge` instance.
- [`feature/aws-ec2-userdata-docker`](../../tree/feature/aws-ec2-userdata-docker)
  uses Terraform and EC2 user data to run Ollama natively and Streamlit in
  Docker on a single public `g4dn.xlarge` instance.
- [`feature/aws-ec2-ansible-native`](../../tree/feature/aws-ec2-ansible-native)
  provisions one public GPU EC2 instance with Terraform and configures native
  Ollama and Streamlit services with Ansible.
- [`feature/aws-ec2-ansible-docker`](../../tree/feature/aws-ec2-ansible-docker)
  provisions one public GPU EC2 instance with Terraform, then uses Ansible to
  manage native Ollama and a Dockerized Streamlit application.
- [`feature/aws-ec2-ansible-microservices-native`](../../tree/feature/aws-ec2-ansible-microservices-native)
  separates native Streamlit onto a public general-purpose EC2 instance and
  Ollama onto a private GPU EC2 instance, both configured by Ansible.
- [`feature/aws-ec2-ansible-microservices-docker`](../../tree/feature/aws-ec2-ansible-microservices-docker)
  uses the same public/private microservice architecture while packaging the
  public Streamlit service as a Docker container.

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

The four single-EC2 branches run both services on one `g4dn.xlarge`. Only the
last two microservice branches separate the web and inference workloads:

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
git switch feature/aws-ec2-userdata-native
```

Each branch has its own README, CI checks, prerequisites, configuration, and
deployment commands. Avoid merging deployment branches together; create shared
application fixes on one branch and cherry-pick the focused commit where it is
needed.

## Choosing a level

- Use local branches for development without AWS cost.
- Use EC2 user data for the smallest automated AWS setup.
- Add Ansible for repeatable in-place configuration and application updates.
- Use Ansible microservices when Streamlit and GPU inference need separate
  security boundaries or independent sizing.

AWS deployments create billable EC2, EBS, NAT Gateway, and public IPv4
resources in `ap-south-1`. Review the selected branch's Terraform plan before
applying it and destroy unused environments.
