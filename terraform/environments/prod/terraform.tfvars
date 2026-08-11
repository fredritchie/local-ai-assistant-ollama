app_image_uri = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/local-ai-assistant@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

# Replace the placeholder digest in this manifest before deployment.
model_manifest_file = "../../../models/model-manifest.example.json"

allowed_app_cidrs = ["0.0.0.0/0"]
enable_https      = true
certificate_arn   = "arn:aws:acm:ap-south-1:123456789012:certificate/uuid"

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
# secret_arns       = ["arn:aws:secretsmanager:ap-south-1:123456789012:secret:local-ai/prod/app-xxxxxx"]
