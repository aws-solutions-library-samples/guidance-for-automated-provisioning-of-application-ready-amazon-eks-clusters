locals {
  region         = data.aws_region.current.id
  tfstate_region = try(var.tfstate_region, local.region)

  tags = merge(
    var.tags,
    {
      "Environment" : terraform.workspace
      "provisioned-by" : "aws-solutions-library-samples/guidance-for-automated-provisioning-of-application-ready-amazon-eks-clusters"
    }
  )
}
