resource "aws_prometheus_workspace" "this" {
  count = var.observability_configuration.aws_oss_tooling ? 1 : 0
  alias = local.name
}
