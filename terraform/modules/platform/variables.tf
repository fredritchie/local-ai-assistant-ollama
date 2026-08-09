variable "aws_region" {
  description = "AWS region for the workload."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix for resources."
  type        = string
  default     = "local-ai-assistant"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the workload VPC."
  type        = string
  default     = "10.30.0.0/16"
}

variable "allowed_app_cidrs" {
  description = "IPv4 CIDRs allowed to reach the public ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_app_cidrs) > 0 && alltrue([for cidr in var.allowed_app_cidrs : can(cidrnetmask(cidr))])
    error_message = "allowed_app_cidrs must contain valid IPv4 CIDRs."
  }
}

variable "nat_gateway_mode" {
  description = "Use one NAT gateway for cost savings or one per AZ for availability."
  type        = string
  default     = "per_az"

  validation {
    condition     = contains(["single", "per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be single or per_az."
  }
}

variable "app_instance_type" {
  description = "Instance type used by the Streamlit ASG."
  type        = string
  default     = "t4g.small"

  validation {
    condition     = can(regex("^(t3|t3a|t4g)\\.(small|medium|large)$", var.app_instance_type))
    error_message = "Use a supported t3, t3a, or t4g application instance type."
  }
}

variable "gpu_instance_type" {
  description = "Instance type used by the Ollama ASG."
  type        = string
  default     = "g4dn.xlarge"

  validation {
    condition     = var.gpu_instance_type == "g4dn.xlarge"
    error_message = "This portfolio stack is tested with g4dn.xlarge."
  }
}

variable "app_capacity" {
  description = "Minimum, desired, and maximum application ASG capacity."
  type = object({
    min     = number
    desired = number
    max     = number
  })
  default = {
    min     = 2
    desired = 2
    max     = 4
  }

  validation {
    condition = (
      var.app_capacity.min >= 1 &&
      var.app_capacity.desired >= var.app_capacity.min &&
      var.app_capacity.max >= var.app_capacity.desired
    )
    error_message = "App capacity must satisfy 1 <= min <= desired <= max."
  }
}

variable "gpu_capacity" {
  description = "Minimum, desired, and maximum Ollama ASG capacity. Use two for production HA."
  type = object({
    min     = number
    desired = number
    max     = number
  })
  default = {
    min     = 2
    desired = 2
    max     = 2
  }

  validation {
    condition = (
      var.gpu_capacity.min >= 1 &&
      var.gpu_capacity.desired >= var.gpu_capacity.min &&
      var.gpu_capacity.max >= var.gpu_capacity.desired
    )
    error_message = "GPU capacity must satisfy 1 <= min <= desired <= max."
  }
}

variable "app_image_uri" {
  description = "Immutable ECR image reference, including an @sha256 digest."
  type        = string

  validation {
    condition     = can(regex("\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+@sha256:[0-9a-f]{64}$", var.app_image_uri))
    error_message = "app_image_uri must be an immutable ECR image URI with a sha256 digest."
  }
}

variable "app_ami_id" {
  description = "Optional Packer-built app AMI. Null uses the current Canonical Ubuntu AMI."
  type        = string
  default     = null
}

variable "gpu_ami_id" {
  description = "Optional Packer-built GPU AMI. Null uses the current AWS DLAMI."
  type        = string
  default     = null
}

variable "ollama_version" {
  description = "Pinned Ollama version."
  type        = string
  default     = "0.32.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.ollama_version))
    error_message = "ollama_version must be a semantic version."
  }
}

variable "model_manifest" {
  description = "Pinned models and expected Ollama SHA256 digests."
  type = list(object({
    name     = string
    digest   = string
    preload  = bool
    size_gib = number
    vram_gib = number
  }))

  validation {
    condition = length(var.model_manifest) > 0 && alltrue([
      for model in var.model_manifest :
      can(regex("^[A-Za-z0-9._/-]+:[A-Za-z0-9._-]+$", model.name)) &&
      can(regex("^sha256:[0-9a-f]{64}$", model.digest)) &&
      model.digest != "sha256:0000000000000000000000000000000000000000000000000000000000000000" &&
      model.size_gib > 0 && model.vram_gib > 0
    ])
    error_message = "Every model needs a versioned name, sha256 digest, and positive size/VRAM values."
  }
}

variable "model_snapshot_id" {
  description = "Optional EBS snapshot containing a verified Ollama model cache."
  type        = string
  default     = null

  validation {
    condition     = var.model_snapshot_id == null || can(regex("^snap-[0-9a-f]+$", var.model_snapshot_id))
    error_message = "model_snapshot_id must be null or an EBS snapshot ID."
  }
}

variable "app_root_volume_size" {
  description = "Application root volume size in GiB."
  type        = number
  default     = 24
}

variable "gpu_root_volume_size" {
  description = "GPU host root volume size in GiB."
  type        = number
  default     = 80
}

variable "model_volume_size" {
  description = "Dedicated model cache volume size in GiB."
  type        = number
  default     = 150

  validation {
    condition     = var.model_volume_size >= 50
    error_message = "model_volume_size must be at least 50 GiB."
  }
}

variable "enable_https" {
  description = "Enable ALB HTTPS and redirect HTTP to HTTPS."
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Protect the public ALB with AWS WAF managed and rate-limit rules."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Maximum requests per five-minute WAF evaluation window per source IP."
  type        = number
  default     = 1000

  validation {
    condition     = var.waf_rate_limit >= 100
    error_message = "waf_rate_limit must be at least 100 requests per five minutes."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN required when HTTPS is enabled."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period."
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Optional email address for SNS alarms. Confirmation is required."
  type        = string
  default     = null
}

variable "secret_arns" {
  description = "Optional Secrets Manager ARNs the app may read. Secret values are never managed here."
  type        = list(string)
  default     = []
}

variable "request_timeout_seconds" {
  description = "Ollama request timeout exposed through Parameter Store."
  type        = number
  default     = 300
}

variable "default_temperature" {
  description = "Default model temperature."
  type        = number
  default     = 0.7
}

variable "max_history_messages" {
  description = "Maximum chat history sent to Ollama."
  type        = number
  default     = 20
}

variable "enable_deletion_protection" {
  description = "Protect ALBs from accidental deletion."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to resources."
  type        = map(string)
  default     = {}
}
