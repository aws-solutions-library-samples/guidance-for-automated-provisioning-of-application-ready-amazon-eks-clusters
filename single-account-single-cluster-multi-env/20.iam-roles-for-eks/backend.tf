# Configure remote state to use S3 and DynamoDB
terraform {
  backend "s3" {
    key            = "iam/roles/terraform.tfstate"
  }
}


