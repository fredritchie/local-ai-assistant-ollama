variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "app_image_uri" {
  description = "Immutable ECR image URI with digest."
  type        = string
}

variable "model_manifest_file" {
  description = "Path to a locked model manifest JSON file."
  type        = string
  default     = "../../../models/model-manifest.example.json"
}

variable "model_snapshot_id" {
  type    = string
  default = null
}

variable "allowed_app_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "app_instance_type" {
  type    = string
  default = "t4g.small"
}

variable "app_ami_id" {
  type    = string
  default = null
}

variable "gpu_ami_id" {
  type    = string
  default = null
}

variable "enable_https" {
  type    = bool
  default = false
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "enable_duckdns" {
  type    = bool
  default = false
}

variable "duckdns_subdomain" {
  type    = string
  default = null
}

variable "alarm_email" {
  type    = string
  default = null
}

variable "secret_arns" {
  type    = list(string)
  default = []
}
