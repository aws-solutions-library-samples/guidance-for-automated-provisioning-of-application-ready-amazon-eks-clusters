vpc_cidr = "10.5.0.0/16"

# custom tags to apply to all resources
tags = {
}

shared_config = {
  resources_prefix = "wre" // WRE = Workload Ready EKS
}

cluster_config = {
  kubernetes_version  = "1.29"
  eks_auto_mode       = true
  private_eks_cluster = false
  create_mng_system   = false // CriticalAddons MNG NodeGroup
  // When eks_auto_mode = true, those are false by default
  // Except: gitops
  capabilities = {
    kube_proxy    = false // kube proxy
    networking    = false // VPC CNI
    coredns       = false // CoreDNS
    identity      = false // Pod Identity
    autoscaling   = false // Karpenter
    blockstorage  = false // EBS CSI Driver
    loadbalancing = false // LB Controller
    gitops        = false // ArgocD
  }
}

# Observability variables
observability_configuration = {
  aws_oss_tooling    = false
  aws_native_tooling = true
  aws_oss_tooling_config = {
    sso_region               = "us-east-1" // IAM Identity Center fka SSO region
    enable_managed_collector = true
    enable_adot_collector    = false
    prometheus_name          = "prom"
    enable_grafana_operator  = true
  }
}
