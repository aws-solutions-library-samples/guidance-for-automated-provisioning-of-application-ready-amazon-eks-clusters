



data "aws_caller_identity" "current" {}



# Create IAM roles and attach policies
resource "aws_iam_role" "iam_roles" {
  for_each = local.iam_roles

  name = "${local.name}-${each.value.role_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          AWS : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", // TODO: consider specific trust policy for those users
        },
      },
    ],
  })
}

