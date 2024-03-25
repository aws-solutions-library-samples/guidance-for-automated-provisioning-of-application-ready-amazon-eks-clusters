variable "domain_name" {
  description = "The domain name for the ArgoCD server and UI"
  type        = string
  default     = "argocd.example.com"

}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {

  }
}
variable "observability_configuration" {
  description = "observability configuration variable"
  type = object({
    aws_oss_tooling        = optional(bool, true)  // AMP & AMG
    aws_native_tooling     = optional(bool, false) // CW
    aws_oss_tooling_config = optional(map(any), {})
  })
}
