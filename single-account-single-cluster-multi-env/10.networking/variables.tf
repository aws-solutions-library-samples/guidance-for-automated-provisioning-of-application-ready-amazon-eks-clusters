
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

}

variable "num_azs" {
  description = "Number of Availability Zones"
  type        = number
  default     = 3
}

variable "private_subnets_cidr_prefix" {
  description = "CIDR prefix for the private subnets"
  type        = number
  default     = 20
}

variable "public_subnets_cidr_prefix" {
  description = "CIDR prefix for the public subnets"
  type        = number
  default     = 24
}

variable "control_plane_subnets_cidr_prefix" {
  description = "CIDR prefix for the control plane subnets"
  type        = number
  default     = 28
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}


variable "cluster_config" {
  description = "cluster configurations such as version, public/private API endpoint, and more"
  type        = map(string)
  default     = {}
}

variable "shared_config" {
  description = "Shared configuration across all modules/folders"
  type        = map(any)
  default     = {}
}

