# ------------ Kibana Settings ------------
module "security_group_kibana" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.9.0"

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
