locals {
  cluster_name    = "${var.shared_config.resources_prefix}-${terraform.workspace}"
  region          = data.aws_region.current.id
  tfstate_region  = try(var.tfstate_region, local.region)
  cluster_version = var.cluster_config.kubernetes_version

  enable_karpenter    = try(var.cluster_config.autoscaling_karpenter, true)
  enable_blockstorage = try(var.cluster_config.enable_blockstorage, true)

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
      "provisioned-by" : "aws-samples/terraform-workloads-ready-eks-accelerator"
    }
  )
}
