resource "aws_ecr_repository" "kokoro_tts" {
  name                 = "kokoro-tts"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "kokoro-tts-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "kokoro-tts-codebuild-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_ownership_controls" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "artifacts" {
  depends_on = [aws_s3_bucket_ownership_controls.artifacts]
  bucket     = aws_s3_bucket.artifacts.id
  acl        = "private"
}

resource "aws_codebuild_project" "kokoro_tts" {
  name          = "kokoro-tts-build"
  description   = "Build project for Kokoro TTS Docker image"
  build_timeout = "30"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "S3"
    location = aws_s3_bucket.artifacts.bucket
    name = "kokoro-tts-build-artifacts"
    packaging = "ZIP"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = ".github/buildspec.yml"

    git_submodules_config {
      fetch_submodules = true
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "kokoro-tts-build-log-group"
      stream_name = "kokoro-tts-build-log-stream"
    }
  }

  tags = var.tags
}

# Webhook for GitHub integration
resource "aws_codebuild_webhook" "kokoro_tts" {
  count = var.create_webhook ? 1 : 0
  
  project_name = aws_codebuild_project.kokoro_tts.name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "^refs/heads/main$"
    }
    filter {
      type    = "FILE_PATH"
      pattern = "examples/deepseek-kokoro/*"
    }
  }
}

data "aws_caller_identity" "current" {} 