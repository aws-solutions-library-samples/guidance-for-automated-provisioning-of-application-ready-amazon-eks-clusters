locals {
  cluster_name    = "${var.shared_config.resources_prefix}-${terraform.workspace}"
  region          = data.aws_region.current.id
  cluster_version = var.cluster_config.kubernetes_version

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
    }
  )
}
