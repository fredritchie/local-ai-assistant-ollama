#checkov:skip=CKV_AWS_338:Environment-specific retention balances incident response with the high cost of verbose AI logs.
resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/${var.environment}/app"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.workload.arn
  tags              = local.common_tags
}

#checkov:skip=CKV_AWS_338:Environment-specific retention balances investigations and cost.
resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/${var.project_name}/${var.environment}/nginx"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.workload.arn
  tags              = local.common_tags
}

#checkov:skip=CKV_AWS_338:Environment-specific retention balances investigations and cost.
resource "aws_cloudwatch_log_group" "ollama" {
  name              = "/${var.project_name}/${var.environment}/ollama"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.workload.arn
  tags              = local.common_tags
}

#checkov:skip=CKV_AWS_338:Bootstrap logs are retained for the configured operational window rather than one year.
resource "aws_cloudwatch_log_group" "bootstrap" {
  name              = "/${var.project_name}/${var.environment}/bootstrap"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.workload.arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "database_bootstrap" {
  name              = "/${var.project_name}/${var.environment}/database-bootstrap"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.workload.arn
  tags              = local.common_tags
}

resource "aws_sns_topic" "alarms" {
  name              = "${local.name_prefix}-alarms"
  kms_master_key_id = aws_kms_key.workload.arn
  tags              = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "public_alb_5xx" {
  alarm_name          = "${local.name_prefix}-public-alb-5xx"
  alarm_description   = "Public ALB is returning server errors"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.public.arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "app_unhealthy" {
  alarm_name          = "${local.name_prefix}-app-unhealthy"
  alarm_description   = "One or more Streamlit targets are unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.public.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "gpu_unhealthy" {
  alarm_name          = "${local.name_prefix}-gpu-unhealthy"
  alarm_description   = "One or more Ollama targets are unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.ollama.arn_suffix
    TargetGroup  = aws_lb_target_group.ollama.arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "app_latency" {
  alarm_name          = "${local.name_prefix}-app-latency"
  alarm_description   = "Application target latency is elevated"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 3
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.public.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "certificate_expiry" {
  count = var.enable_https ? 1 : 0

  alarm_name          = "${local.name_prefix}-certificate-expiry"
  alarm_description   = "The imported or ACM-managed TLS certificate has fewer than 30 days remaining"
  namespace           = "AWS/CertificateManager"
  metric_name         = "DaysToExpiry"
  statistic           = "Minimum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 30
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    CertificateArn = var.certificate_arn
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-operations"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "Public request rate and errors"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.public.arn_suffix, { stat = "Sum" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { stat = "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum" }],
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "Target health"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.public.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.ollama.arn_suffix, "TargetGroup", aws_lb_target_group.ollama.arn_suffix],
          ]
          period = 60
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "Auto Scaling capacity"
          region = var.aws_region
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceCapacity", "AutoScalingGroupName", aws_autoscaling_group.app.name],
            ["AWS/AutoScaling", "GroupInServiceCapacity", "AutoScalingGroupName", aws_autoscaling_group.gpu.name],
          ]
          period = 60
        }
      },
      {
        type   = "log"
        width  = 12
        height = 6
        properties = {
          title  = "Recent application errors"
          region = var.aws_region
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, @message | filter @message like /ERROR|error/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
    ]
  })
}
