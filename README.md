# Local AI Assistant — Production HA on AWS

This is the final portfolio branch. It evolves the Docker and Ansible
microservices deployment into a controlled, multi-AZ platform with immutable
artifacts, autoscaling, managed configuration, observability, and environment
separation.

Streamlit is delivered as a multi-architecture image from Amazon ECR. Nginx
exposes each application instance on port `80`, while Ollama runs only in
private GPU subnets. Public and internal Application Load Balancers route to
healthy Auto Scaling targets across two Availability Zones.

![Production architecture](docs/architecture.svg)

## Highlights

- Public ALB across two AZs with ACM TLS enabled by default in production
- Private application ASG: Nginx `:80` to Dockerized Streamlit `:8501`
- Private GPU ASG behind an internal Ollama ALB
- Production capacity of two app and two `g4dn.xlarge` GPU instances
- Cost-reduced development capacity with one app, one GPU, and one NAT Gateway
- Immutable ECR image digests, tag protection, scanning, and retention
- Packer AMIs configured by Ansible, with launch-time self-configuration
- SSM Parameter Store configuration and optional Secrets Manager access
- Versioned S3 Terraform state with S3-native locking and KMS encryption
- JSON logs, CloudWatch Agent metrics, GPU metrics, dashboards, alarms, and traces
- Model digest verification, dedicated EBS cache volumes, and snapshot support
- Optional GitHub OIDC deployment workflow with protected environments
- Terraform native tests, deployed smoke tests, security scans, and container tests

## Repository layout

```text
.
├── app.py, config.py, ollama_client.py
├── ansible/                 Packer image configuration role
├── packer/                  Versioned app and GPU AMI builds
├── models/                  Digest-locked model manifest
├── scripts/                 Build, deploy, wait, diagnostics, and smoke tests
├── terraform/
│   ├── bootstrap/           State, ECR, KMS, and optional GitHub OIDC
│   ├── environments/dev/    Cost-reduced environment state and settings
│   ├── environments/prod/   Multi-AZ HA environment state and settings
│   └── modules/platform/    Network, compute, IAM, load balancing, and telemetry
├── tests/                   Unit and optional deployed integration tests
└── docs/                    Architecture and operational guides
```

## Deployment sequence

Production deployment is deliberately separated into controlled stages:

1. Apply `terraform/bootstrap` once to create the protected state bucket, KMS
   key, ECR repository, and optional GitHub OIDC role.
2. Generate and review a digest-locked model manifest.
3. Optionally build Packer AMIs. The standard Ubuntu and DLAMI sources remain a
   supported fallback.
4. Build the application image once and push it to ECR.
5. Deploy `dev`, run smoke tests, and review CloudWatch telemetry.
6. Promote the same immutable image digest and model manifest to `prod`.

See the [Terraform guide](terraform/README.md) for exact commands.

## Manual image delivery

After applying the bootstrap stack:

```bash
ECR_REPOSITORY_URL=$(terraform -chdir=terraform/bootstrap \
  output -raw ecr_repository_url)
IMAGE_URI=$(./scripts/build_and_push.sh "$ECR_REPOSITORY_URL")
```

`IMAGE_URI` contains an immutable ECR digest, not a mutable `latest` tag.

## Manual environment deployment

```bash
export IMAGE_URI
export STATE_BUCKET="your-terraform-state-bucket"
export STATE_KMS_KEY_ID="arn:aws:kms:ap-south-1:ACCOUNT:key/UUID"
./scripts/deploy.sh dev
```

After validating development, deploy the identical digest to production:

```bash
./scripts/deploy.sh prod
```

The production ALBs have deletion protection enabled. Disable it through a
reviewed Terraform change before destroying production.

## Managed runtime configuration

Terraform writes non-secret runtime values under:

```text
/local-ai-assistant/ENVIRONMENT/app/
/local-ai-assistant/ENVIRONMENT/ollama/
```

The application retrieves configuration through its EC2 IAM role. Optional
Secrets Manager ARNs are supplied separately; Terraform does not create or
store secret values. Environment variables remain available only as local or
emergency overrides.

## CI/CD

CI runs automatically. Deployment is intentionally manual unless the optional
GitHub OIDC role and protected `dev`/`prod` environments are configured. The
deployment workflow builds an image, records its digest, creates a Terraform
plan, uploads the plan artifact, and applies only when explicitly requested.

See [CI/CD and promotion](docs/cicd.md).

## Operations and safety

- [Architecture and failure domains](docs/architecture.md)
- [Security model](docs/security.md)
- [Model lifecycle and rollback](docs/models.md)
- [Operations, deployment, and recovery](docs/operations.md)
- [Testing strategy](docs/testing.md)
- [Cost estimate and GPU selection](docs/cost.md)

## Important limitations

- Streamlit session state is stored in an individual app process. ALB
  stickiness reduces unnecessary movement, but an instance failure can reset an
  active chat session. Durable sessions would require an external data store.
- A production deployment with two continuously running GPU instances is
  expensive. Use `dev` for portfolio demonstrations and destroy it when idle.
- Model tags can change upstream. Production only accepts the digest recorded
  in the reviewed model manifest; update that lock intentionally.
- Production defaults to HTTPS and requires an ACM certificate and domain
  configuration. Nginx still exposes port 80 only inside the private app tier.
  Development can use public ALB HTTP for short-lived testing.

AWS resources are created in `ap-south-1` and incur charges. Review every plan,
confirm GPU quotas and Availability Zone capacity, and read the cost guide
before applying.
