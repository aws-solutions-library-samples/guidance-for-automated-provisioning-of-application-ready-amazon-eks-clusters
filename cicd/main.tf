terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {

}

# GitHub Connection for CodePipeline
resource "aws_codestarconnections_connection" "github" {
  name          = "GitHub-Connection"
  provider_type = "GitHub"
}

# CodeBuild Project
resource "aws_codebuild_project" "terraform_build" {
  name          = "${var.project_name}-build"
  build_timeout = 25 # in minutes
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    privileged_mode             = true
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "AWS_REGION"
      value = "eu-central-1"
    }
    environment_variable {
      name  = "AWS_PROFILE"
      value = "default"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/aws-samples/terraform-workloads-ready-eks-accelerator.git"
    git_clone_depth = 1
    buildspec       = file("../${path.module}/buildspec.yml")
  }



  source_version = "refs/heads/cicd" # Default branch to use from GitHub
  # Reference to a local buildspec file

}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codebuild.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# CodePipeline for triggering builds
resource "aws_codepipeline" "terraform_pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "aws-samples/terraform-workloads-ready-eks-accelerator"
        BranchName       = "cicd"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
      }
    }
  }
}

# S3 bucket for artifact storage
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts"
}




# IAM Policy for DynamoDB Access
resource "aws_iam_policy" "codebuild_full_access" {
  name = "${var.project_name}-codebuild-full-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "*"
        ],
        Resource = [
          "*"
        ]
      }
    ]
  })
}

# Attach S3 and DynamoDB access policies to the CodeBuild role
resource "aws_iam_policy_attachment" "codebuild_s3_attachment" {
  name       = "${var.project_name}-codebuild-s3-policy-attachment"
  roles      = [aws_iam_role.codebuild_role.name]
  policy_arn = aws_iam_policy.codebuild_full_access.arn
}
