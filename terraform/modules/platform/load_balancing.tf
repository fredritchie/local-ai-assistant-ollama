resource "aws_security_group" "public_alb" {
  name_prefix = "${local.name_prefix}-public-alb-"
  description = "Public HTTP and optional HTTPS entry point"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from approved clients"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = var.allowed_app_cidrs
  }

  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      description = "HTTPS from approved clients"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_blocks = var.allowed_app_cidrs
    }
  }

  egress {
    description = "Nginx targets in the VPC"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  description = "Private Streamlit application instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Nginx from public ALB"
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.public_alb.id]
  }

  egress {
    description = "HTTPS package, ECR, SSM, and telemetry access"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP package repositories"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Internal Ollama API"
    protocol    = "tcp"
    from_port   = 11434
    to_port     = 11434
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description     = "PostgreSQL to the chat database"
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.database.id]
  }

  egress {
    description = "VPC DNS"
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "VPC DNS over TCP"
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Amazon Time Sync Service"
    protocol    = "udp"
    from_port   = 123
    to_port     = 123
    cidr_blocks = ["169.254.169.123/32"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-app" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ollama_alb" {
  name_prefix = "${local.name_prefix}-ollama-alb-"
  description = "Internal Ollama load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Ollama API from application instances"
    protocol        = "tcp"
    from_port       = 11434
    to_port         = 11434
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Ollama targets in the VPC"
    protocol    = "tcp"
    from_port   = 11434
    to_port     = 11434
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ollama-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "gpu" {
  name_prefix = "${local.name_prefix}-gpu-"
  description = "Private Ollama GPU instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Ollama API from internal ALB"
    protocol        = "tcp"
    from_port       = 11434
    to_port         = 11434
    security_groups = [aws_security_group.ollama_alb.id]
  }

  egress {
    description = "HTTPS model, package, SSM, and telemetry access"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP package repositories"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "VPC DNS"
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "VPC DNS over TCP"
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Amazon Time Sync Service"
    protocol    = "udp"
    from_port   = 123
    to_port     = 123
    cidr_blocks = ["169.254.169.123/32"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-gpu" })

  lifecycle {
    create_before_destroy = true
  }
}

#checkov:skip=CKV_AWS_150:Deletion protection is enabled in prod and intentionally disabled in the disposable dev environment.
#checkov:skip=CKV2_AWS_20:TLS redirect is enabled when an ACM certificate is supplied; port 80 is an explicit portfolio requirement.
#checkov:skip=CKV2_AWS_76:The associated WAF includes AWSManagedRulesKnownBadInputsRuleSet, which contains Log4JRCE protection.
resource "aws_lb" "public" {
  name                       = substr("${local.name_prefix}-public", 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.public_alb.id]
  subnets                    = aws_subnet.public[*].id
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true
  idle_timeout               = 300

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "public"
    enabled = true
  }

  tags = local.common_tags

  depends_on = [aws_s3_bucket_policy.alb_logs]

  lifecycle {
    precondition {
      condition     = !var.enable_https || var.certificate_arn != null
      error_message = "certificate_arn must be provided when enable_https is true."
    }
  }
}

#checkov:skip=CKV_AWS_378:ALB-to-Nginx traffic stays inside private subnets and is restricted by security-group identity.
resource "aws_lb_target_group" "app" {
  name                 = substr("${local.name_prefix}-app", 0, 32)
  port                 = 80
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
    path                = "/healthz"
    protocol            = "HTTP"
  }

  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 3600
  }

  tags = local.common_tags
}

#checkov:skip=CKV_AWS_2:HTTP is an explicit requirement; enabling ACM changes this listener to a redirect.
#checkov:skip=CKV_AWS_103:TLS policy applies to the optional HTTPS listener; this listener is HTTP or redirect-only.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener_rule" "http_to_https" {
  count = var.enable_https ? 1 : 0

  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  depends_on = [aws_lb_listener.https]
}

#checkov:skip=CKV_AWS_150:Deletion protection follows the environment setting and is enabled in prod.
#checkov:skip=CKV2_AWS_20:This is an internal-only service ALB with no public listener or certificate.
resource "aws_lb" "ollama" {
  name                       = substr("${local.name_prefix}-ollama", 0, 32)
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ollama_alb.id]
  subnets                    = aws_subnet.gpu[*].id
  idle_timeout               = 600
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "internal"
    enabled = true
  }

  tags = local.common_tags

  depends_on = [aws_s3_bucket_policy.alb_logs]
}

#checkov:skip=CKV_AWS_378:Internal Ollama HTTP traffic is identity-restricted between private security groups.
resource "aws_lb_target_group" "ollama" {
  name                 = substr("${local.name_prefix}-ollama", 0, 32)
  port                 = 11434
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 60

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 10
    matcher             = "200"
    path                = "/api/tags"
    protocol            = "HTTP"
  }

  tags = local.common_tags
}

#checkov:skip=CKV_AWS_2:Ollama is private, IAM-isolated, and not assigned a public TLS identity.
#checkov:skip=CKV_AWS_103:This listener is internal HTTP; external TLS terminates at the public ALB.
resource "aws_lb_listener" "ollama" {
  load_balancer_arn = aws_lb.ollama.arn
  port              = 11434
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ollama.arn
  }
}
