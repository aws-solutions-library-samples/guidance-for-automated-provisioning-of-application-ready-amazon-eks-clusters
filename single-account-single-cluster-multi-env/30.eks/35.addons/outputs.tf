locals {
  argocd_terminal_setup = <<-EOT
    export KUBECONFIG="/tmp/${data.terraform_remote_state.eks.outputs.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${data.terraform_remote_state.eks.outputs.cluster_name}
    export ARGOCD_OPTS="--port-forward --port-forward-namespace argocd --grpc-web"
    kubectl config set-context --current --namespace argocd
    argocd login --port-forward --username admin --password $(argocd admin initial-password | head -1)
    echo "ArgoCD Username: admin"
    echo "ArgoCD Password: $(kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}")"
    echo Port Forward: http://localhost:8080
    kubectl port-forward -n argocd svc/argo-cd-argocd-server 8080:80
    EOT
  argocd_access         = <<-EOT
    export KUBECONFIG="/tmp/${data.terraform_remote_state.eks.outputs.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${data.terraform_remote_state.eks.outputs.cluster_name}
    echo "ArgoCD Username: admin"
    echo "ArgoCD Password: $(kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}")"
    echo "ArgoCD URL: https://$(kubectl get svc -n argocd argo-cd-argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    EOT
}

output "configure_argocd" {
  description = "ArgoCD Terminal Setup"
  value       = try(var.cluster_config.capabilities.gitops, true) ? local.argocd_terminal_setup : null
}

output "access_argocd" {
  description = "ArgoCD Access"
  value       = try(var.cluster_config.capabilities.gitops, true) ? local.argocd_access : null
}

output "external_secrets_addon_output" {
  description = "external-secrets addon output values"
  value       = try(var.observability_configuration.aws_oss_tooling, false) ? module.eks_blueprints_addons.external_secrets : null
}
