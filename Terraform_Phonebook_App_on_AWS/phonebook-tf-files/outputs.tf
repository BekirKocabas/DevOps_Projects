# output "my-subnets" {
#   value = data.aws_subnets.pb-subnets.ids
# }

# output "my-ami" {
#   value = data.aws_ami.amazon-linux-2.id
# }

output "my-website-URL" {
  value = "http://${aws_lb.app-lb.dns_name}"

}