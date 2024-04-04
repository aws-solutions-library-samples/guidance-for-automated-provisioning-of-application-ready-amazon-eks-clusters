locals {

  name = "${var.shared_config.resources_prefix}-${terraform.workspace}"

  region = data.aws_region.current.name

  eks_cluster_endpoint = data.aws_eks_cluster.this.endpoint
  eks_cluster_name     = data.terraform_remote_state.eks.outputs.cluster_name

  grafana_workspace_name                   = local.name
  grafana_workspace_description            = join("", ["Amazon Managed Grafana workspace for ${local.grafana_workspace_name}"])
  grafana_workspace_api_expiration_days    = 30
  grafana_workspace_api_expiration_seconds = 60 * 60 * 24 * local.grafana_workspace_api_expiration_days

  critical_addons_tolerations = {
    tolerations = [
      {
        key      = "CriticalAddonsOnly",
        operator = "Exists",
        effect   = "NoSchedule"
      }
    ]
  }

  tags = merge(
    var.tags,
    {
      "Environment" : terraform.workspace
      "provisioned-by" : "aws-samples/terraform-workloads-ready-eks-accelerator"
    }
  )
}
