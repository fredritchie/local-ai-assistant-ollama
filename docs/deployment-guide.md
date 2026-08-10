# Dev and production deployment guide

This guide deploys the application through GitHub Actions. It uses committed
non-secret configuration files for environment-specific values and a GitHub
environment secret only for the DuckDNS token.

## Deploy now: command checklist

Run these commands from the repository root in this order. The first four steps
are one-time setup; subsequent releases start at the GitHub Actions steps.

```bash
# 1. Generate and commit a real model manifest.
python3 scripts/lock_model_manifest.py \
  --model llama3.2:3b:2.0:4.0:true \
  > models/model-manifest.json

# 2. Create or update Bootstrap AWS resources and the GitHub OIDC role.
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply \
  -var="state_bucket_name=YOUR_GLOBALLY_UNIQUE_STATE_BUCKET" \
  -var="enable_github_oidc=true" \
  -var="github_owner=YOUR_GITHUB_USERNAME" \
  -var="github_repository=YOUR_REPOSITORY_NAME" \
  -var="github_owner_id=YOUR_NUMERIC_GITHUB_OWNER_ID" \
  -var="github_repository_id=YOUR_NUMERIC_GITHUB_REPOSITORY_ID"

# 3. Create your local, ignored operator input file and fill in its values.
cp .github/deployment-config/operator.env.example \
  .github/deployment-config/operator.env
${EDITOR:-vi} .github/deployment-config/operator.env

# 4. Authenticate once, then generate and synchronize both environments.
gh auth login
./scripts/sync_github_environment.sh dev
./scripts/sync_github_environment.sh prod

# 5. Commit the generated non-secret configuration and your model/config files.
git add models/model-manifest.json \
  terraform/environments/dev/terraform.tfvars \
  terraform/environments/prod/terraform.tfvars \
  .github/deployment-config/dev.env \
  .github/deployment-config/prod.env
git commit -m "Configure CI/CD environments"
git push
```

During the production synchronization step, paste the newly rotated DuckDNS
token only when prompted. The script saves it directly as a GitHub `prod`
environment secret and never writes it into `operator.env`.

Then deploy from **GitHub → Actions → Controlled deployment**:

| Target | First run | Second run |
|---|---|---|
| Dev | `environment=dev`, `operation=plan` | `environment=dev`, `operation=deploy` |
| Prod | `environment=prod`, `operation=plan` | `environment=prod`, `operation=deploy`, then approve `prod` |

Leave `image_uri` empty for the first deployment. The workflow builds and
publishes an immutable image. The first production deploy ends at
`https://fred-ai-assistant.duckdns.org`.

## What is created

Each environment creates a VPC, private app and GPU instances, load balancers,
RDS PostgreSQL for persistent users and chat history, CloudWatch alarms, and
an SNS alert topic. Production also uses two app instances, two GPU instances,
two NAT gateways, WAF, RDS Multi-AZ, and deletion protection.

Development is the lower-cost test environment. Deploy it first. Promote its
tested immutable ECR digest to production rather than rebuilding production
from an untested commit.

## Prerequisites

- An AWS account with permission to create the bootstrap resources.
- A GitHub repository containing this code and permission to create GitHub
  environments and environment secrets.
- Terraform installed locally for the one-time bootstrap command.
- GitHub CLI (`gh`) installed locally and authenticated with `gh auth login`.
- A reviewed, locked model manifest committed to the repository.
- For production HTTPS, a DuckDNS account and a newly rotated DuckDNS token.

Do not store passwords, API tokens, or private keys in a `.env` configuration
file, Terraform variable file, or Git history.

## 1. Commit a locked model manifest

The example manifest has a deliberately invalid all-zero digest and cannot be
deployed. Generate a real manifest, then commit it:

```bash
python3 scripts/lock_model_manifest.py \
  --model llama3.2:3b:2.0:4.0:true \
  > models/model-manifest.json
```

Create `terraform/environments/dev/terraform.tfvars` and
`terraform/environments/prod/terraform.tfvars` with at least:

