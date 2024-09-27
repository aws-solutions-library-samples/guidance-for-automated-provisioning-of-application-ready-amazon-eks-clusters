# ADOT is a specific addon for observability, and therefore is managed in this part of the repo structure (and not in the addons folder)
# Its dependencies however (such as cert-manager addon), are managed in the addons folder, as other capabilities might need it 


data "aws_eks_addon_version" "adot" {
  addon_name         = "adot"
  kubernetes_version = data.aws_eks_cluster.this.version
  most_recent        = true
}


resource "aws_eks_addon" "adot" {
  count = (
    var.observability_configuration.aws_oss_tooling
    && var.observability_configuration.aws_oss_tooling_config.enable_adot_collector
  ) ? 1 : 0

  cluster_name                = data.aws_eks_cluster.this.name
  addon_name                  = "adot"
  addon_version               = data.aws_eks_addon_version.adot.version
  resolve_conflicts_on_update = "OVERWRITE"
  resolve_conflicts_on_create = "OVERWRITE"
  preserve                    = true

  configuration_values = "{\"collector\": {}}"
}

