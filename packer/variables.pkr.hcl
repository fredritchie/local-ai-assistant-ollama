variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "local-ai-assistant"
}

variable "ollama_version" {
  type    = string
  default = "0.32.0"
}

variable "gpu_source_ami" {
  description = "Current Ubuntu 24.04 NVIDIA GPU DLAMI ID from AWS SSM."
  type        = string
  default     = "ami-00000000000000000"
}
