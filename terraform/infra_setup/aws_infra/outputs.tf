output "aws_ami_ubuntu" {
  description = "The latest Ubuntu 22.04 AMI."
  value = data.aws_ami.ubuntu.id
}

output "aws_vpc" {
  description = "The ID of the AWS VPC created for the demo."
  value = aws_vpc.boundary_demo.id
}

output "aws_subnet_public_id" {
  description = "The ID of the public subnet created for the demo."
  value = aws_subnet.boundary_demo_public.id
}

output "aws_secgroup_public_id" {
  description = "The ID of the public-subnet security group created for the demo."
  value = aws_security_group.boundary_demo_public.id
}

output "aws_subnet_private_id" {
  description = "The ID of the private subnet created for the demo."
  value = aws_subnet.boundary_demo_private.id
}

output "aws_secgroup_private_id" {
  description = "The ID of the private-subnet security group created for the demo."
  value = aws_security_group.boundary_demo_private.id
}

output "aws_ssh_keypair_app_infra" {
  description = "The name of the app infrastructure AWS SSH keypair."
  value = aws_key_pair.app_infra.key_name
}

output "app_infra_ssh_privkey" {
  description = "The raw content of the app infrastructure SSH private key."
  value = tls_private_key.aws_infra_ssh_key.private_key_openssh
}
