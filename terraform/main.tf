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

# ------------ Logstash Settings ------------
module "security_group_logstash" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.9.0"

  ingress_with_cidr_blocks = [
    {
      # Metricbeat ingress
      from_port   = 5044
      protocol    = "TCP"
      to_port     = 5044
      cidr_blocks = "0.0.0.0/0"
    },
    {
      # Logstash ingress
      from_port   = 9600
      protocol    = "TCP"
      to_port     = 9600
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  name   = "logstash"
  tags   = "${var.tags}"
  vpc_id = "${module.vpc.vpc_id}"
}

data "template_file" "logstash" {
  template = "${file("${path.module}/templates/user-data.conf")}"

  vars {
    config   = "${base64encode("${file("${path.module}/templates/logstash.yml")}")}"
    pipeline = "${base64encode("${file("${path.module}/templates/pipeline.conf")}")}"
  }
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
    "${module.security_group_ssh.this_security_group_id}",
    "${module.security_group_logstash.this_security_group_id}",
  ]

  name = "logstash"

  tags = [
    "${var.tags}",
  ]

  user_data = "${data.template_file.logstash.rendered}"

  vpc_zone_identifier = [
    "${module.vpc.public_subnets}",
  ]
}
