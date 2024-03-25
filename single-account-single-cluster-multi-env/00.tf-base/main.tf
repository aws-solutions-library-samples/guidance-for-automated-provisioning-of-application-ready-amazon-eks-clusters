# main.tf
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Create an S3 bucket for remote state
resource "aws_s3_bucket" "tfstate" {
  // convention - bucket name will the combination of the string "tfstate" and the aws account number
  bucket        = "tfstate-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "tfstate" {
  depends_on = [aws_s3_bucket_ownership_controls.tfstate]

  bucket = aws_s3_bucket.tfstate.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create a DynamoDB table for state locking
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

# Generate a random string for the S3 bucket prefix
resource "random_string" "random_suffix" {
  length  = 6
  special = false
}


# Because tf doesn't allow to use variables in the backend configuration, 
# we will export the bucket and region values to a partial configuration file in the root of this folder, 
# which will be used by all subsequent terraform folders/modules within this structure.
# Partial configuration https://developer.hashicorp.com/terraform/language/settings/backends/configuration
# issue  https://github.com/hashicorp/terraform/issues/13022
resource "local_file" "general_config" {
  content  = "bucket=\"${aws_s3_bucket.tfstate.id}\" \nregion=\"${data.aws_region.current.name}\""
  filename = "${path.module}/../00.global/global-backend-config"
}
