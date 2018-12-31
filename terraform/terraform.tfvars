cidr = "10.0.0.0/16"

desired_capacity = 3

instance_type = "t2.medium"

enable_nat_gateway = true

max_size = 3

min_size = 2

private_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24",
]

public_key = "~/.ssh/id_rsa.pub"

public_subnets = [
  "10.0.3.0/24",
  "10.0.4.0/24",
]

tags = {
  Environment = "staging"
}
