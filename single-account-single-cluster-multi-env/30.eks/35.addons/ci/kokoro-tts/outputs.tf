output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.kokoro_tts.repository_url
}

output "ecr_repository_name" {
  description = "The name of the ECR repository"
  value       = aws_ecr_repository.kokoro_tts.name
}

output "codebuild_project_name" {
  description = "The name of the CodeBuild project"
  value       = aws_codebuild_project.kokoro_tts.name
}

output "codebuild_project_arn" {
  description = "The ARN of the CodeBuild project"
  value       = aws_codebuild_project.kokoro_tts.arn
}

output "artifacts_bucket_name" {
  description = "The name of the S3 bucket for build artifacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "The ARN of the S3 bucket for build artifacts"
  value       = aws_s3_bucket.artifacts.arn
}

output "webhook_url" {
  description = "The payload URL of the CodeBuild webhook"
  value       = var.create_webhook ? aws_codebuild_webhook.kokoro_tts[0].payload_url : "Webhook not created"
  sensitive   = true
} 