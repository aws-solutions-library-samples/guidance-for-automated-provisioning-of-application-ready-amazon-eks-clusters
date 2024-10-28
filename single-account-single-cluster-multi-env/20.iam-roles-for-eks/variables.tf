variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {

  }
}

variable "shared_config" {
  description = "Shared configuration across all modules/folders"
  type        = map(any)
  default     = {}
}
