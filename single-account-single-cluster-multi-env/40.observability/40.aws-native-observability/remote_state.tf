data "terraform_remote_state" "eks" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "${var.shared_config.resources_prefix}-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "eks/terraform.tfstate"
    region = local.region
  }
}
