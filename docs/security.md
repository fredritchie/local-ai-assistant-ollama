# Security model

## Network controls

- Application and GPU instances are private and receive no public IPv4 address.
- The public ALB accepts port 80 and optional 443 only from configured CIDRs.
- App instances accept port 80 only from the public ALB security group.
- The internal ALB accepts port 11434 only from the app security group.
- GPU instances accept port 11434 only from the internal ALB security group.
- PostgreSQL RDS accepts port 5432 only from the app security group and has no
  public endpoint.
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
Manager secret. Terraform only references that secret ARN, and grants the app
role access automatically. Do not pass other secret values through Terraform.
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
`ADMIN_PASSWORD_HASH` (bcrypt) through environment variables or Secrets Manager.
Set `AUTH_ENABLED=false` only for local development without a login gate.

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
