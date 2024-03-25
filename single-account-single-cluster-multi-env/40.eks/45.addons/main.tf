data "aws_region" "current" {}
provider "aws" {
  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name, "--region", local.region]

    }
  }
}


provider "kubectl" {
  apply_retry_count      = 5
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name, "--region", local.region]

  }
}
provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name, "--region", local.region]
  }
}

locals {
  environment = terraform.workspace
  region      = data.aws_region.current.id
}
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16.1"

  cluster_name      = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint  = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_version   = data.terraform_remote_state.eks.outputs.kubernetes_version
  oidc_provider_arn = data.terraform_remote_state.eks.outputs.oidc_provider_arn

  create_kubernetes_resources = true

  # common addons deployed with EKS Blueprints Addons
  enable_aws_load_balancer_controller = true


  # Common addons needed for Observability Accerelrator w/ AMP (cert_manager, external secrets)
  #  ADOT will be deployed as part of the observability accelerator as it's needed specifically for AMP deployment

  enable_external_secrets = try(var.observability_configuration.aws_oss_tooling, false)
  enable_cert_manager     = try(var.observability_configuration.aws_oss_tooling, false)

  enable_aws_for_fluentbit = try(var.observability_configuration.aws_oss_tooling, false)
  aws_for_fluentbit_cw_log_group = {
    name            = "/aws/eks/${data.terraform_remote_state.eks.outputs.cluster_name}/aws-fluentbit-logs"
    use_name_prefix = false
    create          = true
  }

  # CW Container Insights 
  enable_aws_cloudwatch_metrics = try(var.observability_configuration.aws_native_tooling, false)

  # GitOps 
  enable_argocd = true
  argocd = {
    enabled = true
    # The following settings are required to be set to true to ensure the
    # argocd application is deployed
    create_argocd_application   = true
    create_kubernetes_resources = true
    enable_argocd               = true
    argocd_namespace            = "argocd"
    /*values = [templatefile("values.yaml", {
      ENV     = local.environment
      FQDN    = var.domain_name
      LB_NAME = "test-public-application"
    })]*/
  }
}


resource "null_resource" "clean_up_argocd_resources" {
  triggers = {
    argocd           = module.eks_blueprints_addons.argocd.name
    eks_cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
  }
  provisioner "local-exec" {
    command     = <<-EOT
      kubeconfig=/tmp/tf.clean_up_argocd.kubeconfig.yaml
      aws eks update-kubeconfig --name ${self.triggers.eks_cluster_name} --kubeconfig $kubeconfig
      rm -f /tmp/tf.clean_up_argocd_resources.err.log
      kubectl --kubeconfig $kubeconfig get Application -A -o name | xargs -I {} kubectl --kubeconfig $kubeconfig -n argocd patch -p '{"metadata":{"finalizers":null}}' --type=merge {} 2> /tmp/tf.clean_up_argocd_resources.err.log || true
      kubectl --kubeconfig $kubeconfig get appprojects -A -o name | xargs -I {} kubectl --kubeconfig $kubeconfig -n argocd patch -p '{"metadata":{"finalizers":null}}' --type=merge {} 2> /tmp/tf.clean_up_argocd_resources.err.log || true
      rm -f $kubeconfig
    EOT
    interpreter = ["bash", "-c"]
    when        = destroy
  }
}

# # ArgoCD Application example
# resource "kubectl_manifest" "argocd_app" {
#   yaml_body = templatefile("app_example/app_manifest.yaml", {
#     ENV = local.environment
#   })
# }

# resource "kubernetes_namespace" "dev" {
#   metadata {
#     name = "dev"
#   }
# }


