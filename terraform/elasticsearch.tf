# ------------ Elasticsearch Settings ------------

locals {
  endpoint = "${lookup(local.endpoints, var.region, "us-east-1")}"

  nodes = "${list(
      map("master", "true", "data", "false", "ingest", "false"),
      map("master", "false", "data", "true", "ingest", "false")
    )}"
}

# EC2 discovery requires making a call to the EC2 service.
resource "aws_iam_role_policy" "elasticsearch" {
  name = "elasticsearch"

  policy = <<EOF
{
"Statement": [
  {
    "Action": [
      "ec2:DescribeInstances"
    ],
    "Effect": "Allow",
    "Resource": [
      "*"
    ]
  }
],
"Version": "2012-10-17"
}
EOF

  role = "${aws_iam_role.elasticsearch.id}"
}

resource "aws_iam_role" "elasticsearch" {
  assume_role_policy = <<EOF
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Sid": ""
    }
  ],
  "Version": "2012-10-17"
}
EOF

  name = "elasticsearch"
}

resource "aws_iam_instance_profile" "elasticsearch" {
  name = "elasticsearch"
  role = "${aws_iam_role_policy.elasticsearch.role}"
}

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
    {
      # Elasticsearch transport ingress rule for internal communication between
      # nodes within the cluster.
      from_port = 9300

      protocol    = "TCP"
      to_port     = 9400
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

data "template_file" "config" {
  template = "${local.config["elasticsearch"]}"

  vars {
    data   = "${lookup(local.nodes[count.index], "data")}"
    ingest = "${lookup(local.nodes[count.index], "ingest")}"
    master = "${lookup(local.nodes[count.index], "master")}"

    endpoint             = "${local.endpoint}"
    minimum_master_nodes = "${floor((var.desired_capacity / 2) + 1)}"
    security_group_ids   = "${module.security_group_elasticsearch.this_security_group_id}"
  }

  count = "${length(local.nodes)}"
}

data "template_file" "elasticsearch" {
  template = "${file("${path.module}/templates/elasticsearch/user-data.conf")}"

  vars {
    # Sensitive data stored within the Elasticsearch keystore.
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"

    config = "${base64encode(element(data.template_file.config.*.rendered, count.index))}"
  }

  count = "${length(local.nodes)}"
}

module "master" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "2.9.0"

  asg_name                    = "elasticsearch"
  associate_public_ip_address = true
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
  name                        = "elasticsearch"

  security_groups = [
    "${module.security_group_ssh.this_security_group_id}",
    "${module.security_group_elasticsearch.this_security_group_id}",
  ]

  tags_as_map = "${merge(map("Node", "master"), var.tags)}"
  user_data   = "${element(data.template_file.elasticsearch.*.rendered, 0)}"

  vpc_zone_identifier = [
    "${module.vpc.public_subnets}",
  ]
}

module "data" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "2.9.0"

  asg_name                    = "elasticsearch"
  associate_public_ip_address = true
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
  name                        = "elasticsearch"

  security_groups = [
    "${module.security_group_ssh.this_security_group_id}",
    "${module.security_group_elasticsearch.this_security_group_id}",
  ]

  tags_as_map = "${merge(map("Node", "data"), var.tags)}"

  target_group_arns = [
    "${module.alb_elasticsearch.target_group_arns}",
  ]

  user_data = "${element(data.template_file.elasticsearch.*.rendered, 1)}"

  vpc_zone_identifier = [
    "${module.vpc.public_subnets}",
  ]
}
