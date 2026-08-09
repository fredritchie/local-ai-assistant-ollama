output "state_bucket_name" {
  description = "S3 bucket used by environment backends."
  value       = aws_s3_bucket.state.id
}

output "state_kms_key_arn" {
  description = "KMS key used by state and image artifacts."
  value       = aws_kms_key.artifacts.arn
}

output "ecr_repository_url" {
  description = "ECR repository used for immutable application images."
  value       = aws_ecr_repository.app.repository_url
}

output "github_deploy_role_arn" {
  description = "Optional GitHub Actions OIDC deployment role."
  value       = var.enable_github_oidc ? aws_iam_role.github_deploy[0].arn : null
}
