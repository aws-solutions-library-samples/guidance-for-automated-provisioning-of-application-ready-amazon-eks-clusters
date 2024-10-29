locals {
  cluster_name    = "${var.shared_config.resources_prefix}-${terraform.workspace}"
  region          = data.aws_region.current.id
  tfstate_region  = try(var.tfstate_region, local.region)
  cluster_version = var.cluster_config.kubernetes_version

  private_subnet_ids       = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  control_plane_subnet_ids = try(var.cluster_config.use_intra_subnets, true) ? data.terraform_remote_state.vpc.outputs.intra_subnet_ids : local.private_subnet_ids

  capabilities = {
    networking   = try(var.cluster_config.capabilities.networking, true)
    coredns      = try(var.cluster_config.capabilities.coredns, true)
    identity     = try(var.cluster_config.capabilities.identity, true)
    autoscaling  = try(var.cluster_config.capabilities.autoscaling, true)
    blockstorage = try(var.cluster_config.capabilities.blockstorage, true)
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
      "provisioned-by" : "aws-samples/terraform-workloads-ready-eks-accelerator"
    }
  )
}
