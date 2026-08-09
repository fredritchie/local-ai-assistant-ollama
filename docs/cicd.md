# CI/CD and controlled promotion

Deployment automation is optional. Manual scripts and Terraform remain fully
supported.

## Enable GitHub OIDC

Set `enable_github_oidc = true` in the bootstrap stack and apply. In GitHub,
create protected environments named `dev` and `prod`, then configure:

| Repository/environment variable | Value |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Bootstrap `github_deploy_role_arn` output |
| `ECR_REPOSITORY_URL` | Bootstrap `ecr_repository_url` output |
| `TF_STATE_BUCKET` | Bootstrap `state_bucket_name` output |
| `TF_STATE_KMS_KEY_ID` | Bootstrap `state_kms_key_arn` output |
| `ACM_CERTIFICATE_ARN` | Production ACM certificate ARN; may be empty in development |

Require reviewers for the production environment. The workflow uses short-lived
OIDC credentials and does not require AWS access-key secrets.

## Promotion flow

1. Run `Controlled deployment` for `dev` with Apply disabled.
2. Review the uploaded plan and image scan.
3. Rerun with Apply enabled after approval.
4. Run deployed integration tests.
5. Copy the deployed ECR digest into the production workflow's `image_uri`
   input so production receives the tested artifact without rebuilding it.
6. Approve the protected production environment.

Leaving `image_uri` empty builds the selected commit. Supplying it skips the
build and requires a digest-pinned ECR URI. The reviewed model manifest remains
versioned with the selected commit, so promotion explicitly controls both
artifacts.

## Pipeline boundaries

CI never performs an automatic production apply on a push. A workflow dispatch,
protected environment approval, reviewed plan, and explicit Apply input are
required. Concurrency permits only one deployment per environment.
