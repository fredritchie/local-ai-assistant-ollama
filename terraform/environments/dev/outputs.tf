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

output "dashboard_name" {
  value = module.platform.dashboard_name
}
