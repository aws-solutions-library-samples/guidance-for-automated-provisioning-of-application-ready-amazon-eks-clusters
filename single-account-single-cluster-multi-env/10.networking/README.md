# Networking

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.40.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.40.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_endpoints"></a> [endpoints](#module\_endpoints) | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | 5.5.3 |
| <a name="module_subnets"></a> [subnets](#module\_subnets) | hashicorp/subnets/cidr | 1.0.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 5.5.2 |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_config"></a> [cluster\_config](#input\_cluster\_config) | cluster configurations such as version, public/private API endpoint, and more | `map(string)` | `{}` | no |
| <a name="input_control_plane_subnets_cidr_prefix"></a> [control\_plane\_subnets\_cidr\_prefix](#input\_control\_plane\_subnets\_cidr\_prefix) | CIDR prefix for the control plane subnets | `number` | `28` | no |
| <a name="input_num_azs"></a> [num\_azs](#input\_num\_azs) | Number of Availability Zones | `number` | `3` | no |
| <a name="input_private_subnets_cidr_prefix"></a> [private\_subnets\_cidr\_prefix](#input\_private\_subnets\_cidr\_prefix) | CIDR prefix for the private subnets | `number` | `20` | no |
| <a name="input_public_subnets_cidr_prefix"></a> [public\_subnets\_cidr\_prefix](#input\_public\_subnets\_cidr\_prefix) | CIDR prefix for the public subnets | `number` | `24` | no |
| <a name="input_shared_config"></a> [shared\_config](#input\_shared\_config) | Shared configuration across all modules/folders | `map(any)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_intra_subnet_ids"></a> [intra\_subnet\_ids](#output\_intra\_subnet\_ids) | List of IDs of intra subnets |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of IDs of private subnets |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of IDs of public subnets |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->