output "kibana" {
  value = "${module.alb_kibana.dns_name}"
}
