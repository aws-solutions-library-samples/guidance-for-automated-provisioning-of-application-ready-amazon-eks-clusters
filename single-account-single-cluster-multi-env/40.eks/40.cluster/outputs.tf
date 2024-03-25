output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${module.eks.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}
  EOT
}

output "cluster_name" {
  description = "The EKS Cluster version"
  value       = module.eks.cluster_name

}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "kubernetes_version" {
  description = "The EKS Cluster version"
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "The OIDC Provider ARN"
  value       = module.eks.oidc_provider_arn
}
