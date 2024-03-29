# Data block to fetch the SSO admin instance. Once you enabled SSO admin from console, you need data block to fetch this in your code.
data "aws_ssoadmin_instances" "current" {}

module "managed_grafana" {
  count   = var.observability_configuration.aws_oss_tooling ? 1 : 0
  source  = "terraform-aws-modules/managed-service-grafana/aws"
  version = "2.1.1"

  name                      = local.grafana_workspace_name
  associate_license         = false
  description               = local.grafana_workspace_description
  account_access_type       = "CURRENT_ACCOUNT"
  authentication_providers  = ["AWS_SSO"]
  permission_type           = "SERVICE_MANAGED"
  data_sources              = ["CLOUDWATCH", "PROMETHEUS", "XRAY"]
  notification_destinations = ["SNS"]
  stack_set_name            = local.grafana_workspace_name

  configuration = jsonencode({
    unifiedAlerting = {
      enabled = true
    },
    plugins = {
      pluginAdminEnabled = false
    }
  })

  grafana_version = "9.4"

  # Workspace IAM role
  create_iam_role                = true
  iam_role_name                  = local.grafana_workspace_name
  use_iam_role_name_prefix       = true
  iam_role_description           = local.grafana_workspace_description
  iam_role_path                  = "/grafana/"
  iam_role_force_detach_policies = true
  iam_role_max_session_duration  = 7200
  iam_role_tags                  = local.tags

  # Role associations
  # Ref: https://github.com/aws/aws-sdk/issues/25
  # Ref: https://github.com/hashicorp/terraform-provider-aws/issues/18812
  # WARNING: https://github.com/hashicorp/terraform-provider-aws/issues/24166
  role_associations = {
    "ADMIN" = {
      "group_ids" = [aws_identitystore_group.group[count.index].group_id]
    }
  }

  tags = local.tags
}

# ############################## Users,Group,Group's Membership #########################################

resource "aws_identitystore_user" "user" {
  count             = var.observability_configuration.aws_oss_tooling ? 1 : 0
  identity_store_id = tolist(data.aws_ssoadmin_instances.current.identity_store_ids)[0]

  display_name = "Grafana Admin"
  user_name    = "grafana-admin"


  name {
    family_name = "Admin"
    given_name  = "Grafana"
  }

  emails {
    value = var.grafana_admin_email
  }
}

resource "aws_identitystore_group" "group" {
  count             = var.observability_configuration.aws_oss_tooling ? 1 : 0
  identity_store_id = tolist(data.aws_ssoadmin_instances.current.identity_store_ids)[0]
  display_name      = "grafana-admins"
  description       = "Grafana Administrators"
}

resource "aws_identitystore_group_membership" "group_membership" {
  count             = var.observability_configuration.aws_oss_tooling ? 1 : 0
  identity_store_id = tolist(data.aws_ssoadmin_instances.current.identity_store_ids)[0]
  group_id          = aws_identitystore_group.group[count.index].group_id
  member_id         = aws_identitystore_user.user[count.index].user_id
}
