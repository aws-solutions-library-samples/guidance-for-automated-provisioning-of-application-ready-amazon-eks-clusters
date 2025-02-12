data "terraform_remote_state" "vpc" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "${var.shared_config.resources_prefix}-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "networking/vpc/terraform.tfstate"
    region = local.region
  }
}

data "terraform_remote_state" "iam" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "${var.shared_config.resources_prefix}-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "iam/roles/terraform.tfstate"
    region = local.region
  }
}

