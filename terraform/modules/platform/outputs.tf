output "application_url" {
  description = "Public application URL."
  value       = var.enable_https ? "https://${aws_lb.public.dns_name}" : "http://${aws_lb.public.dns_name}"
}

output "application_health_url" {
  description = "Public application health endpoint."
  value       = "${var.enable_https ? "https" : "http"}://${aws_lb.public.dns_name}/healthz"
}

output "public_alb_dns_name" {
  description = "Public ALB DNS name."
  value       = aws_lb.public.dns_name
}

output "ollama_internal_url" {
  description = "Private Ollama load-balancer URL."
  value       = "http://${aws_lb.ollama.dns_name}:11434"
}

output "app_autoscaling_group_name" {
  description = "Application Auto Scaling Group name."
  value       = aws_autoscaling_group.app.name
}

output "gpu_autoscaling_group_name" {
  description = "GPU Auto Scaling Group name."
  value       = aws_autoscaling_group.gpu.name
}

output "dashboard_name" {
  description = "CloudWatch operations dashboard."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "alarm_topic_arn" {
  description = "SNS topic receiving alarm transitions."
  value       = aws_sns_topic.alarms.arn
}

output "parameter_prefix" {
  description = "SSM Parameter Store path used by the application."
  value       = local.parameter_prefix
}

output "vpc_id" {
  description = "Workload VPC ID."
  value       = aws_vpc.main.id
}

output "selected_availability_zones" {
  description = "Failure domains selected for this deployment."
  value       = local.availability_zones
}
