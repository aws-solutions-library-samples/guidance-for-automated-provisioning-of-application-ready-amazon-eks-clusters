variable "observability_configuration" {
  description = "observability configuration variable"
  type = object({
    aws_oss_tooling        = optional(bool, true)  // AMP & AMG
    aws_native_tooling     = optional(bool, false) // CW
    aws_oss_tooling_config = optional(map(any), {})
  })


  default = {
    aws_oss_tooling    = true
    aws_native_tooling = false
    aws_oss_tooling_config = {
      enable_managed_collector       = true
      enable_self_managed_collectors = false
      prometheus_name                = "prom"
      enable_grafana_operator        = true

    }

  }
  # nullable = false
}

variable "go_config" {
  description = "Grafana Operator configuration"
  type = object({
    create_namespace   = optional(bool, true)
    helm_chart         = optional(string, "oci://ghcr.io/grafana-operator/helm-charts/grafana-operator")
    helm_name          = optional(string, "grafana-operator")
    k8s_namespace      = optional(string, "grafana-operator")
    helm_release_name  = optional(string, "grafana-operator")
    helm_chart_version = optional(string, "v5.5.2")
  })

  default = {
    create_namespace   = true
    helm_chart         = "oci://ghcr.io/grafana-operator/helm-charts/grafana-operator"
    helm_name          = "grafana-operator"
    k8s_namespace      = "grafana-operator"
    helm_release_name  = "grafana-operator"
    helm_chart_version = "v5.5.2"
  }
}

variable "prometheus_name" {
  description = "Amazon Managed Service for Prometheus Name"
  type        = string
  default     = "prom"
}


variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "grafana_admin_email" {
  description = "default email for the grafana-admin user"
  type        = string
  default     = "email@example.com"
}

variable "ne_config" {
  description = "Node exporter configuration"
  type = object({
    create_namespace   = optional(bool, true)
    k8s_namespace      = optional(string, "prometheus-node-exporter")
    helm_chart_name    = optional(string, "prometheus-node-exporter")
    helm_chart_version = optional(string, "4.24.0")
    helm_release_name  = optional(string, "prometheus-node-exporter")
    helm_repo_url      = optional(string, "https://prometheus-community.github.io/helm-charts")
    helm_settings      = optional(map(string), {})
    helm_values        = optional(map(any), {})

    scrape_interval = optional(string, "60s")
    scrape_timeout  = optional(string, "60s")
  })

  default  = {}
  nullable = false
}


variable "ksm_config" {
  description = "Kube State metrics configuration"
  type = object({
    create_namespace   = optional(bool, true)
    k8s_namespace      = optional(string, "kube-system")
    helm_chart_name    = optional(string, "kube-state-metrics")
    helm_chart_version = optional(string, "5.16.1")
    helm_release_name  = optional(string, "kube-state-metrics")
    helm_repo_url      = optional(string, "https://prometheus-community.github.io/helm-charts")
    helm_settings      = optional(map(string), {})
    helm_values        = optional(map(any), {})

    scrape_interval = optional(string, "60s")
    scrape_timeout  = optional(string, "15s")
  })

  default  = {}
  nullable = false
}

variable "shared_config" {
  description = "Shared configuration across all modules/folders"
  type        = map(any)
  default     = {}
}