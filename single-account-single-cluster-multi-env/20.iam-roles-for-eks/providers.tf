terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}
provider "aws" {
  default_tags {
    tags = local.tags
  }
}