```hcl
model_manifest_file = "../../../models/model-manifest.json"
allowed_app_cidrs  = ["YOUR_PUBLIC_IP_OR_OFFICE_CIDR"]
```

Commit these files only when they contain no secrets. For production, restrict
`allowed_app_cidrs` to your office or VPN range rather than `0.0.0.0/0`.

## 2. Bootstrap AWS once

The bootstrap stack creates the remote Terraform state bucket, KMS key, ECR
repository, and GitHub OIDC deployment role. It cannot be created by the
deployment pipeline because the pipeline needs that role before it can obtain
AWS credentials.

```bash
terraform -chdir=terraform/bootstrap init

terraform -chdir=terraform/bootstrap apply \
  -var="state_bucket_name=YOUR_GLOBALLY_UNIQUE_STATE_BUCKET" \
  -var="enable_github_oidc=true" \
  -var="github_owner=YOUR_GITHUB_USERNAME" \
  -var="github_repository=YOUR_REPOSITORY_NAME" \
  -var="github_owner_id=YOUR_NUMERIC_GITHUB_OWNER_ID" \
  -var="github_repository_id=YOUR_NUMERIC_GITHUB_REPOSITORY_ID"
```

GitHub repositories using immutable OIDC subjects require the numeric owner and
repository IDs. GitHub includes both IDs in every deployment token, preventing
a renamed or recycled repository name from inheriting the role trust.

Retrieve the values needed by CI/CD:

```bash
terraform -chdir=terraform/bootstrap output -raw github_deploy_role_arn
terraform -chdir=terraform/bootstrap output -raw ecr_repository_url
terraform -chdir=terraform/bootstrap output -raw state_bucket_name
terraform -chdir=terraform/bootstrap output -raw state_kms_key_arn
```

Reapply this bootstrap stack whenever the repository changes its GitHub OIDC
permissions, such as after enabling automated Let’s Encrypt setup.

## 3. Create GitHub environments

In GitHub, open **Settings → Environments** and create `dev` and `prod`.
Configure required reviewers for `prod`. The workflow selects one of these
environments at runtime, so production reviewers must approve production jobs
before they can read production secrets.

No GitHub configuration variables are required. The non-secret values live in
repository files in the next step.

## 4. Create and synchronize non-secret CI/CD configuration

Copy the local operator template:

```bash
cp .github/deployment-config/operator.env.example \
  .github/deployment-config/operator.env
```

Edit `operator.env` with your GitHub owner/repository and alert address. It is
ignored by Git and must never contain a DuckDNS token, password, or API key.
Keep the production defaults for automated HTTPS:

```dotenv
PROD_ENABLE_DUCKDNS=true
PROD_ENABLE_LETSENCRYPT=true
PROD_DUCKDNS_SUBDOMAIN=fred-ai-assistant
PROD_LETSENCRYPT_EMAIL=fredrickritchie@gmail.com
```

Synchronize each environment after the Bootstrap Terraform stack exists:

```bash
./scripts/sync_github_environment.sh dev
./scripts/sync_github_environment.sh prod
```

The script fetches the role ARN, ECR URL, state bucket, and KMS key from
Terraform Bootstrap outputs; generates `.github/deployment-config/dev.env` and
`prod.env`; creates matching GitHub environment variables through the GitHub
API; and prompts for the DuckDNS token only when synchronizing production.

Commit the generated `dev.env` and `prod.env` files. They contain identifiers
and settings, not credentials. The public hostname is
`fred-ai-assistant.duckdns.org`; DuckDNS does not use `.duckdns.com`.

## 5. Protect the sole GitHub secret

When the production synchronization script prompts for `DUCKDNS_TOKEN`, paste a
newly rotated token. The script sends it directly to the GitHub `prod`
environment as an environment secret; it does not save the token in any local
file. Do not use a repository secret or GitHub variable for this value.

## 6. Deploy development

1. Push the configuration and application changes to GitHub.
2. Open **Actions → Controlled deployment → Run workflow**.
3. Select `dev` and `plan`.
4. Review the uploaded Terraform plan and image build output.
5. Run the workflow again with `dev` and `deploy`.
6. Leave `image_uri` blank to build the selected commit, or provide an
   existing immutable ECR digest.
