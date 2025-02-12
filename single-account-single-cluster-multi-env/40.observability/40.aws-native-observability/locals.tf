locals {
  region = data.aws_region.current.id
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
  
  tags = merge(
    var.tags,
    {
      "Environment" : terraform.workspace
      "provisioned-by" : "aws-solutions-library-samples/guidance-for-automated-provisioning-of-application-ready-amazon-eks-clusters"
    }
  )
}
