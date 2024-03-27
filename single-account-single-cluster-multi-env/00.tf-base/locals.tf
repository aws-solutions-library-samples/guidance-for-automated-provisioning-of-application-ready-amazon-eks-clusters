locals {
  tags = merge(
    var.tags,
    {
      "Environment" : terraform.workspace
    }
  )
}