7. Confirm the SNS subscription email sent to `ALARM_EMAIL`.
8. Open the application URL shown in the workflow health-check log.

The development environment is HTTP by default unless you deliberately enable
HTTPS and configure a certificate.

## 7. Deploy production with automated Let’s Encrypt HTTPS

1. Run `./scripts/sync_github_environment.sh prod` after confirming
   `operator.env` has `PROD_ENABLE_DUCKDNS=true`,
   `PROD_ENABLE_LETSENCRYPT=true`, and the correct DuckDNS label and email.
   This creates or updates the `DUCKDNS_TOKEN` GitHub `prod` environment secret
   when prompted.
3. Run **Controlled deployment** with `environment=prod` and `operation=plan`.
   On the first deployment the plan represents the temporary HTTP bootstrap.
4. Review it, then run the workflow again with `environment=prod` and
   `operation=deploy`.
5. Approve the protected production environment when GitHub requests approval.

The first production deployment automatically creates a Global Accelerator,
updates DuckDNS, issues a Let’s Encrypt DNS-01 certificate, imports it to ACM,
enables ALB HTTPS, and redirects HTTP to HTTPS. It waits for `/healthz` before
finishing.

Open:

```text
https://fred-ai-assistant.duckdns.org
```

Allow a few minutes for DNS propagation and initial GPU model startup.

## 8. Promote a tested development image

For a later production release, copy the digest-pinned ECR image URI from the
successful development workflow log. Run a production `plan` and `deploy` with
that exact value in `image_uri`. This preserves the same verified application
artifact across environments.

## 9. Certificate renewal and alerts

The **Renew DuckDNS Let’s Encrypt certificate** workflow runs monthly and can
also be started manually from the Actions tab. It reads the certificate ARN and
static IP from Parameter Store, refreshes the DNS-01 record, and reimports the
renewed certificate into the same ACM certificate ARN.

Confirm the SNS subscription email after each environment’s first deployment.
The app and Ollama load-balancer health alarms publish both alarm and recovery
notifications to `ALARM_EMAIL`.

## 10. Destroy an environment through CI/CD

1. Open **Actions → Controlled deployment → Run workflow**.
2. Select `dev` or `prod`.
3. Set `operation=destroy`.
4. Set `confirm_destroy` to exactly `DESTROY`.
5. Supply the deployed immutable ECR image digest in `image_uri`.
6. Approve the GitHub environment if required.

Production teardown temporarily disables deletion protection and removes the
versioned ALB log bucket. RDS retains a final snapshot so chat history is not
silently erased. Delete that snapshot manually only when permanent removal is
intended.

The bootstrap state bucket, ECR repository, and KMS key are intentionally not
destroyed by an environment destroy. Remove them only through a separately
reviewed bootstrap teardown after both environments are gone.

## Troubleshooting

| Symptom | Check |
|---|---|
| OIDC authentication fails | Verify the GitHub owner/repository values used in bootstrap and the role ARN in the environment file. |
| Pipeline cannot find configuration | Commit `.github/deployment-config/dev.env` or `prod.env`; only the `.example` files are not sufficient. |
| First prod run fails before certificate issuance | Verify `ENABLE_DUCKDNS=true`, `ENABLE_LETSENCRYPT=true`, `DUCKDNS_SUBDOMAIN`, `LETSENCRYPT_EMAIL`, and the `DUCKDNS_TOKEN` prod secret. |
| HTTPS is unavailable | Check the deployment log, the DuckDNS record, ACM certificate status, and the certificate-expiry alarm. |
| No alert email | Confirm the SNS subscription message sent by AWS. |
| App health wait times out | Review the app and bootstrap CloudWatch log groups; initial GPU model startup can take several minutes. |

For implementation details, see [CI/CD](cicd.md),
[DuckDNS and Let’s Encrypt](duckdns-letsencrypt.md), and
[Operations and recovery](operations.md).
