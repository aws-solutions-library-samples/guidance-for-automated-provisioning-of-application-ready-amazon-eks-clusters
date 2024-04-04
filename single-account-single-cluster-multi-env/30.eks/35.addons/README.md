# Observing Amazon EKS Cluster with AWS services for OSS tooling

This part of this pattern deploys and configure the relevant Kubernetes addons. It uses the [Amazon EKS Blueprints addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/) to deploy relevant addons. A subset of the addons deployed in this folder are :

* [Cert-Manager](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/cert-manager/)
* [External Secret](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/external-secrets/)
* [AWS for FluentBit](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-for-fluentbit/)
* [ArgoCD](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/argocd/) for GitOps tooling
* and more... 

## Prerequisites  
helm

To install Helm, the package manager for Kubernetes, first, download the Helm binary for your operating system from the Helm Releases page. For Linux and macOS, use curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3; chmod 700 get_helm.sh; ./get_helm.sh in the terminal. Windows users should download the .zip file, extract it, and move helm.exe to a directory on their PATH. Verify the installation with helm version. Next, add the stable repository with helm repo add stable https://charts.helm.sh/stable and update your repositories using helm repo update. This process installs Helm and prepares it for managing Kubernetes applications by updating the local list of charts to match the latest versions in your repositories. For additional details and configurations, refer to the Helm documentation.
None

## Using the services deployed in this part


## Architecture Decisions  

### All relevant addons should be configured based on the use-case and not based on flags

#### Context

One of the purpose of this project is to provide a cluster ready to deploy applications into it. Therefore, instead of enabling/disabling addons based on flags, we will enable the relevant addons based on a use-case.

#### Decision

For every use-case/configuration that this project will collect as it grows, we will enable a group of addons for a specific use-case or purpose. For example, instead of allowing users to enable observability addons, one by one, we will group them together under a variable called `observability_configuration.aws_oss_tooling` and this will automatically configure all the addons and the relevant AWS Services to enable observability in the cluster.

#### Consequences

Grouping addons deployment based on requirements, simplify the deployment process. We'll might have to enable deploying addons one-by-one as an "escape hatch", but we will do it based on feedback collected along the way.


## Deploy it

To deploy this folder resources to a specific resources, use the following commands

```
terraform init --backend-config=../../00.global/global-backend-config
terraform workspace new <YOUR_ENV>
terraform workspace select <YOUR_ENV>
terraform apply -var-file="../../00.global/vars/dev.tfvars"
```


## Troubleshooting


## Terraform docs
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.40.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.7 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.3 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.22.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.40.0 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks_blueprints_addons"></a> [eks\_blueprints\_addons](#module\_eks\_blueprints\_addons) | aws-ia/eks-blueprints-addons/aws | ~> 1.16.1 |

## Resources

| Name | Type |
|------|------|
| [null_resource.clean_up_argocd_resources](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [terraform_remote_state.eks](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_observability_configuration"></a> [observability\_configuration](#input\_observability\_configuration) | observability configuration variable | <pre>object({<br>    aws_oss_tooling        = optional(bool, true)  // AMP & AMG<br>    aws_native_tooling     = optional(bool, false) // CW<br>    aws_oss_tooling_config = optional(map(any), {})<br>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_argocd"></a> [access\_argocd](#output\_access\_argocd) | ArgoCD Access |
| <a name="output_configure_argocd"></a> [configure\_argocd](#output\_configure\_argocd) | Terminal Setup |
| <a name="output_external_secrets_addon_output"></a> [external\_secrets\_addon\_output](#output\_external\_secrets\_addon\_output) | external-secrets addon output values |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->