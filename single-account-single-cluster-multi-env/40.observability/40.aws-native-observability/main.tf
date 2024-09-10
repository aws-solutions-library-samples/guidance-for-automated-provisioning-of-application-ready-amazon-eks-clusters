data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  region = data.aws_region.current.id
}
################################################################################
# CW EKS Addon
################################################################################
module "aws_cloudwatch_observability_irsa" {

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"
  count   = var.observability_configuration.aws_native_tooling ? 1 : 0

  role_name = "${data.terraform_remote_state.eks.outputs.cluster_name}-cw-ci"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  oidc_providers = {
    cluster = {
      provider_arn               = data.terraform_remote_state.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:cloudwatch-agent"]
    }
  }
}

module "aws_cloudwatch_observability" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16.2"
  count   = var.observability_configuration.aws_native_tooling ? 1 : 0

  cluster_name      = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint  = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_version   = data.terraform_remote_state.eks.outputs.kubernetes_version
  oidc_provider_arn = data.terraform_remote_state.eks.outputs.oidc_provider_arn

  create_kubernetes_resources = true
  eks_addons = {
    amazon-cloudwatch-observability = {
      most_recent              = true
      service_account_role_arn = module.aws_cloudwatch_observability_irsa[0].iam_role_arn
    }
  }
}


