
data "terraform_remote_state" "vpc" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "networking/vpc/terraform.tfstate"
    region = local.tfstate_region
  }
}

data "terraform_remote_state" "iam" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "iam/roles/terraform.tfstate"
    region = local.tfstate_region
  }
}

