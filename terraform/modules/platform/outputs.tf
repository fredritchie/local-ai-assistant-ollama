output "application_url" {
  description = "Public application URL."
  value       = "${var.enable_https ? "https" : "http"}://${local.public_hostname}"
}

output "application_health_url" {
  description = "Public application health endpoint."
  value       = "${var.enable_https ? "https" : "http"}://${local.public_hostname}/healthz"
}

output "duckdns_fqdn" {
  description = "Optional DuckDNS hostname configured outside Terraform."
  value       = var.enable_duckdns ? "${var.duckdns_subdomain}.duckdns.org" : null
}

output "duckdns_ipv4" {
  description = "Primary stable Global Accelerator IPv4 address to publish to DuckDNS."
  value       = var.enable_duckdns ? aws_globalaccelerator_accelerator.public[0].ip_sets[0].ip_addresses[0] : null
}

output "global_accelerator_ipv4_addresses" {
  description = "Both Global Accelerator IPv4 addresses. DuckDNS publishes one; full DNS HA requires a provider supporting multiple A records."
  value       = var.enable_duckdns ? aws_globalaccelerator_accelerator.public[0].ip_sets[0].ip_addresses : []
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

output "database_endpoint" {
  description = "Private PostgreSQL endpoint used for persistent users and chat history."
  value       = aws_db_instance.chat.address
}

output "database_instance_id" {
  description = "RDS instance identifier used by the IAM database-user bootstrap command."
  value       = aws_db_instance.chat.identifier
}

output "database_secret_arn" {
  description = "Secrets Manager ARN containing the RDS master credentials for administration and IAM-user bootstrap only."
  value       = aws_db_instance.chat.master_user_secret[0].secret_arn
}

output "database_iam_username" {
  description = "PostgreSQL user that the application authenticates as through its EC2 IAM role."
  value       = local.database_iam_username
}
