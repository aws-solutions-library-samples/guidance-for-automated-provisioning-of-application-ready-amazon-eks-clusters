locals {
  region         = data.aws_region.current.id
  tfstate_region = try(var.tfstate_region, local.region)
  critical_addons_tolerations = {
    tolerations = [
      {
        key      = "CriticalAddonsOnly",
        operator = "Exists",
        effect   = "NoSchedule"
      }
    ]
  }

  tags = merge(
    var.tags,
    {
      "Environment" : terraform.workspace
      "provisioned-by" : "aws-samples/terraform-workloads-ready-eks-accelerator"
    }
  )
}
