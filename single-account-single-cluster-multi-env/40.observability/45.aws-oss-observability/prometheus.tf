
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


data "aws_eks_cluster_auth" "this" {
  name = local.eks_cluster_name
}

data "aws_eks_cluster" "this" {
  name = local.eks_cluster_name

}



locals {
  region               = data.aws_region.current.name
  eks_cluster_endpoint = data.aws_eks_cluster.this.endpoint
  eks_cluster_name     = data.terraform_remote_state.eks.outputs.cluster_name
  environment          = terraform.workspace
  prometheus_name      = "${var.prometheus_name}-${local.environment}"
  tags                 = merge(var.tags, { Environment = terraform.workspace })
}


resource "aws_prometheus_workspace" "this" {

  alias = local.prometheus_name
  tags  = merge(var.tags)
}





