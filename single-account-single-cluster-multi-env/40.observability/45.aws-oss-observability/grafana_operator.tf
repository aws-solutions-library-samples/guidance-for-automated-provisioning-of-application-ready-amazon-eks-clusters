resource "helm_release" "grafana_operator" {
  count            = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  chart            = var.go_config.helm_chart
  name             = var.go_config.helm_name
  namespace        = var.go_config.k8s_namespace
  version          = var.go_config.helm_chart_version
  create_namespace = var.go_config.create_namespace
  max_history      = 3
}

locals {
  cluster_secretstore_name = "aws-parameter-store"
  cluster_secretstore_sa   = "external-secrets-sa" // this is currently const - need to dynamically get it from the cluster
  esop_secret_name         = "external-secrets"
  target_secret_name       = "grafana-admin-credentials"
}

#---------------------------------------------------------------
# External Secrets Operator - Secret
#---------------------------------------------------------------
locals {

  grafana_workspace_api_expiration_days    = 30
  grafana_workspace_api_expiration_seconds = 60 * 60 * 24 * local.grafana_workspace_api_expiration_days
}

resource "aws_kms_key" "secrets" {
  count               = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  enable_key_rotation = true
}

# handle grafana api key expiration
# https://github.com/hashicorp/terraform-provider-aws/issues/27043#issuecomment-1614947274
resource "time_rotating" "this" {
  count         = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  rotation_days = local.grafana_workspace_api_expiration_days
}

resource "time_static" "this" {
  count   = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  rfc3339 = time_rotating.this[count.index].rfc3339
}

resource "aws_grafana_workspace_api_key" "this" {
  count           = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  key_name        = "eks-monitoring-grafana-admin-key"
  key_role        = "ADMIN"
  seconds_to_live = local.grafana_workspace_api_expiration_seconds // TODO: mechanism to rotate expired key
  workspace_id    = module.managed_grafana[count.index].workspace_id

  lifecycle {
    replace_triggered_by = [
      time_static.this
    ]
  }
}

resource "aws_ssm_parameter" "secret" {
  count       = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  name        = "/eks-accelerator/${terraform.workspace}/grafana-api-key"
  description = "SSM Secret to store grafana API Key"
  type        = "SecureString"
  value = jsonencode({
    GF_SECURITY_ADMIN_APIKEY = tostring(aws_grafana_workspace_api_key.this[count.index].key)
    key_id                   = aws_kms_key.secrets[count.index].id
  })
}


#---------------------------------------------------------------
# External Secrets Operator - Cluster Secret Store
#---------------------------------------------------------------
resource "kubectl_manifest" "cluster_secretstore" {
  count     = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  yaml_body = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: ${local.cluster_secretstore_name}
spec:
  provider:
    aws:
      service: ParameterStore
      region: ${data.aws_region.current.name}
      auth:
        jwt:
          serviceAccountRef:
            name: ${local.cluster_secretstore_sa}
            namespace: ${data.terraform_remote_state.eks_addons.outputs.external_secrets_addon_output.namespace}
YAML
  # depends_on = [module.external_secrets]
}

resource "kubectl_manifest" "secret" {
  depends_on = [helm_release.grafana_operator]
  count      = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  yaml_body  = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ${local.esop_secret_name}-sm
  namespace: ${var.go_config.k8s_namespace}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: ${local.cluster_secretstore_name}
    kind: ClusterSecretStore
  target:
    name: ${local.target_secret_name}
  dataFrom:
  - extract:
      key: ${aws_ssm_parameter.secret[count.index].name}
YAML
  # depends_on = [module.external_secrets]
  lifecycle {
    replace_triggered_by = [
      aws_ssm_parameter.secret[count.index].version
    ]
  }
}


resource "kubectl_manifest" "amg_remote_identity" {
  depends_on = [module.managed_grafana, helm_release.grafana_operator]
  count      = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  yaml_body = templatefile("${path.module}/grafana-operator-manifests/infrastructure/amg-grafana.yaml",
    {


      AMG_ENDPOINT_URL = "https://${module.managed_grafana[count.index].workspace_endpoint}",
      AMG_ID           = module.managed_grafana[count.index].workspace_id,
  })
}

resource "kubectl_manifest" "amp_data_source" {
  depends_on = [module.managed_grafana, helm_release.grafana_operator]
  count      = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? 1 : 0
  yaml_body = templatefile("${path.module}/grafana-operator-manifests/infrastructure/amp-datasource.yaml",
    {
      AMP_ENDPOINT_URL = aws_prometheus_workspace.this.prometheus_endpoint,
      AMG_AWS_REGION   = local.region
      ENVIRONMENT      = terraform.workspace
    }
  )
}

# default dashboards
data "kubectl_path_documents" "default_dashboards_manifest" {
  pattern = "${path.module}/grafana-operator-manifests/infrastructure/dashboards.yaml"
}

resource "kubectl_manifest" "default_dashboards" {
  depends_on = [module.managed_grafana, helm_release.grafana_operator]
  count      = var.observability_configuration.aws_oss_tooling && var.observability_configuration.aws_oss_tooling_config.enable_grafana_operator ? length(data.kubectl_path_documents.default_dashboards_manifest.documents) : 0
  yaml_body  = element(data.kubectl_path_documents.default_dashboards_manifest.documents, count.index)
}
