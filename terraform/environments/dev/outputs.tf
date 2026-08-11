output "application_url" {
  value = module.platform.application_url
}

output "application_health_url" {
  value = module.platform.application_health_url
}

output "app_autoscaling_group_name" {
  value = module.platform.app_autoscaling_group_name
}

output "gpu_autoscaling_group_name" {
  value = module.platform.gpu_autoscaling_group_name
}

output "instance_connect_endpoint_id" {
  description = "EC2 Instance Connect Endpoint used to administer private instances."
  value       = module.platform.instance_connect_endpoint_id
}

output "dashboard_name" {
  value = module.platform.dashboard_name
}

output "duckdns_fqdn" {
  value = module.platform.duckdns_fqdn
}

output "duckdns_ipv4" {
  value = module.platform.duckdns_ipv4
}

output "global_accelerator_ipv4_addresses" {
  value = module.platform.global_accelerator_ipv4_addresses
}

output "database_endpoint" {
  description = "Private RDS PostgreSQL endpoint for persistent users and chat history."
  value       = module.platform.database_endpoint
}

output "database_secret_arn" {
  description = "RDS-managed Secrets Manager credential ARN used by the application."
  value       = module.platform.database_secret_arn
}

output "health_alert_topic_arn" {
  description = "SNS topic publishing application and Ollama health-check alerts."
  value       = module.platform.alarm_topic_arn
}
