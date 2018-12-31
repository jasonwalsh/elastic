provider "aws" {
  access_key = "${var.access_key}"
  region     = "${var.region}"
  secret_key = "${var.secret_key}"
}

data "aws_ami" "ami" {
  filter {
    name   = "name"
    values = ["elastic-*"]
  }

  most_recent = true
  owners      = ["self"]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_key_pair" "key_pair" {
  public_key = "${file(pathexpand("${var.public_key}"))}"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.50.0"

  azs = [
    "${data.aws_availability_zones.available.names}",
  ]

  cidr                         = "${var.cidr}"
  create_database_subnet_group = false
  create_vpc                   = true
  enable_dns_hostnames         = "${var.enable_dns_hostnames}"
  enable_nat_gateway           = "${var.enable_nat_gateway}"
  name                         = "elastic"
  private_subnets              = "${var.private_subnets}"
  public_subnets               = "${var.public_subnets}"
  tags                         = "${var.tags}"
}

module "security_group_ssh" {
  source  = "terraform-aws-modules/security-group/aws//modules/ssh"
  version = "2.4.0"

  ingress_cidr_blocks = [
    "0.0.0.0/0",
  ]

  name   = "SSH"
  tags   = "${var.tags}"
  vpc_id = "${module.vpc.vpc_id}"
}
