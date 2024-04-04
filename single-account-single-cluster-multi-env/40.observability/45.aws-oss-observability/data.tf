data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


data "aws_eks_cluster_auth" "this" {
  name = local.eks_cluster_name
}

data "aws_eks_cluster" "this" {
  name = local.eks_cluster_name

}
