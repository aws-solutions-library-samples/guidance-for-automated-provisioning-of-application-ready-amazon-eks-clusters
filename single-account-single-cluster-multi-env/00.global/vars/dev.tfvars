# Dev environment variables 
vpc_cidr = "10.1.0.0/16"

# custom tags to apply to all resources
tags = {
}

shared_config = {
  resources_prefix = "kubecon" // WRE = Workload Ready EKS 
}

cluster_config = {
  kubernetes_version  = "1.31"
  private_eks_cluster = false
  create_iam_role     = true
  private_eks_cluster = false
  use_intra_subnets   = false
  create_mng_system   = true
  capabilities = {
    networking    = true
    coredns       = true
    identity      = true
    autoscaling   = true
    blockstorage  = true
    loadbalancing = true
    gitops        = false
    #KubeCon demo specific capabilities
    inference     = true
  }
}

# Observability variables 
observability_configuration = {
  aws_oss_tooling    = false
  aws_native_tooling = true
  aws_oss_tooling_config = {
    enable_managed_collector = false
    enable_adot_collector    = false
    prometheus_name          = "prom"
    enable_grafana_operator  = false

  }
}
