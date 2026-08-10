data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }

}

resource "aws_iam_role" "app" {
  name_prefix        = "${local.name_prefix}-app-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role" "gpu" {
  name_prefix        = "${local.name_prefix}-gpu-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "app_ssm_core" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "gpu_ssm_core" {
  role       = aws_iam_role.gpu.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#checkov:skip=CKV_AWS_111:CloudWatch PutMetricData and X-Ray write APIs do not support resource-level permissions.
#checkov:skip=CKV_AWS_356:CloudWatch PutMetricData and X-Ray write APIs require a wildcard resource; all readable data remains scoped.
data "aws_iam_policy_document" "app" {
  statement {
    sid = "PullApplicationImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/*"]
  }

  statement {
    sid       = "DecryptRuntimeParameters"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.workload.arn]
  }

  statement {
    sid       = "AuthenticateToECR"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ReadRuntimeParameters"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_prefix}/*"]
  }

  dynamic "statement" {
    for_each = length(local.app_secret_arns) > 0 ? [1] : []
    content {
      sid       = "ReadApprovedSecrets"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = local.app_secret_arns
    }
  }

  statement {
    sid = "PublishTelemetry"
    actions = [
      "cloudwatch:PutMetricData",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "xray:PutTelemetryRecords",
      "xray:PutTraceSegments",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "${local.name_prefix}-app-runtime"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

#checkov:skip=CKV_AWS_111:CloudWatch PutMetricData does not support resource-level permissions.
#checkov:skip=CKV_AWS_356:CloudWatch PutMetricData requires a wildcard resource; model parameters remain scoped.
data "aws_iam_policy_document" "gpu" {
  statement {
    sid = "ReadModelConfiguration"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_prefix}/ollama/*"]
  }

  statement {
    sid       = "DecryptModelParameters"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.workload.arn]
  }

  statement {
    sid = "PublishTelemetry"
    actions = [
      "cloudwatch:PutMetricData",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "gpu" {
  name   = "${local.name_prefix}-gpu-runtime"
  role   = aws_iam_role.gpu.id
  policy = data.aws_iam_policy_document.gpu.json
}

resource "aws_iam_instance_profile" "app" {
  name_prefix = "${local.name_prefix}-app-"
  role        = aws_iam_role.app.name
  tags        = local.common_tags
}

resource "aws_iam_instance_profile" "gpu" {
  name_prefix = "${local.name_prefix}-gpu-"
  role        = aws_iam_role.gpu.name
  tags        = local.common_tags
}
