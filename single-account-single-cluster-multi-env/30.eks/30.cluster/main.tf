

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
  version = "20.8.3"

  cluster_name                   = local.cluster_name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = try(!var.cluster_config.private_eks_cluster, false)

  vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  control_plane_subnet_ids = data.terraform_remote_state.vpc.outputs.intra_subnet_ids

  # Combine root account, current user/role and additinoal roles to be able to access the cluster KMS key - required for terraform updates
  kms_key_administrators = distinct(concat([
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
    var.kms_key_admin_roles,
    [data.aws_iam_session_context.current.issuer_arn]
  ))

  enable_cluster_creator_admin_permissions = "true"
  authentication_mode                      = "API_AND_CONFIG_MAP"

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
    instance_types = ["m6i.large", "m5.large"]
    iam_role_additional_policies = {
      SSM = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  eks_managed_node_groups = {
    "${local.cluster_name}-criticaladdons" = {
#      use_name_prefix = true

      subnet_ids   = data.terraform_remote_state.vpc.outputs.private_subnet_ids
      max_size     = 5
      desired_size = 2
      min_size     = 2

      # Launch template configuration
      # create_launch_template = true              # false will use the default launch template
      # launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

#      labels = {
#        "node.kubernetes.io/component" = "management-nodes"
#      }
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
  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks_blueprints_addons.karpenter.node_iam_role_arn

  # From https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateAccessEntry.html :
  # If you set the value to EC2_LINUX or EC2_WINDOWS, you can't specify values for kubernetesGroups, or associate an AccessPolicy to the access entry.
  type = "EC2_LINUX"
}


################################################################################
# EKS Blueprints Addons - common/base addons for every cluster
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.15.1"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # We want to wait for the Fargate profiles to be deployed first
  create_delay_dependencies = [for prof in module.eks.fargate_profiles : prof.fargate_profile_arn]

  eks_addons = {
    # coredns = {
    #   //TODO - add local DNS CACHE 
    # }
    vpc-cni = {
      # Specify the VPC CNI addon should be deployed before compute to ensure
      # the addon is configured before data plane compute resources are created
      before_compute = true
      most_recent    = true # To ensure access to the latest settings provided
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        },
        # tolerations = [
        #   {
        #     key      = "node.kubernetes.io/component"
        #     operator = "Equal"
        #     value    = "management-nodes"
        #     effect   = "NO_SCHEDULE"
        #   }
        # ]
      })
    }
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
      preserve                    = true
      most_recent                 = true
      configuration_values = jsonencode(
        {
          replicaCount : 2,
#          nodeSelector : {
#            "node.kubernetes.io/component" : "management-nodes"
#          },
          tolerations : [local.critical_addons_tolerations.tolerations[0]]
        }
      )

    }
    kube-proxy = {
      most_recent = true
    }
  }

  # by default, Karpenter helm chart is set to not schedule Karpenter pods, on nodes it creates,
  #  so no additional nodeSelector is needed here to ensure it'll run on the above node-groups
  enable_karpenter = true
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    values = [yamlencode(local.critical_addons_tolerations)]
  }
  karpenter_node = {
    # Use static name so that it matches what is defined in `karpenter.yaml` example manifest
    iam_role_use_name_prefix = false
  }

  tags = local.tags

  depends_on = [module.eks]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${module.eks_blueprints_addons.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}
      tags:
        karpenter.sh/discovery: ${local.cluster_name}
        Environment: ${terraform.workspace}
        provisioned-by: "aws-samples/terraform-workloads-ready-eks-accelerator"
  YAML

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        metadata:
          labels:
            intent: apps
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r", "t"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["4", "8", "16", "32", "64", "96", "128"]
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}
