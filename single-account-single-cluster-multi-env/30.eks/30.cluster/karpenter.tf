data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

# Add the Karpenter discovery tag only to the cluster primary security group
# by default if using the eks module tags, it will tag all resources with this tag, which is not needed.
resource "aws_ec2_tag" "cluster_primary_security_group" {
  count       = local.capabilities.autoscaling ? 1 : 0
  resource_id = module.eks.cluster_primary_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

################################################################################
# Karpenter
################################################################################
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.31.3"

  create = local.capabilities.autoscaling

  cluster_name = module.eks.cluster_name

  enable_v1_permissions = true

  enable_pod_identity             = true
  create_pod_identity_association = true

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  iam_role_name            = "KarpenterController-${module.eks.cluster_name}"
  iam_role_use_name_prefix = false

  node_iam_role_name            = "KarpenterNode-${module.eks.cluster_name}"
  node_iam_role_use_name_prefix = false

  tags = local.tags

  depends_on = [
    module.eks
  ]
}

################################################################################
# Karpenter Helm chart deployment
################################################################################
resource "helm_release" "karpenter" {
  count = local.capabilities.autoscaling ? 1 : 0

  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.1.1"
  wait                = false

  values = [
    yamlencode({
      tolerations = local.critical_addons_tolerations.tolerations,
      dnsPolicy : "Default",
      settings = {
        clusterName : module.eks.cluster_name
        clusterEndpoint : module.eks.cluster_endpoint
        interruptionQueue : module.karpenter.queue_name
      }
    })
  ]

  depends_on = [
    module.karpenter
  ]
}
################################################################################
# Karpenter default NodePool & NodeClass
################################################################################
data "kubectl_path_documents" "karpenter_manifests" {
  count   = local.capabilities.autoscaling ? 1 : 0
  pattern = "${path.module}/karpenter/*.yaml"
  vars = {
    role         = module.karpenter.node_iam_role_name
    cluster_name = local.cluster_name
    environment  = terraform.workspace
  }
  depends_on = [
    helm_release.karpenter[0]
  ]
}

# workaround terraform issue with attributes that cannot be determined ahead because of module dependencies
# https://github.com/gavinbunney/terraform-provider-kubectl/issues/58
data "kubectl_path_documents" "karpenter_manifests_dummy" {
  count   = local.capabilities.autoscaling ? 1 : 0
  pattern = "${path.module}/karpenter/*.yaml"
  vars = {
    role         = ""
    cluster_name = ""
    environment  = terraform.workspace
  }
}

resource "kubectl_manifest" "karpenter_manifests" {
  count     = local.capabilities.autoscaling ? length(data.kubectl_path_documents.karpenter_manifests_dummy[0].documents) : 0
  yaml_body = element(data.kubectl_path_documents.karpenter_manifests[0].documents, count.index)
}
