data "aws_ec2_instance_type_offerings" "gpu" {
  filter {
    name   = "instance-type"
    values = [var.gpu_instance_type]
  }

  location_type = "availability-zone"
}

data "aws_ssm_parameter" "ubuntu_amd64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_ssm_parameter" "ubuntu_arm64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

data "aws_ssm_parameter" "gpu_dlami" {
  name = "/aws/service/deeplearning/ami/x86_64/base-with-single-cuda-ubuntu-24.04/latest/ami-id"
}

data "aws_caller_identity" "current" {}

locals {
  availability_zones = slice(sort(tolist(data.aws_ec2_instance_type_offerings.gpu.locations)), 0, 2)
  app_ami_id = coalesce(
    var.app_ami_id,
    startswith(var.app_instance_type, "t4g.") ? data.aws_ssm_parameter.ubuntu_arm64.value : data.aws_ssm_parameter.ubuntu_amd64.value,
  )
  gpu_ami_id       = coalesce(var.gpu_ami_id, data.aws_ssm_parameter.gpu_dlami.value)
  primary_model    = var.model_manifest[0].name
  parameter_prefix = "/${var.project_name}/${var.environment}"
  name_prefix      = "${var.project_name}-${var.environment}"
  public_hostname  = var.enable_duckdns ? "${var.duckdns_subdomain}.duckdns.org" : aws_lb.public.dns_name
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  })
}

check "gpu_failure_domains" {
  assert {
    condition     = length(data.aws_ec2_instance_type_offerings.gpu.locations) >= 2
    error_message = "The selected GPU instance type must be offered in at least two Availability Zones."
  }
}

check "duckdns_configuration" {
  assert {
    condition     = !var.enable_duckdns || (var.duckdns_subdomain != null && var.duckdns_subdomain != "")
    error_message = "duckdns_subdomain is required when enable_duckdns is true."
  }
}
