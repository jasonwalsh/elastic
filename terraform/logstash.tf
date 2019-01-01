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

# This data source renders a cloud-init configuration file for provisioning
# instances associated with the Auto Scaling Group. Modifications to either
# file forces Terraform to recreate the Launch Configuration.
data "template_file" "logstash" {
  template = "${file("${path.module}/templates/logstash/user-data.conf")}"

  vars {
    config   = "${base64encode(local.config["logstash"])}"
    pipeline = "${base64encode(data.template_file.pipeline.rendered)}"
  }
}

data "template_file" "pipeline" {
  template = "${file("${path.module}/templates/logstash/pipeline.conf")}"

  vars {
    dns_name = "${module.alb_elasticsearch.dns_name}"
  }
}

module "logstash" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "2.9.0"

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
  name                        = "logstash"

  security_groups = [
    "${module.security_group_ssh.this_security_group_id}",
    "${module.security_group_logstash.this_security_group_id}",
  ]

  tags_as_map = "${var.tags}"
  user_data   = "${data.template_file.logstash.rendered}"

  vpc_zone_identifier = [
    "${module.vpc.public_subnets}",
  ]
}
