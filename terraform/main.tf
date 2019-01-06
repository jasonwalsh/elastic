provider "aws" {
  access_key = "${var.access_key}"
  region     = "${var.region}"
  secret_key = "${var.secret_key}"
}

locals {
  config = {
    elasticsearch = "${file("${path.module}/templates/elasticsearch/elasticsearch.yml")}"
    kibana        = "${file("${path.module}/templates/kibana/kibana.yml")}"
    logstash      = "${file("${path.module}/templates/logstash/logstash.yml")}"
  }
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

data "aws_region" "current" {}

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

data "aws_ami" "bastion" {
  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-ebs"]
  }

  most_recent = true

  owners = [
    "amazon",
  ]
}

module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "1.13.0"

  ami                         = "${data.aws_ami.bastion.id}"
  associate_public_ip_address = true
  instance_count              = 1
  instance_type               = "t2.micro"
  key_name                    = "${aws_key_pair.key_pair.key_name}"
  name                        = "bastion"
  subnet_id                   = "${element(module.vpc.public_subnets, 0)}"
  tags                        = "${var.tags}"

  vpc_security_group_ids = [
    "${module.security_group_ssh.this_security_group_id}",
  ]
}

resource "null_resource" "bastion" {
  connection {
    host        = "${module.bastion.public_ip}"
    private_key = "${file("${pathexpand("${var.private_key}")}")}"
    user        = "ec2-user"
  }

  provisioner "file" {
    content     = "${file("${pathexpand("${var.private_key}")}")}"
    destination = "~/.ssh/id_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0400 ~/.ssh/id_rsa",
    ]
  }
}
