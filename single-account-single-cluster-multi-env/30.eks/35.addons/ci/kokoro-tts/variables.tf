variable "github_repo_url" {
  description = "URL of the GitHub repository containing the Kokoro TTS code"
  type        = string
  default     = "https://github.com/omototo/kubecon.git"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
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

variable "create_webhook" {
  description = "Whether to create a GitHub webhook for automatic builds"
  type        = bool
  default     = false
} 