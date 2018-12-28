# ------------ Elasticsearch Settings ------------
module "security_group_elasticsearch" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.9.0"

  egress_rules = [
    "all-all",
  ]

  ingress_with_cidr_blocks = [
    {
      # Elasticsearch ingress
      from_port   = 9200
      protocol    = "TCP"
      to_port     = 9200
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  name   = "elasticsearch"
  tags   = "${var.tags}"
  vpc_id = "${module.vpc.vpc_id}"
}

module "alb_elasticsearch" {
  source  = "terraform-aws-modules/alb/aws"
  version = "3.5.0"

  enable_cross_zone_load_balancing = true

  http_tcp_listeners = [
    {
      port     = 9200
      protocol = "HTTP"
    },
  ]

  http_tcp_listeners_count = 1

  load_balancer_is_internal = true
  load_balancer_name        = "elasticsearch"
  logging_enabled           = false

  security_groups = [
    "${module.security_group_elasticsearch.this_security_group_id}",
  ]

  subnets = "${module.vpc.private_subnets}"

  target_groups = [
    {
      name             = "elasticsearch"
      backend_protocol = "HTTP"
      backend_port     = 9200
    },
  ]

  target_groups_count = 1

  tags   = "${var.tags}"
  vpc_id = "${module.vpc.vpc_id}"
}

data "template_file" "elasticsearch" {
  template = "${file("${path.module}/templates/elasticsearch/user-data.conf")}"

  vars {
    elasticsearch_config = "${base64encode("${file("${path.module}/templates/elasticsearch/elasticsearch.yml")}")}"
    kibana_config        = "${base64encode("${file("${path.module}/templates/kibana/kibana.yml")}")}"
  }
}

module "elasticsearch" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "2.9.0"

  asg_name                    = "elasticsearch"
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
  name                        = "elasticsearch"

  security_groups = [
    "${module.security_group_ssh.this_security_group_id}",
    "${module.security_group_elasticsearch.this_security_group_id}",
    "${module.security_group_kibana.this_security_group_id}",
  ]

  tags = [
    "${var.tags}",
  ]

  target_group_arns = [
    "${module.alb_elasticsearch.target_group_arns}",
    "${module.alb_kibana.target_group_arns}",
  ]

  user_data = "${data.template_file.elasticsearch.rendered}"

  vpc_zone_identifier = [
    "${module.vpc.public_subnets}",
  ]
}
