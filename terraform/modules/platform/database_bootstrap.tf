data "aws_iam_policy_document" "database_bootstrap_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "database_bootstrap" {
  name_prefix        = "${local.name_prefix}-db-bootstrap-"
  assume_role_policy = data.aws_iam_policy_document.database_bootstrap_assume.json
  tags               = local.common_tags
}

resource "aws_security_group" "database_bootstrap" {
  name_prefix = "${local.name_prefix}-db-bootstrap-"
  description = "One-time RDS IAM database-user bootstrap job"
  vpc_id      = aws_vpc.main.id

  egress {
    description     = "PostgreSQL to the chat database"
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.database.id]
  }

  egress {
    description = "HTTPS package and AWS API access through NAT"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP Ubuntu package repositories through NAT"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db-bootstrap" })
}

resource "aws_vpc_security_group_ingress_rule" "database_from_bootstrap" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.database_bootstrap.id
  description                  = "PostgreSQL from the IAM database-user bootstrap job"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

data "aws_iam_policy_document" "database_bootstrap" {
  statement {
    sid = "ReadRdsMasterSecretForBootstrap"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [aws_db_instance.chat.master_user_secret[0].secret_arn]
  }

  statement {
    sid       = "DescribeChatDatabase"
    actions   = ["rds:DescribeDBInstances"]
    resources = ["*"]
  }

  statement {
    sid = "WriteBootstrapLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.database_bootstrap.arn}:*"]
  }

  statement {
    sid = "ManageVpcNetworkInterfaces"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "database_bootstrap" {
  name   = "${local.name_prefix}-db-bootstrap"
  role   = aws_iam_role.database_bootstrap.id
  policy = data.aws_iam_policy_document.database_bootstrap.json
}

resource "aws_codebuild_project" "database_bootstrap" {
  name           = "${local.name_prefix}-db-bootstrap"
  description    = "Configures the PostgreSQL IAM user used by the application"
  service_role   = aws_iam_role.database_bootstrap.arn
  build_timeout  = 15
  queued_timeout = 30

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "DB_INSTANCE_ID"
      value = aws_db_instance.chat.identifier
    }

    environment_variable {
      name  = "DB_IAM_USERNAME"
      value = local.database_iam_username
    }
  }

  source {
    type = "NO_SOURCE"

    buildspec = <<-YAML
      version: 0.2
      phases:
        install:
          commands:
            - apt-get update
            - DEBIAN_FRONTEND=noninteractive apt-get install --yes postgresql-client
        build:
          commands:
            - |
              set -eu
              db_json=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" --query 'DBInstances[0].{host:Endpoint.Address,port:Endpoint.Port,name:DBName,secret:MasterUserSecret.SecretArn,status:DBInstanceStatus}' --output json)
              test "$(printf '%s' "$db_json" | jq -r '.status')" = "available"
              db_host=$(printf '%s' "$db_json" | jq -r '.host')
              db_port=$(printf '%s' "$db_json" | jq -r '.port')
              db_name=$(printf '%s' "$db_json" | jq -r '.name')
              secret_arn=$(printf '%s' "$db_json" | jq -r '.secret')
              test "$db_host" != "null" && test "$db_name" != "null" && test "$secret_arn" != "null"
              secret=$(aws secretsmanager get-secret-value --secret-id "$secret_arn" --query SecretString --output text)
              master_username=$(printf '%s' "$secret" | jq -r '.username')
              export PGPASSWORD=$(printf '%s' "$secret" | jq -r '.password')
              psql "host=$db_host port=$db_port dbname=$db_name user=$master_username sslmode=require" --set=ON_ERROR_STOP=1 --set=db_name="$db_name" --set=app_username="$DB_IAM_USERNAME" --command "SELECT format('CREATE ROLE %I LOGIN', :'app_username') WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_username') \gexec" --command 'GRANT rds_iam TO :"app_username"; GRANT CONNECT ON DATABASE :"db_name" TO :"app_username"; GRANT USAGE, CREATE ON SCHEMA public TO :"app_username"; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"app_username"; GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO :"app_username";'
YAML
  }

  vpc_config {
    vpc_id             = aws_vpc.main.id
    subnets            = aws_subnet.app[*].id
    security_group_ids = [aws_security_group.database_bootstrap.id]
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.database_bootstrap.name
      stream_name = "bootstrap"
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db-bootstrap" })

  depends_on = [
    aws_iam_role_policy.database_bootstrap,
    aws_vpc_security_group_ingress_rule.database_from_bootstrap,
  ]
}
