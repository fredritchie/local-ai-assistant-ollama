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
  default     = null

  validation {
    condition = var.allowed_ssh_cidr == null || (
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

variable "enable_ssh" {
  description = "Whether to create an SSH key and allow trusted SSH ingress."
  type        = bool
  default     = false
}

variable "server_configuration" {
  description = "Server configuration system: cloud-init bootstrap or external Ansible."
  type        = string
  default     = "cloud-init"

  validation {
    condition     = contains(["cloud-init", "ansible"], var.server_configuration)
    error_message = "server_configuration must be either cloud-init or ansible."
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

  validation {
    condition     = can(regex("^https://[^[:space:]\"']+$", var.repository_url))
    error_message = "repository_url must be a public HTTPS URL without whitespace or quotes."
  }
}

variable "repository_branch" {
  description = "Git branch deployed onto the instance."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.repository_branch))
    error_message = "repository_branch contains unsupported characters."
  }
}

variable "repository_commit" {
  description = "Optional immutable Git commit to deploy after cloning the branch."
  type        = string
  default     = null

  validation {
    condition = (
      var.repository_commit == null ||
      can(regex("^[0-9a-fA-F]{7,40}$", var.repository_commit))
    )
    error_message = "repository_commit must be null or a 7-to-40-character Git SHA."
  }
}

variable "deployment_mode" {
  description = "Application runtime: native systemd process or Docker container."
  type        = string
  default     = "native"

  validation {
    condition     = contains(["native", "docker"], var.deployment_mode)
    error_message = "deployment_mode must be either native or docker."
  }
}

variable "ollama_version" {
  description = "Pinned Ollama version installed during server configuration."
  type        = string
  default     = "0.32.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.ollama_version))
    error_message = "ollama_version must use semantic version format, such as 0.32.0."
  }
}

variable "force_destroy_skip_os_shutdown" {
  description = "Force EC2 termination and skip OS shutdown during destroy."
  type        = bool
  default     = false
}

variable "ollama_model" {
  description = "Primary Ollama model pulled during server configuration."
  type        = string
  default     = "llama3.2:3b"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+(:[A-Za-z0-9._-]+)?$", var.ollama_model))
    error_message = "ollama_model must be a valid Ollama model name without spaces."
  }
}

variable "additional_ollama_models" {
  description = "Additional Ollama models pulled during server configuration."
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
