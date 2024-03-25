locals {
  # environment     = terraform.workspace
  name            = "${terraform.workspace}-cluster"
  region          = data.aws_region.current.id
  cluster_version = var.cluster_config.kubernetes_version


  tags = merge(
    var.tags,
    {
    }
  )
}
