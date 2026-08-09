# Local AI Assistant with Ollama

A Streamlit chat application backed by Ollama, organized as focused Git
branches so each branch contains one deployment approach instead of a mixture
of unrelated infrastructure and setup code.

The `main` branch is intentionally documentation-only. Choose a branch below
for runnable code and deployment instructions.

## Branch progression

Start at the bottom and move upward. Native and Docker become separate tracks
after the local foundation, so each advantage is compared with the relevant
branch below it.

| Branch | Short description | Advantage over the previous branch |
|---|---|---|
| [`feature/aws-ansible-docker`](../../tree/feature/aws-ansible-docker) | Terraform creates the two EC2 services; Ansible builds and manages Streamlit in Docker. | Over `aws-microservices-docker`: repeatable, idempotent configuration and easier updates without replacing EC2 instances. |
| [`feature/aws-ansible-native`](../../tree/feature/aws-ansible-native) | Terraform creates the infrastructure; Ansible installs native Streamlit and private Ollama services. | Over `aws-microservices-native`: configuration can be rerun, audited, and updated independently of Terraform. |
| [`feature/aws-microservices-docker`](../../tree/feature/aws-microservices-docker) | EC2 user data runs Streamlit in Docker publicly and Ollama on a private GPU instance. | Over `local-docker`: adds a new VPC, workload separation, GPU inference, encrypted storage, and AWS management. |
| [`feature/aws-microservices-native`](../../tree/feature/aws-microservices-native) | EC2 user data installs native Streamlit publicly and Ollama on a private GPU instance. | Over `local-native`: adds reproducible AWS infrastructure, security groups, private inference, and Session Manager. |
| [`feature/local-docker`](../../tree/feature/local-docker) | Streamlit runs in Docker and connects to Ollama on the local host. | Over `local-native`: provides an isolated, reproducible application runtime and image-based packaging. |
| [`feature/local-native`](../../tree/feature/local-native) | Streamlit and Ollama run directly on one local machine. | Foundation: simplest setup, fastest feedback, and lowest cost. |

```text
aws-ansible-native                 aws-ansible-docker
        ↑                                  ↑
aws-microservices-native          aws-microservices-docker
        ↑                                  ↑
local-native ────────────────────── local-docker
        ↑
   START HERE
```

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
git switch feature/aws-microservices-native
```

Each branch has its own README, CI checks, prerequisites, configuration, and
deployment commands. Avoid merging deployment branches together; create shared
application fixes on one branch and cherry-pick the focused commit where it is
needed.

## Choosing a track

- Choose the native track for fewer components and straightforward systemd
  operation.
- Choose the Docker track for image-based packaging and runtime isolation.
- Stop at the microservices branch when immutable EC2 user-data setup is
  sufficient.
- Continue to the Ansible branch when you need repeatable in-place updates and
  configuration management.

AWS deployments create billable EC2, EBS, NAT Gateway, and public IPv4
resources in `ap-south-1`. Review the selected branch's Terraform plan before
applying it and destroy unused environments.
