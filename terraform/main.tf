provider "aws" {
  profile = "${var.profile}"
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
  source = "terraform-aws-modules/vpc/aws"

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

module "allow_ssh" {
  source  = "terraform-aws-modules/security-group/aws//modules/ssh"
  version = "2.4.0"

  ingress_cidr_blocks = [
    "0.0.0.0/0",
  ]

  name   = "SSH"
  tags   = "${var.tags}"
  vpc_id = "${module.vpc.vpc_id}"
}

module "logstash" {
  source = "terraform-aws-modules/autoscaling/aws"

  asg_name                    = "logstash"
  associate_public_ip_address = true
  create_asg                  = true
  create_lc                   = true
  desired_capacity            = "${var.desired_capacity}"
  health_check_type           = "EC2"
  image_id                    = "${data.aws_ami.ami.id}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${aws_key_pair.key_pair.key_name}"
  max_size                    = "${var.max_size}"
  min_size                    = "${var.min_size}"

  security_groups = [
    "${module.allow_ssh.this_security_group_id}",
  ]

  name = "logstash"

  tags = [
    "${var.tags}",
  ]

  vpc_zone_identifier = [
    "${module.vpc.public_subnets}",
  ]
}
