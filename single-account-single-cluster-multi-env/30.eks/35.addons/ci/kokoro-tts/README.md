# Kokoro TTS CI Module

This Terraform module sets up AWS CodeBuild to automatically build and deploy the Kokoro TTS Docker image to Amazon ECR.

## Overview

The module creates the following resources:

1. **Amazon ECR Repository**: Stores the Kokoro TTS Docker image
2. **AWS CodeBuild Project**: Builds the Docker image from the GitHub repository
3. **S3 Bucket**: Stores build artifacts
4. **IAM Role and Policy**: Provides necessary permissions for CodeBuild
5. **GitHub Webhook**: Triggers builds automatically on code changes

## Usage

```hcl
module "kokoro_tts_ci" {
  source = "./ci/kokoro-tts"

  github_repo_url = "https://github.com/omototo/kubecon.git"
  region          = "us-west-2"
  environment     = "dev"

  tags = {
    Environment = "dev"
    Project     = "KokoroTTS"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| github_repo_url | URL of the GitHub repository containing the Kokoro TTS code | `string` | `"https://github.com/omototo/kubecon.git"` | no |
| region | AWS region | `string` | `"us-west-2"` | no |
| environment | Environment name (e.g., dev, staging, prod) | `string` | `"dev"` | no |
| tags | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| ecr_repository_url | The URL of the ECR repository |
| ecr_repository_name | The name of the ECR repository |
| codebuild_project_name | The name of the CodeBuild project |
| codebuild_project_arn | The ARN of the CodeBuild project |
| artifacts_bucket_name | The name of the S3 bucket for build artifacts |
| artifacts_bucket_arn | The ARN of the S3 bucket for build artifacts |

## GitHub Repository Structure

The module expects the following structure in the GitHub repository:

```
.github/
  buildspec.yml         # CodeBuild buildspec file
examples/
  deepseek-kokoro/      # Kokoro TTS application directory
    Dockerfile.kokoro-tts  # Docker file for Kokoro TTS
    app.py              # Application code
    requirements.txt    # Python dependencies
    app_manifest.yaml   # ArgoCD application manifest
    kokoro-tts.yaml     # Kubernetes deployment manifest
    values.yaml         # Configuration values
```

## Deployment Process

1. When code is pushed to the main branch, the GitHub webhook triggers a CodeBuild job
2. CodeBuild clones the repository and builds the Docker image
3. The image is pushed to the ECR repository
4. The image can then be deployed to the Kubernetes cluster using ArgoCD 