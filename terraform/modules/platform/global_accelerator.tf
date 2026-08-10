resource "aws_globalaccelerator_accelerator" "public" {
  count = var.enable_duckdns ? 1 : 0

  name            = substr("${local.name_prefix}-public", 0, 64)
  enabled         = true
  ip_address_type = "IPV4"

  attributes {
    flow_logs_enabled   = true
    flow_logs_s3_bucket = aws_s3_bucket.alb_logs.id
    flow_logs_s3_prefix = "global-accelerator"
  }

  tags = local.common_tags

  depends_on = [aws_s3_bucket_policy.alb_logs]
}

resource "aws_globalaccelerator_listener" "public" {
  count = var.enable_duckdns ? 1 : 0

  accelerator_arn = aws_globalaccelerator_accelerator.public[0].id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }

  dynamic "port_range" {
    for_each = var.enable_https ? [443] : []
    content {
      from_port = port_range.value
      to_port   = port_range.value
    }
  }
}

resource "aws_globalaccelerator_endpoint_group" "public" {
  count = var.enable_duckdns ? 1 : 0

  listener_arn                  = aws_globalaccelerator_listener.public[0].id
  endpoint_group_region         = var.aws_region
  health_check_interval_seconds = 30
  health_check_path             = "/healthz"
  health_check_port             = 80
  health_check_protocol         = "HTTP"
  threshold_count               = 3

  endpoint_configuration {
    endpoint_id                    = aws_lb.public.arn
    client_ip_preservation_enabled = true
    weight                         = 100
  }
}
