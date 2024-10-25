

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
# data "aws_availability_zones" "available" {}
data "aws_iam_session_context" "current" {
  # This data source provides information on the IAM source role of an STS assumed role
  # For non-role ARNs, this data source simply passes the ARN through issuer ARN
  # Ref https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2327#issuecomment-1355581682
  # Ref https://github.com/hashicorp/terraform-provider-aws/issues/28381
  arn = data.aws_caller_identity.current.arn
}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}


################################################################################
# EKS Cluster
################################################################################
#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name                   = local.cluster_name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = try(!var.cluster_config.private_eks_cluster, false)

  cluster_enabled_log_types = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

  vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  control_plane_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  # control_plane_subnet_ids = data.terraform_remote_state.vpc.outputs.intra_subnet_ids

  # Combine root account, current user/role and additinoal roles to be able to access the cluster KMS key - required for terraform updates
  kms_key_administrators = distinct(concat([
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
    var.kms_key_admin_roles,
    [data.aws_iam_session_context.current.issuer_arn]
  ))

  enable_cluster_creator_admin_permissions = "true"
  authentication_mode                      = "API_AND_CONFIG_MAP"

  bootstrap_self_managed_addons = "false"

  cluster_addons = merge(
    local.capabilities.networking ? {
      vpc-cni = {
        # Specify the VPC CNI addon should be deployed before compute to ensure
        # the addon is configured before data plane compute resources are created
        before_compute = true
        most_recent    = true # To ensure access to the latest settings provided
        preserve       = false
        configuration_values = jsonencode({
          env = {
            ENABLE_PREFIX_DELEGATION = "false"
            WARM_ENI_TARGET          = "0"
            MINIMUM_IP_TARGET        = "10"
            WARM_IP_TARGET           = "5"
          }
        })
      }
    } : {},
    local.capabilities.networking ? {
      kube-proxy = {
        before_compute = true
        most_recent    = true
        preserve       = false
      }
    } : {},
    local.capabilities.coredns ? {
      coredns = {
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "PRESERVE"
        preserve                    = false
        most_recent                 = true
        configuration_values = jsonencode(
          {
            replicaCount : 2,
            tolerations : [local.critical_addons_tolerations.tolerations[0]]
          }
        )
      }
    } : {},
    local.capabilities.identity ? {
      eks-pod-identity-agent = {
        most_recent = true
        preserve    = false
      }
    } : {},
    local.capabilities.blockstorage ? {
      aws-ebs-csi-driver = {
        service_account_role_arn = module.ebs_csi_driver_irsa[0].iam_role_arn
        preserve                 = false
      }
    } : {}
  )

  access_entries = {
    EKSClusterAdmin = {
      kubernetes_groups = []
      principal_arn     = data.terraform_remote_state.iam.outputs.iam_roles_map["EKSClusterAdmin"]

      policy_associations = {
        single = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    EKSAdmin = {
      kubernetes_groups = []
      principal_arn     = data.terraform_remote_state.iam.outputs.iam_roles_map["EKSAdmin"]

      policy_associations = {
        single = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    EKSEdit = {
      kubernetes_groups = []
      principal_arn     = data.terraform_remote_state.iam.outputs.iam_roles_map["EKSEdit"]
      policy_associations = {
        single = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            namespaces = ["default"]
            type       = "namespace"
          }
        }
      }
    }
    EKSView = {
      kubernetes_groups = []
      principal_arn     = data.terraform_remote_state.iam.outputs.iam_roles_map["EKSView"]

      policy_associations = {
        single = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = {
            namespaces = ["default"]
            type       = "namespace"
          }
        }
      }
    }

  }

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

  # managed node group for base EKS addons such as Karpenter 

  eks_managed_node_group_defaults = {
    instance_types = ["m6g.large"]
    ami_type       = "AL2_ARM_64"
    iam_role_additional_policies = {
      SSM = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  eks_managed_node_groups = {
    "${local.cluster_name}-criticaladdons" = {
      create                   = try(var.cluster_config.create_mng_system, true)
      iam_role_use_name_prefix = false
      subnet_ids               = data.terraform_remote_state.vpc.outputs.private_subnet_ids
      max_size                 = 8
      desired_size             = 2
      min_size                 = 2

      taints = {
        critical_addons = {
          key    = "CriticalAddonsOnly"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
  tags = local.tags
}


resource "null_resource" "update-kubeconfig" {
  depends_on = [module.eks]
  triggers = {
    always_run   = timestamp()
    region       = local.region
    cluster_name = module.eks.cluster_name
  }
  provisioner "local-exec" {

    command = "aws eks --region ${self.triggers.region} update-kubeconfig --name ${self.triggers.cluster_name}"

    interpreter = ["bash", "-c"]
    # when        = destroy
  }
  lifecycle {
    ignore_changes = [
      # Ignore changes so it won't be applied every run
      # This is simply to simplify the access for whoever test this solution
      id,
      triggers
    ]
  }
}

# Add the karpernter discovery tag only to the cluster primary security group
# by default if use the eks module tags, it will tag all resources with this tag, which is not needed.
resource "aws_ec2_tag" "cluster_primary_security_group" {
  resource_id = module.eks.cluster_primary_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}



################################################################################
# Cluster Access Management - permissions of Karpenter node Role
################################################################################
resource "aws_eks_access_entry" "karpenter_node" {
  count         = local.capabilities.autoscaling ? 1 : 0
  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks_blueprints_addons.karpenter.node_iam_role_arn

  # From https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateAccessEntry.html :
  # If you set the value to EC2_LINUX or EC2_WINDOWS, you can't specify values for kubernetesGroups, or associate an AccessPolicy to the access entry.
  type = "EC2_LINUX"
}


################################################################################
# EBS CSI Driver
################################################################################
module "ebs_csi_driver_irsa" {
  count   = local.capabilities.blockstorage ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.43"

  role_name = "${local.cluster_name}-ebs-csi"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  oidc_providers = {
    cluster = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}


################################################################################
# EKS Blueprints Addons - common/base addons for every cluster
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16.2"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # We want to wait for the Fargate profiles to be deployed first
  create_delay_dependencies = [for prof in module.eks.fargate_profiles : prof.fargate_profile_arn]

  # by default, Karpenter helm chart is set to not schedule Karpenter pods, on nodes it creates,
  #  so no additional nodeSelector is needed here to ensure it'll run on the above node-groups
  enable_karpenter = local.capabilities.autoscaling
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    namespace           = "kube-system"
    values              = [yamlencode(local.critical_addons_tolerations)]
  }
  karpenter_node = {
    # Use static name so that it matches what is defined in `karpenter.yaml` example manifest
    iam_role_use_name_prefix = false
  }

  tags = local.tags

  depends_on = [module.eks]
}

data "kubectl_path_documents" "karpenter_manifests" {
  count   = local.capabilities.autoscaling ? 1 : 0
  pattern = "${path.module}/karpenter/*.yaml"
  vars = {
    role         = module.eks_blueprints_addons.karpenter.node_iam_role_name
    cluster_name = local.cluster_name
    environment  = terraform.workspace
  }
}

resource "kubectl_manifest" "karpenter_manifests" {
  count      = local.capabilities.autoscaling ? length(data.kubectl_path_documents.karpenter_manifests[0].documents) : 0
  yaml_body  = element(data.kubectl_path_documents.karpenter_manifests[0].documents, count.index)
  depends_on = [module.eks_blueprints_addons]
}

################################################################################
# Storage Classes
################################################################################
resource "kubernetes_annotations" "gp2" {
  count       = local.capabilities.blockstorage ? 1 : 0
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = "true"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  depends_on = [
    module.eks
  ]
}

resource "kubernetes_storage_class_v1" "gp3" {
  count = local.capabilities.blockstorage ? 1 : 0
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true" # make gp3 the default storage class
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    encrypted = true
    fsType    = "ext4"
    type      = "gp3"
  }
  depends_on = [
    module.eks
  ]
}
