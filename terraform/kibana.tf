# ------------ Kibana Settings ------------
module "security_group_kibana" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.9.0"

  egress_rules = [
    "all-all",
  ]

  ingress_with_cidr_blocks = [
    {
      # Kibana ingress
      from_port   = 80
      protocol    = "TCP"
      to_port     = 80
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  ingress_with_cidr_blocks = [
    {
      # Kibana ingress
      from_port   = 5601
      protocol    = "TCP"
      to_port     = 5601
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  name   = "kibana"
  tags   = "${var.tags}"
  vpc_id = "${module.vpc.vpc_id}"
}

module "alb_kibana" {
  source  = "terraform-aws-modules/alb/aws"
  version = "3.5.0"

  enable_cross_zone_load_balancing = true

  http_tcp_listeners = [
    {
      port     = 80
      protocol = "HTTP"
    },
  ]

  http_tcp_listeners_count = 1

  load_balancer_is_internal = false
  load_balancer_name        = "kibana"
  logging_enabled           = false

  security_groups = [
    "${module.security_group_kibana.this_security_group_id}",
  ]

  subnets = "${module.vpc.public_subnets}"
  tags    = "${var.tags}"

  target_groups = [
    {
      name             = "kibana"
      backend_protocol = "HTTP"
      backend_port     = 5601
    },
  ]

  target_groups_count = 1

  target_groups_defaults = {
    health_check_matcher = "302"
  }

  vpc_id = "${module.vpc.vpc_id}"
}

data "template_file" "kibana_config" {
  template = "${local.config["kibana"]}"

  vars {
    elasticsearch_url = "http://${module.alb_elasticsearch.dns_name}:9200"
  }
}

data "template_file" "kibana" {
  template = "${file("${path.module}/templates/kibana/user-data.conf")}"

  vars {
    config = "${base64encode(data.template_file.kibana_config.rendered)}"
  }
}

module "kibana" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "2.9.0"

  asg_name                    = "kibana"
  associate_public_ip_address = false
  create_asg                  = true
  create_lc                   = true
  desired_capacity            = "${var.desired_capacity}"
  health_check_type           = "EC2"
  iam_instance_profile        = "${aws_iam_instance_profile.elasticsearch.name}"
  image_id                    = "${data.aws_ami.ami.id}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${aws_key_pair.key_pair.key_name}"
  max_size                    = "${var.max_size}"
  min_size                    = "${var.min_size}"
  name                        = "kibana"

  security_groups = [
    "${module.security_group_ssh.this_security_group_id}",
    "${module.security_group_kibana.this_security_group_id}",
  ]

  tags_as_map = "${var.tags}"

  target_group_arns = [
    "${module.alb_kibana.target_group_arns}",
  ]

  user_data = "${data.template_file.kibana.rendered}"

  vpc_zone_identifier = [
    "${module.vpc.public_subnets}",
  ]
}
