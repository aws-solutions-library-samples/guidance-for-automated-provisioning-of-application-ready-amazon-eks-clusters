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


################################################################################
# EKS Cluster
################################################################################
#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31.3"

  cluster_name                   = local.cluster_name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = try(!var.cluster_config.private_eks_cluster, false)

  create_iam_role          = try(var.cluster_config.create_iam_role, true)
  iam_role_arn             = try(var.cluster_config.cluster_iam_role_arn, null)
  iam_role_use_name_prefix = false

  node_iam_role_use_name_prefix = false

  cluster_enabled_log_types = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

  vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids               = local.private_subnet_ids
  control_plane_subnet_ids = local.control_plane_subnet_ids

  # Combine root account, current user/role and additinoal roles to be able to access the cluster KMS key - required for terraform updates
  kms_key_administrators = distinct(concat([
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
    var.kms_key_admin_roles,
    [data.aws_iam_session_context.current.issuer_arn]
  ))

  enable_cluster_creator_admin_permissions = "true"
  authentication_mode                      = try(var.cluster_config.authentication_mode, "API")

  bootstrap_self_managed_addons = "false"

  cluster_compute_config = local.eks_auto_mode ? { enabled = local.eks_auto_mode } : {}

  # We're using EKS module to only provision EKS managed addons
  # The reason for that is to use the `before_compute` parameter which allows for the addon to be deployed before a compute is available for it to run
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
    local.capabilities.kube_proxy ? {
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
      create                   = local.create_mng_system
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
# EKS Auto Mode Node role access entry
################################################################################
resource "aws_eks_access_entry" "automode_node" {
  count         = local.eks_auto_mode ? 1 : 0
  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks.node_iam_role_arn
  type          = "EC2"
}

resource "aws_eks_access_policy_association" "automode_node" {
  count        = local.eks_auto_mode ? 1 : 0
  cluster_name = module.eks.cluster_name
  access_scope {
    type = "cluster"
  }
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
  principal_arn = module.eks.node_iam_role_arn
}

################################################################################
# EKS Auto Mode default NodePools & NodeClass
################################################################################
data "kubectl_path_documents" "automode_manifests" {
  count   = local.eks_auto_mode ? 1 : 0
  pattern = "${path.module}/auto-mode/*.yaml"
  vars = {
    role                      = module.eks.node_iam_role_name
    cluster_name              = local.cluster_name
    cluster_security_group_id = module.eks.cluster_primary_security_group_id
    environment               = terraform.workspace
  }
  depends_on = [
    module.eks
  ]
}

# workaround terraform issue with attributes that cannot be determined ahead because of module dependencies
# https://github.com/gavinbunney/terraform-provider-kubectl/issues/58
data "kubectl_path_documents" "automode_manifests_dummy" {
  count   = local.eks_auto_mode ? 1 : 0
  pattern = "${path.module}/auto-mode/*.yaml"
  vars = {
    role                      = ""
    cluster_name              = ""
    cluster_security_group_id = ""
    environment               = terraform.workspace
  }
}

resource "kubectl_manifest" "automode_manifests" {
  count     = local.eks_auto_mode ? length(data.kubectl_path_documents.automode_manifests_dummy[0].documents) : 0
  yaml_body = element(data.kubectl_path_documents.automode_manifests[0].documents, count.index)
}

################################################################################
# Storage Classes
################################################################################
resource "kubernetes_annotations" "gp2" {
  count       = local.capabilities.blockstorage || local.eks_auto_mode ? 1 : 0
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

################################################################################
# EKS Auto Mode Storage Class
################################################################################
resource "kubernetes_storage_class_v1" "automode" {
  count = local.eks_auto_mode ? 1 : 0
  metadata {
    name = "auto-ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.eks.amazonaws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    encrypted = true
    type      = "gp3"
  }
  depends_on = [
    module.eks
  ]
}

################################################################################
# EKS Auto Mode Ingress
################################################################################
resource "kubectl_manifest" "automode_ingressclass_params" {
  count     = local.eks_auto_mode ? 1 : 0
  yaml_body = <<YAML
apiVersion: eks.amazonaws.com/v1
kind: IngressClassParams
metadata:
  name: auto-alb
spec:
  scheme: internet-facing
YAML
  depends_on = [
    module.eks
  ]
}

resource "kubernetes_ingress_class_v1" "automode" {
  count = local.eks_auto_mode ? 1 : 0
  metadata {
    name = "auto-alb"
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }
  spec {
    controller = "eks.amazonaws.com/alb"
    parameters {
      api_group = "eks.amazonaws.com"
      kind      = "IngressClassParams"
      name      = "auto-alb"
    }
  }
  depends_on = [
    kubectl_manifest.automode_ingressclass_params
  ]
}
