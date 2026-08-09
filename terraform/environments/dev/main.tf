module "platform" {
  source = "../../modules/platform"

  aws_region        = var.aws_region
  environment       = "dev"
  vpc_cidr          = "10.30.0.0/16"
  allowed_app_cidrs = var.allowed_app_cidrs
  nat_gateway_mode  = "single"
  app_instance_type = var.app_instance_type
  app_capacity      = { min = 1, desired = 1, max = 2 }
  gpu_capacity      = { min = 1, desired = 1, max = 1 }
  app_image_uri     = var.app_image_uri
  app_ami_id        = var.app_ami_id
  gpu_ami_id        = var.gpu_ami_id
  model_manifest = jsondecode(file(
    startswith(var.model_manifest_file, "/") ?
    var.model_manifest_file : abspath("${path.module}/${var.model_manifest_file}")
  ))
  model_snapshot_id          = var.model_snapshot_id
  enable_https               = var.enable_https
  enable_waf                 = false
  certificate_arn            = var.certificate_arn
  log_retention_days         = 7
  alarm_email                = var.alarm_email
  secret_arns                = var.secret_arns
  enable_deletion_protection = false
}
