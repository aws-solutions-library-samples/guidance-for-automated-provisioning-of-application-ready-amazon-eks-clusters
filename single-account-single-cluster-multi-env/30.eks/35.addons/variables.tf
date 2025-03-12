variable "tfstate_region" {
  description = "region where the terraform state is stored"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {}
}

variable "cluster_config" {
  description = <<EOT
Cluster configuration supplied by previous Module.
The configuration object should include:
- capabilities: A map of enabled capabilities (e.g., inference)
- examples: A map of example applications to deploy (e.g., deepseek_kokoro)
EOT
  type        = any
}

variable "observability_configuration" {
  description = "Application add-on requirements"
  type        = any
}

variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = ""
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
  default     = ""
}

variable "github_repo_url" {
  description = "URL of the GitHub repository containing the code"
  type        = string
  default     = "https://github.com/omototo/kubecon.git"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}
