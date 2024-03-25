output "vpc_id" {
  description = "The ID of the VPC"
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value = module.vpc.public_subnets
}

output "intra_subnet_ids" {
  description = "List of IDs of intra subnets"
  value = module.vpc.intra_subnets
}
