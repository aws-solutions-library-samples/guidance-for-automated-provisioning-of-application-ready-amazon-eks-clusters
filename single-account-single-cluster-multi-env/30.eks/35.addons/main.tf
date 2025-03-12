data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Set local values for AWS region and account ID
locals {
  aws_region = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16.2"

  cluster_name      = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint  = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_version   = data.terraform_remote_state.eks.outputs.kubernetes_version
  oidc_provider_arn = data.terraform_remote_state.eks.outputs.oidc_provider_arn

  create_kubernetes_resources = true

  # common addons deployed with EKS Blueprints Addons
  enable_aws_load_balancer_controller = try(var.cluster_config.capabilities.loadbalancing, true)
  aws_load_balancer_controller = {
    values = [yamlencode(local.critical_addons_tolerations)]
  }

  # external-secrets is being used AMG for grafana auth
  enable_external_secrets = try(var.observability_configuration.aws_oss_tooling, false)
  external_secrets = {
    values = [
      yamlencode({
        tolerations = [local.critical_addons_tolerations.tolerations[0]]
        webhook = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        certController = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
      })
    ]
  }

  # cert-manager as a dependency for ADOT addon
  enable_cert_manager = try(
    var.observability_configuration.aws_oss_tooling
    && var.observability_configuration.aws_oss_tooling_config.enable_adot_collector,
  false)
  cert_manager = {
    values = [
      yamlencode({
        tolerations = [local.critical_addons_tolerations.tolerations[0]]
        webhook = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        cainjector = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
      })
    ]
  }

  # FluentBit 
  enable_aws_for_fluentbit = try(
    var.observability_configuration.aws_oss_tooling
    && !var.observability_configuration.aws_oss_tooling_config.enable_adot_collector
  , false)
  aws_for_fluentbit = {
    values = [
      yamlencode({ "tolerations" : [{ "operator" : "Exists" }] })
    ]
  }
  aws_for_fluentbit_cw_log_group = {
    name            = "/aws/eks/${data.terraform_remote_state.eks.outputs.cluster_name}/aws-fluentbit-logs"
    use_name_prefix = false
    create          = true
  }

  # GitOps 
  enable_argocd = try(var.cluster_config.capabilities.gitops, true)
  argocd = {
    enabled = true
    # The following settings are required to be set to true to ensure the
    # argocd application is deployed
    create_argocd_application   = true
    create_kubernetes_resources = true
    enable_argocd               = true
    argocd_namespace            = "argocd"
    
    # Complete tolerations configuration for all ArgoCD components
    values = [
      yamlencode({
        # Global tolerations that apply to all components
        global = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        
        # Controller tolerations
        controller = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        
        # Server tolerations
        server = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        
        # Repo server tolerations
        repoServer = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        
        # ApplicationSet controller tolerations
        applicationSet = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        
        # Redis tolerations
        redis = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        
        # Dex server tolerations
        dex = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        
        # Notifications controller tolerations
        notifications = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
      })
    ]
  }
}


resource "null_resource" "clean_up_argocd_resources" {
  count = try(var.cluster_config.capabilities.gitops, true) ? 1 : 0
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

