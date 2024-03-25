# Prod environment variables 
vpc_cidr = "10.1.0.0/16"


tags = {
  Environment    = "prod"
  provisioned-by = "eks-accelerator-for-tf"
}

kubernetes_version = 1.28

# Observability variables 
observability_configuration = {
  aws_oss_tooling    = true
  aws_native_tooling = false
  aws_oss_tooling_config = {
    enable_managed_collector       = true
    enable_self_managed_collectors = false
    prometheus_name                = "prom"
    enable_grafana_operator        = true

  }
}
