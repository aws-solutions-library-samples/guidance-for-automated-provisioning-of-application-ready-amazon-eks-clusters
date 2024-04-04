resource "aws_prometheus_workspace" "this" {
  alias = local.name
}
