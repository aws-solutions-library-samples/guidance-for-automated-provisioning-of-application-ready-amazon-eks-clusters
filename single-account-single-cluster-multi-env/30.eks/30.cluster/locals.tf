locals {
  cluster_name    = "${var.shared_config.resources_prefix}-${terraform.workspace}"
  region          = data.aws_region.current.id
  tfstate_region  = try(var.tfstate_region, local.region)
  cluster_version = var.cluster_config.kubernetes_version
  eks_auto_mode   = try(var.cluster_config.eks_auto_mode, false)

  private_subnet_ids       = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  control_plane_subnet_ids = try(var.cluster_config.use_intra_subnets, true) ? data.terraform_remote_state.vpc.outputs.intra_subnet_ids : local.private_subnet_ids

  capabilities = {
    kube_proxy   = try(var.cluster_config.capabilities.kube_proxy, !local.eks_auto_mode, true)
    networking   = try(var.cluster_config.capabilities.networking, !local.eks_auto_mode, true)
    coredns      = try(var.cluster_config.capabilities.coredns, !local.eks_auto_mode, true)
    identity     = try(var.cluster_config.capabilities.identity, !local.eks_auto_mode, true)
    autoscaling  = try(var.cluster_config.capabilities.autoscaling, !local.eks_auto_mode, true)
    blockstorage = try(var.cluster_config.capabilities.blockstorage, !local.eks_auto_mode, true)
  }

  create_mng_system = try(var.cluster_config.create_mng_system, !local.eks_auto_mode, true)

  critical_addons_tolerations = {
    tolerations = [
      {
        key      = "CriticalAddonsOnly",
        operator = "Exists",
        effect   = "NoSchedule"
      }
    ]
  }

  tags = merge(
    var.tags,
    {
      "Environment" : terraform.workspace
      "provisioned-by" : "aws-solutions-library-samples/guidance-for-automated-provisioning-of-application-ready-amazon-eks-clusters"
    }
  )
}
