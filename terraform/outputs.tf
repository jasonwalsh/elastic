output "aws_ami" {
  value = "${data.aws_ami.ami.id}"
}
