locals {
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
    }
  )
}
