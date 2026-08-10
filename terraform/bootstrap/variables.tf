variable "aws_region" {
  description = "AWS region for bootstrap resources."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project resource prefix."
  type        = string
  default     = "local-ai-assistant"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid lowercase S3 bucket name."
  }
}

variable "github_owner" {
  description = "GitHub repository owner allowed to use deployment OIDC."
  type        = string
  default     = "fredritchie"
}

variable "github_repository" {
  description = "GitHub repository allowed to use deployment OIDC."
  type        = string
  default     = "local-ai-assistant-ollama"
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID included in OIDC subjects for repositories using immutable claims."
  type        = string
  default     = null

  validation {
    condition     = var.github_owner_id == null || can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must be null or a numeric GitHub owner ID."
  }
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID included in OIDC subjects for repositories using immutable claims."
  type        = string
  default     = null

  validation {
    condition     = var.github_repository_id == null || can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must be null or a numeric GitHub repository ID."
  }
}

variable "enable_github_oidc" {
  description = "Create the optional GitHub Actions deployment role."
  type        = bool
  default     = false
}

variable "github_environments" {
  description = "Protected GitHub environments allowed to assume the deployment role."
  type        = list(string)
  default     = ["dev", "prod"]
}
