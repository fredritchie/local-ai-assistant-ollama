app_image_uri = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/local-ai-assistant@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

# Use the locked manifest containing the model's verified digest.
model_manifest_file = "../../../models/model-manifest.json"

allowed_app_cidrs = ["0.0.0.0/0"]

# Enable only after issuing or importing an ACM certificate in this account
# and region, then set certificate_arn to its real ARN.
enable_https = true
# certificate_arn = "arn:aws:acm:ap-south-1:AWS_ACCOUNT_ID:certificate/uuid"

enable_deletion_protection = false
force_destroy_log_bucket   = false

# Optional DuckDNS + Let's Encrypt entry point. See docs/duckdns-letsencrypt.md.
# enable_duckdns    = true
# duckdns_subdomain = "your-local-ai-assistant"

# Recommended production settings:
# model_snapshot_id = "snap-0123456789abcdef0"
# Receives an email when app or Ollama target health checks fail. Confirm the
# SNS subscription email AWS sends after apply.
# alarm_email       = "operator@example.com"
# secret_arns       = ["arn:aws:secretsmanager:ap-south-1:AWS_ACCOUNT_ID:secret:local-ai/prod/app-xxxxxx"]
