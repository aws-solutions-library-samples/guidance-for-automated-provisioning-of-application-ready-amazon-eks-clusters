
data "aws_availability_zones" "available" {
  # exclude zones where EKS control plane can't reside in: https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#network-requirements-subnets
  exclude_zone_ids = ["use1-az3", "usw1-az2", "cac1-az3"]
}

locals {
  name                  = "${var.shared_config.resources_prefix}-${terraform.workspace}"
  azs                   = slice(data.aws_availability_zones.available.names, 0, var.num_azs)
  private_subnets       = [for k, v in module.subnets.network_cidr_blocks : v if endswith(k, "/private")]
  public_subnets        = [for k, v in module.subnets.network_cidr_blocks : v if endswith(k, "/public")]
  control_plane_subnets = [for k, v in module.subnets.network_cidr_blocks : v if endswith(k, "/controlplane")]

  vpc_cidr_prefix = tonumber(split("/", var.vpc_cidr)[1])

  tags = merge(
    var.tags,
    {
      "Name" : local.name,
      "Environment" : terraform.workspace
      "provisioned-by" : "aws-samples/terraform-workloads-ready-eks-accelerator"
    }
  )
}

module "subnets" {
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"

  base_cidr_block = var.vpc_cidr
  networks = concat(
    [for k, v in local.azs : tomap({ "name" = "${v}/private", "new_bits" = var.private_subnets_cidr_prefix - local.vpc_cidr_prefix })],
    [for k, v in local.azs : tomap({ "name" = "${v}/public", "new_bits" = var.public_subnets_cidr_prefix - local.vpc_cidr_prefix })],
    [for k, v in local.azs : tomap({ "name" = "${v}/controlplane", "new_bits" = var.control_plane_subnets_cidr_prefix - local.vpc_cidr_prefix })]
  )
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.2"

  name = local.name
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.control_plane_subnets

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = local.name
  }

  enable_nat_gateway = true
}

module "endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.5.3"
  count   = var.cluster_config.private_eks_cluster ? 1 : 0

  vpc_id                     = module.vpc.vpc_id
  create_security_group      = true
  security_group_name        = "${local.name}-vpc-endpoints"
  security_group_description = "VPC Endpoint Security Group - ${local.name}"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC - ${local.name}"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }
  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    },
    aps = {
      service             = "aps"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      # policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    aps-workspaces = {
      service             = "aps-workspaces"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      # policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    grafana = {
      service             = "grafana"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      # policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    grafana-workspace = {
      service             = "grafana-workspace"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      # policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    eks-auth = {
      service             = "eks-auth"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      # policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    eks = {
      service             = "eks"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      # policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      # policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      # policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      # policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    autoscaling = {
      service             = "autoscaling"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ebs = {
      service             = "ebs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    kms = {
      service             = "kms"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ssmmessages = {
      service             = "ssmmessages"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ec2messages = {
      service             = "ec2messages"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
  }
}

#--------------------------------------------------------------
# Adding guidance solution ID via AWS CloudFormation resource
#--------------------------------------------------------------
resource "random_bytes" "this" {
  length = 2
}
resource "aws_cloudformation_stack" "guidance_deployment_metrics" {
  name          = "tracking-stack-${random_bytes.this.hex}"
  on_failure    = "DO_NOTHING"
  template_body = <<STACK
    {
        "AWSTemplateFormatVersion": "2010-09-09",
        "Description": "This is Guidance for Automated Provisioning of Application-Ready Amazon EKS Clusters (SO9530)",
        "Resources": {
            "EmptyResource": {
                "Type": "AWS::CloudFormation::WaitConditionHandle"
            }
        }
    }
    STACK
}
