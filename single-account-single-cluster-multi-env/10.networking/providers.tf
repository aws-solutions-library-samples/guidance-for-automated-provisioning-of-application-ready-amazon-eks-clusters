terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.74.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = local.tags
  }
}
