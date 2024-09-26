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

# variable "observability_configuration" {
#   description = "observability configuration variable"

#   type = object({
#     aws_oss_tooling    = bool
#     aws_native_tooling = bool
#     aws_oss_tooling_config = object({
#       enable_managed_collector = bool
#       enable_adot_collector    = bool
#       prometheus_name          = string
#       enable_grafana_operator  = bool
#     })
#   })
# }
