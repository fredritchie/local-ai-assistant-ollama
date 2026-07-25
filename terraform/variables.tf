variable "aws_region" {
  description = "AWS region in which to create all resources."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix used for resources and tags."
  type        = string
  default     = "local-ai-assistant"
}

variable "environment" {
  description = "Environment tag applied to the resources."
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the new VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR for the public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "allowed_ssh_cidr" {
  description = "Trusted public IPv4 CIDR allowed to SSH, normally YOUR_IP/32."
  type        = string

  validation {
    condition = (
      can(cidrnetmask(var.allowed_ssh_cidr)) &&
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(2[4-9]|3[0-2])$", var.allowed_ssh_cidr))
    )
    error_message = "allowed_ssh_cidr must be a valid IPv4 /24 or narrower CIDR; /32 is recommended."
  }
}

variable "allowed_app_cidr" {
  description = "Trusted public IPv4 CIDR allowed to access Streamlit on port 8501."
  type        = string

  validation {
    condition = (
      can(cidrnetmask(var.allowed_app_cidr)) &&
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(2[4-9]|3[0-2])$", var.allowed_app_cidr))
    )
    error_message = "allowed_app_cidr must be a valid IPv4 /24 or narrower CIDR; /32 is recommended."
  }
}

variable "key_name" {
  description = "Name of the EC2 key pair Terraform creates in ap-south-1."
  type        = string
  default     = "local_llm_aws_vm_key"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.key_name))
    error_message = "key_name may only contain letters, numbers, periods, underscores, and hyphens."
  }
}

variable "instance_type" {
  description = "EC2 GPU instance type."
  type        = string
  default     = "g4dn.xlarge"

  validation {
    condition     = var.instance_type == "g4dn.xlarge"
    error_message = "This stack is configured to use g4dn.xlarge."
  }
}

variable "root_volume_size" {
  description = "Size of the encrypted gp3 root volume in GiB."
  type        = number
  default     = 100

  validation {
    condition     = var.root_volume_size >= 50
    error_message = "root_volume_size must be at least 50 GiB for the DLAMI and models."
  }
}

variable "repository_url" {
  description = "Public HTTPS Git repository cloned onto the instance."
  type        = string
  default     = "https://github.com/fredritchie/local-ai-assistant-ollama.git"
}

variable "repository_branch" {
  description = "Git branch deployed onto the instance."
  type        = string
  default     = "main"
}

variable "ollama_model" {
  description = "Primary Ollama model pulled during instance bootstrap."
  type        = string
  default     = "llama3.2:3b"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+(:[A-Za-z0-9._-]+)?$", var.ollama_model))
    error_message = "ollama_model must be a valid Ollama model name without spaces."
  }
}

variable "additional_ollama_models" {
  description = "Additional Ollama models pulled during instance bootstrap."
  type        = list(string)
  default = [
    "qwen3:4b",
    "gemma3:4b",
    "phi4-mini:3.8b",
    "deepseek-r1:7b",
    "mistral:7b",
  ]

  validation {
    condition = alltrue([
      for model in var.additional_ollama_models :
      can(regex("^[A-Za-z0-9._/-]+(:[A-Za-z0-9._-]+)?$", model))
    ])
    error_message = "Each additional Ollama model must be a valid model name without spaces."
  }
}
