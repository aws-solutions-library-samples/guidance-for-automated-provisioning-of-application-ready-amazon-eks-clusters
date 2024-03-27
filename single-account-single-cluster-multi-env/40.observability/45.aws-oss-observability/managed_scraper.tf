# The configurations in this file are for AMP Managed Collector (https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-collector-how-to.html)
#  and will be enabled only if var.observability_configuration.aws_oss_tooling_config.enable_managed_collector is set to true

### managed collector

# per docs on https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-collector-how-to.html#AMP-collector-create
resource "kubectl_manifest" "amp_scraper_clusterrole" {
  count     = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_managed_collector ? 1 : 0
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aps-collector-role
rules:
  - apiGroups: [""]
    resources: ["nodes", "nodes/proxy", "nodes/metrics", "services", "endpoints", "pods", "ingresses", "configmaps"]
    verbs: ["describe", "get", "list", "watch"]
  - apiGroups: ["extensions", "networking.k8s.io"]
    resources: ["ingresses/status", "ingresses"]
    verbs: ["describe", "get", "list", "watch"]
  - nonResourceURLs: ["/metrics"]
    verbs: ["get"]
YAML
}

resource "kubectl_manifest" "amp_scraper_clusterrolebinding" {
  count     = var.observability_configuration.aws_oss_tooling_config.enable_managed_collector ? 1 : 0
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: aps-collector-user-role-binding
subjects:
- kind: User
  name: aps-collector-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: aps-collector-role
  apiGroup: rbac.authorization.k8s.io
YAML
}

resource "aws_prometheus_scraper" "amp_scraper" {
  count = var.observability_configuration.aws_oss_tooling_config.enable_managed_collector ? 1 : 0
  source {
    eks {
      cluster_arn = data.aws_eks_cluster.this.arn
      subnet_ids  = data.terraform_remote_state.vpc.outputs.intra_subnet_ids
    }
  }

  destination {
    amp {
      workspace_arn = aws_prometheus_workspace.this.arn
    }
  }

  scrape_configuration = templatefile(
    "${path.module}/aws_prometheus_scraper_configuration",
    {
      CLUSTER_ARN  = data.aws_eks_cluster.this.arn
      CLUSTER_NAME = data.aws_eks_cluster.this.id
    }
  )
}

locals {
  amp_scrpaer_arn_trimmed = replace(aws_prometheus_scraper.amp_scraper[0].role_arn, "aws-service-role/scraper.aps.amazonaws.com/", "")
}

resource "null_resource" "clean_up_argocd_resources" {
  depends_on = [aws_prometheus_scraper.amp_scraper]
  triggers = {
    always_run   = timestamp()
    region       = local.region
    scraper_arn  = local.amp_scrpaer_arn_trimmed
    cluster_name = local.eks_cluster_name
  }
  provisioner "local-exec" {

    command = "eksctl create iamidentitymapping --cluster ${self.triggers.cluster_name} --region ${self.triggers.region} --arn ${self.triggers.scraper_arn} --username aps-collector-user"

    interpreter = ["bash", "-c"]
    # when        = destroy
  }
}

output "eksctl_create_amp_scraper_identitymapping_command" {
  value = "eksctl create iamidentitymapping --cluster ${local.eks_cluster_name} --region ${local.region} --arn ${local.amp_scrpaer_arn_trimmed} --username aps-collector-user"
}
