variable "tfstate_region" {
  description = "region where the terraform state is stored"
  type        = string
  default     = null
}

variable "kms_key_admin_roles" {
  description = "list of role ARNs to add to the KMS policy"
  type        = list(string)
  default     = []

}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "cluster_config" {
  description = "cluster configurations such as version, public/private API endpoint, and more"
  type        = any
  default     = {}
}

variable "shared_config" {
  description = "Shared configuration across all modules/folders"
  type        = map(any)
  default     = {}
}
