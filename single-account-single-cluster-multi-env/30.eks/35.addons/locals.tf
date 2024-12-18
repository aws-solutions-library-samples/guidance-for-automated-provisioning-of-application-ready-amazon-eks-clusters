locals {
  region         = data.aws_region.current.id
  tfstate_region = try(var.tfstate_region, local.region)
  eks_auto_mode  = try(var.cluster_config.eks_auto_mode, false)

  capabilities = {
    loadbalancing = try(var.cluster_config.capabilities.loadbalancing, !local.eks_auto_mode, true)
    gitops        = try(var.cluster_config.capabilities.gitops, true)
  }

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
