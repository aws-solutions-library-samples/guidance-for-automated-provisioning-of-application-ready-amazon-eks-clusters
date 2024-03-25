
# Output IAM roles map with names and ARNs
output "iam_roles_map" {
  value = {
    for role_name, role_config in aws_iam_role.iam_roles : role_name => role_config.arn
  }
}

output "iam_roles_aws_auth_list" {
  value = [
    for r in {
      for role_name, role_obj in local.iam_roles : role_name => {
        "rolearn"  = aws_iam_role.iam_roles[role_name].arn
        "username" = "system:node:{{${aws_iam_role.iam_roles[role_name].name}}}"
        "groups"   = ["system:masters"]
      }
    }
  : r]
}
