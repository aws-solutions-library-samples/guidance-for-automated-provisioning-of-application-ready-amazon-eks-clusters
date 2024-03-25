provider "aws" {
  default_tags {
    tags = local.tags
  }

}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


data "aws_eks_cluster_auth" "this" {
  name = local.eks_cluster_name
  # name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_eks_cluster" "this" {
  name = local.eks_cluster_name
  # name = data.terraform_remote_state.eks.outputs.cluster_name
}

# data "aws_grafana_workspace" "this" {
#   workspace_id = local.grafana_workspace_id
# }

provider "kubernetes" {
  host                   = local.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = local.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
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





