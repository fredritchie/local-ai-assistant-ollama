#checkov:skip=CKV_AWS_109:The account-root statement is the standard KMS delegation boundary and service access is condition-scoped.
#checkov:skip=CKV_AWS_111:KMS key policies require wildcard resources because the key is the policy attachment point.
#checkov:skip=CKV_AWS_356:KMS key policies cannot reference their own ARN while being created.
data "aws_iam_policy_document" "workload_kms" {
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid = "CloudWatchLogsEncryption"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }

  statement {
    sid = "CloudWatchAlarmEncryption"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

#checkov:skip=CKV_AWS_109:The account-root statement delegates key administration to IAM; service statements are condition-scoped.
#checkov:skip=CKV_AWS_111:KMS key policies require wildcard resources because the key is the policy attachment point.
#checkov:skip=CKV_AWS_356:KMS key policies cannot reference their own ARN while being created.
resource "aws_kms_key" "workload" {
  description             = "Encrypt ${local.name_prefix} workload data, logs, and alarm notifications"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.workload_kms.json

  tags = local.common_tags
}

resource "aws_kms_alias" "workload" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.workload.key_id
}

resource "aws_ssm_parameter" "ollama_url" {
  name        = "${local.parameter_prefix}/app/OLLAMA_BASE_URL"
  description = "Internal highly available Ollama endpoint"
  type        = "SecureString"
  value       = "http://${aws_lb.ollama.dns_name}:11434"
  key_id      = aws_kms_key.workload.arn
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "default_model" {
  name        = "${local.parameter_prefix}/app/DEFAULT_MODEL"
  description = "Default model exposed by the application"
  type        = "SecureString"
  value       = local.primary_model
  key_id      = aws_kms_key.workload.arn
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "request_timeout" {
  name   = "${local.parameter_prefix}/app/REQUEST_TIMEOUT_SECONDS"
  type   = "SecureString"
  value  = tostring(var.request_timeout_seconds)
  key_id = aws_kms_key.workload.arn
  tags   = local.common_tags
}

resource "aws_ssm_parameter" "default_temperature" {
  name   = "${local.parameter_prefix}/app/DEFAULT_TEMPERATURE"
  type   = "SecureString"
  value  = tostring(var.default_temperature)
  key_id = aws_kms_key.workload.arn
  tags   = local.common_tags
}

resource "aws_ssm_parameter" "max_history" {
  name   = "${local.parameter_prefix}/app/MAX_HISTORY_MESSAGES"
  type   = "SecureString"
  value  = tostring(var.max_history_messages)
  key_id = aws_kms_key.workload.arn
  tags   = local.common_tags
}

resource "aws_ssm_parameter" "model_manifest" {
  name        = "${local.parameter_prefix}/ollama/model_manifest"
  description = "Pinned model names, digests, and capacity metadata"
  type        = "SecureString"
  value       = jsonencode(var.model_manifest)
  key_id      = aws_kms_key.workload.arn
  tags        = local.common_tags
}
