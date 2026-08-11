# CI/CD and controlled promotion

Deployment automation is optional. Manual scripts and Terraform remain fully
supported.

## Enable GitHub OIDC

Set `enable_github_oidc = true` in the bootstrap stack and apply. Set
`github_owner_id` and `github_repository_id` to the immutable numeric IDs from
`gh repo view --json nameWithOwner,id,owner`; the OIDC trust policy uses these
IDs rather than mutable repository names. Create protected GitHub environments
named `dev` and `prod`, then create the ignored operator input file and
synchronize it:

```bash
cp .github/deployment-config/operator.env.example \
  .github/deployment-config/operator.env
./scripts/sync_github_environment.sh dev
./scripts/sync_github_environment.sh prod
```

The script fetches Bootstrap Terraform outputs, generates committed non-secret
environment files, and creates matching GitHub environment variables through
the GitHub API. Require reviewers for the production environment. The workflow
uses short-lived OIDC credentials and does not require AWS access-key secrets.

When `ENABLE_LETSENCRYPT=true`, the script prompts for the DuckDNS token and
creates the `DUCKDNS_TOKEN` **prod environment secret**. The deployment
workflow stores it in AWS Secrets Manager and does not expose it as a Terraform
value.

See [the detailed deployment guide](deployment-guide.md) for the full setup.

## Deploy through GitHub Actions

Run **Controlled deployment** from the GitHub Actions tab and select `dev` or
`prod` plus the `deploy` operation. Leave `image_uri` empty to build the
selected commit, or provide a previously tested immutable ECR digest to
promote it. Select `plan` first to upload a reviewable Terraform plan without
making AWS changes.

The `destroy` operation is protected by the selected GitHub environment and
requires `confirm_destroy` to be exactly `DESTROY`. For production it first
disables ALB/RDS deletion protection and enables removal of the versioned ALB
access-log bucket, then creates and applies a Terraform destroy plan. The RDS
final snapshot is retained deliberately; delete it separately only when chat
history must be permanently erased.

The bootstrap stack must be created once by an administrator before using this
workflow, because it creates the OIDC role that GitHub Actions assumes.

## Database IAM-user bootstrap

After a successful `deploy` apply, the workflow starts the environment's
VPC-scoped CodeBuild project. It creates or updates `localai_app`, grants it
the PostgreSQL `rds_iam` role, and grants the application schema permissions.
The application role never receives the RDS administrator secret or permission
to run this job.

If this stage fails, open the build link printed by the workflow or inspect:

```bash
aws logs tail /local-ai-assistant/ENVIRONMENT/database-bootstrap --follow
```

The deployment fails deliberately when this job fails, preventing a new app
version from appearing healthy while database IAM authentication is incomplete.

## Promotion flow

1. Run `Controlled deployment` for `dev` with the `plan` operation.
2. Review the uploaded plan and image scan.
3. Rerun with the `deploy` operation after approval.
4. Run deployed integration tests.
5. Copy the deployed ECR digest into the production workflow's `image_uri`
   input so production receives the tested artifact without rebuilding it.
6. Approve the protected production environment.

Leaving `image_uri` empty builds the selected commit. Supplying it skips the
build and requires a digest-pinned ECR URI. The reviewed model manifest remains
versioned with the selected commit, so promotion explicitly controls both
artifacts.

## Pipeline boundaries

CI never performs an automatic production apply or destroy on a push. A
workflow dispatch, protected environment approval, reviewed plan, and explicit
operation selection are required. Concurrency permits only one operation per
environment.

Certificate renewal is a separate optional workflow. It retrieves the DuckDNS
token from Secrets Manager, completes a DNS-01 challenge, and reimports the
certificate into the existing ACM ARN. See
[DuckDNS and Let's Encrypt HTTPS](duckdns-letsencrypt.md).
