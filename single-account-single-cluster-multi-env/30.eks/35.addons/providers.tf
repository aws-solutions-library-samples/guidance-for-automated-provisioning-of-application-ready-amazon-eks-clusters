terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.74.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.22.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.1.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
  }

}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name, "--region", local.region]

    }
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name, "--region", local.region]
  }
}

provider "aws" {
  default_tags {
    tags = local.tags
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name, "--region", local.region]

  }
}
