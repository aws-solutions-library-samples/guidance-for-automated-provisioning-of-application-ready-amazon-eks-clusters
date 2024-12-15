locals {
  tags = merge(
    var.tags,
    {
      "Environment" : terraform.workspace
      "provisioned-by" : "aws-solutions-library-samples/guidance-for-automated-provisioning-of-application-ready-amazon-eks-clusters"
    }

  )
  name = "${var.shared_config.resources_prefix}-${terraform.workspace}"
  # The below IAM roles represent the default Kubernetes user-facing roles as documented in https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles
  #  and as supported by Amazon EKS Cluster Access Management 
  iam_roles = {
    # cluster admin resources with wildcard permissions to any cluster resources 
    EKSClusterAdmin = {
      role_name         = "EKSClusterAdmin"
      attached_policies = []
    },
    EKSAdmin = {
      role_name         = "EKSAdmin"
      attached_policies = []
    },
    EKSEdit = {
      role_name         = "EKSEdit"
      attached_policies = []
    },
    EKSView = {
      role_name         = "EKSView"
      attached_policies = []
    },
  }
}
