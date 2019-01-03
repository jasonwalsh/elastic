// Provider variables
variable "access_key" {
  description = "This is the AWS access key"
}

variable "region" {
  description = "This is the AWS region"
}

variable "secret_key" {
  description = "This is the AWS secret key"
}

// Resource variables
variable "cidr" {
  description = "The IPv4 network range for the VPC, in CIDR notation"
}

variable "desired_capacity" {
  description = "The number of EC2 instances that should be running in the group"
}

variable "enable_dns_hostnames" {
  default     = true
  description = "If enabled, instances in the VPC get DNS hostnames; otherwise, they do not"
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway in the specified public subnet"
}

variable "instance_type" {
  description = "The instance type of the EC2 instance"
}

variable "max_size" {
  description = "The maximum size of the group"
}

variable "min_size" {
  description = "The minimum size of the group"
}

variable "private_key" {
  description = "The private key material"
}

variable "private_subnets" {
  default = []
  type    = "list"
}

variable "public_key" {
  description = "The public key material"
}

variable "public_subnets" {
  default = []
  type    = "list"
}

variable "tags" {
  default     = {}
  description = "One or more tags"
  type        = "map"
}
