# Security model

This guide defines the implemented trust boundaries and the remaining controls
required before operating the platform in a stricter production environment.

> **Documentation:** [Index](README.md)
> · [All architecture diagrams](diagrams/README.md)
> · [Operations guide](operations.md)

## Architecture context

### Runtime identity and configuration

![Runtime configuration and IAM architecture](diagrams/runtime_configuration_iam_architecture.png)

## Network controls

- Application and GPU instances are private and receive no public IPv4 address.
- The public ALB accepts port 80 and optional 443 only from configured CIDRs.
- App instances accept port 80 only from the public ALB security group.
- The internal ALB accepts port 11434 only from the app security group.
- GPU instances accept port 11434 only from the internal ALB security group.
- PostgreSQL RDS accepts port 5432 from the app security group and the
  dedicated VPC-scoped CodeBuild database-bootstrap security group; it has no
  public endpoint.
- RDS uses two dedicated private database subnets and a shared database route
  table with no NAT or internet default route.
- No SSH ingress or bastion is created. Use Systems Manager Session Manager.

The instances currently retain general outbound access through NAT because
Ubuntu packages and Ollama models come from internet endpoints. A stricter
environment can add VPC endpoints for ECR, S3, SSM, CloudWatch, and Secrets
Manager, then place internet model acquisition in a separate controlled build
process.

## Identity and secrets

App and GPU instances use different IAM roles. The app role can pull images,
read its Parameter Store hierarchy, publish telemetry, and read only explicitly
listed secret ARNs. The GPU role reads only model parameters and publishes
telemetry.

RDS generates and owns its database password through its managed Secrets
Manager secret. The application does not receive this secret: it connects with
an IAM database token generated from its EC2 role. Use the managed secret only
for administration and the dedicated VPC-scoped CodeBuild bootstrap job. Do
not pass the RDS password through Terraform.

After every controlled `deploy`, CodeBuild creates or updates `localai_app`,
grants it `rds_iam`, and grants the schema permissions needed to initialize the
application. The CodeBuild service role has narrowly scoped access to the RDS
administrator secret and private database network path. The application role
does not have `rds:DescribeDBInstances`, Secrets Manager access to that secret,
or permission to run the bootstrap job.

`scripts/bootstrap_rds_iam_user.sh` is retained only as an administrator
recovery tool. Never run it from an application EC2 instance or broaden the app
role to make it work; inspect or rerun the CodeBuild bootstrap job instead.

Create those secrets separately, grant the app role their ARN through
`secret_arns`, and store a JSON object whose keys correspond to application
settings.

Parameter Store is used for ordinary runtime configuration. Secrets Manager is
reserved for credentials requiring stronger lifecycle or rotation controls.
See [AWS Parameter Store guidance](https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-a-parameter.html).

## Host and container controls

- IMDSv2 is required.
- App containers run as a non-root image user.
- The runtime drops Linux capabilities, enables `no-new-privileges`, uses a
  read-only root filesystem, and provides only a small temporary filesystem.
- EBS volumes, state, ECR, SNS, and CloudWatch Logs are encrypted.
- ECR tags are immutable and images are scanned on push.
- Production defaults to ACM TLS; Nginx port 80 remains private behind the ALB.
- The optional DuckDNS token stays in Secrets Manager and never enters
  Terraform state. Let's Encrypt private keys exist only in an ephemeral
  renewal workspace before import into ACM.

## CI/CD trust

The optional GitHub role uses OIDC rather than long-lived access keys. Its
trust policy restricts token subjects to this repository's protected
environments. GitHub recommends both subject conditions and environment
protection rules for AWS OIDC deployments. See [GitHub's AWS OIDC guide](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).
Third-party workflow actions are pinned to reviewed commit SHAs, and Dependabot
opens update pull requests for actions, Python, Docker, and Terraform providers.

## Edge protection

Production associates AWS WAF with the public ALB. It applies an IP rate limit,
the AWS Common Rule Set, and Known Bad Inputs rules; authorization headers are
redacted from WAF logs. Treat these managed rules as a baseline and tune them
against observed traffic before exposing the service broadly.

## Application authentication

The Streamlit app requires sign-in before chat is available. At startup it
creates the configured admin account in PostgreSQL if it does not already
exist; it never overwrites an existing password:

- Username: `admin`
- Password: `changeme`

Change these before exposing the service. Set `ADMIN_USERNAME` and
`ADMIN_PASSWORD_HASH` (bcrypt) in an application Secrets Manager JSON object,
then add that secret ARN to `secret_arns` so the app role can read it. Do not
use the RDS administrator secret for application credentials. Set
`AUTH_ENABLED=false` only for local development without a login gate.

Generate a bcrypt hash for a new password:

```bash
python -c "import bcrypt; print(bcrypt.hashpw(b'your-password', bcrypt.gensalt()).decode())"
```

Store production credentials in Secrets Manager as JSON, for example:

```json
{"ADMIN_USERNAME": "admin", "ADMIN_PASSWORD_HASH": "$2b$12$..."}
```

Grant the app role access by adding the secret ARN to `secret_arns` in Terraform.

## Remaining production work

- Review IAM with Access Analyzer after real deployment activity.
- Enable organization-level CloudTrail, GuardDuty, Security Hub, AWS Config,
  and centralized log archival where applicable.
- Move package and model acquisition into controlled build pipelines or VPC
  endpoints, then remove the remaining HTTP/HTTPS internet egress.

## Scanner exceptions

`.checkov.yml` records the deliberate static-analysis exceptions. They cover
port 80 and private service HTTP, environment-specific retention and deletion
protection, Docker's required IMDS hop limit, KMS key-policy semantics, and
account-level logging/replication responsibilities. The configuration keeps
these decisions visible instead of silently marking the security job as a soft
failure.

## Implementation references

- Network controls: [`network.tf`](../terraform/modules/platform/network.tf),
  [`load_balancing.tf`](../terraform/modules/platform/load_balancing.tf), and
  [`database.tf`](../terraform/modules/platform/database.tf)
- Identity controls: [`iam.tf`](../terraform/modules/platform/iam.tf) and
  [`database_bootstrap.tf`](../terraform/modules/platform/database_bootstrap.tf)
