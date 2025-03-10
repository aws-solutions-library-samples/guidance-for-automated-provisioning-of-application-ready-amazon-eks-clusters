# Dev environment variables 
vpc_cidr = "10.1.0.0/16"

# custom tags to apply to all resources
tags = {
}

shared_config = {
  resources_prefix = "wre" // WRE = Workload Ready EKS 
}

cluster_config = {
  kubernetes_version  = "1.32"
  private_eks_cluster = false
  create_mng_system   = true // CriticalAddons MNG NodeGroup
  capabilities = {
    kube_proxy    = true // kube proxy
    networking    = true // VPC CNI
    coredns       = true // CoreDNS
    identity      = true // Pod Identity
    autoscaling   = true // Karpenter
    blockstorage  = true // EBS CSI Driver
    loadbalancing = true // LB Controller
    gitops        = true // ArgocD
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
    enable_grafana_operator  = true
  }
}
