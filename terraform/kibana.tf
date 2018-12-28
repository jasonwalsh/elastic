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
      port     = 5601
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
