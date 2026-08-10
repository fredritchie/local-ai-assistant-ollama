module "platform" {
  source = "../../modules/platform"

  aws_region        = var.aws_region
  environment       = "prod"
  vpc_cidr          = "10.40.0.0/16"
  allowed_app_cidrs = var.allowed_app_cidrs
  nat_gateway_mode  = "per_az"
  app_instance_type = var.app_instance_type
  app_capacity      = { min = 2, desired = 2, max = 4 }
  gpu_capacity      = { min = 2, desired = 2, max = 2 }
  app_image_uri     = var.app_image_uri
  app_ami_id        = var.app_ami_id
  gpu_ami_id        = var.gpu_ami_id
  model_manifest = jsondecode(file(
    startswith(var.model_manifest_file, "/") ?
    var.model_manifest_file : abspath("${path.module}/${var.model_manifest_file}")
  ))
  model_snapshot_id          = var.model_snapshot_id
  enable_https               = var.enable_https
  enable_duckdns             = var.enable_duckdns
  duckdns_subdomain          = var.duckdns_subdomain
  enable_waf                 = true
  certificate_arn            = var.certificate_arn
  log_retention_days         = 30
  alarm_email                = var.alarm_email
  secret_arns                = var.secret_arns
  enable_deletion_protection = true
}
