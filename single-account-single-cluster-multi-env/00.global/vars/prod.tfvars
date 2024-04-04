# Prod environment variables
vpc_cidr = "10.0.0.0/16"

tags = {
  provisioned-by = "aws-samples/terraform-workloads-ready-eks-accelerator"
}

shared_config = {
  resources_prefix = "wre" // WRE = Workload Ready EKS
}

cluster_config = {
  kubernetes_version  = 1.28
  private_eks_cluster = false
}

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
