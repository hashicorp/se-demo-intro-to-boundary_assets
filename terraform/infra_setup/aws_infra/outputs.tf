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

output "aws_secgroup_inet_id" {
  description = "The ID of the unrestricted Internet-incoming security group created for the demo."
  value = aws_security_group.boundary_demo_inet.id
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

output "aws_ssh_keypair_boundary_infra" {
  description = "The name of the Boundary worker AWS SSH keypair."
  value = aws_key_pair.boundary_infra.key_name
}

output "app_infra_ssh_privkey" {
  description = "The raw content of the app infrastructure SSH private key."
  value = file("${path.root}/gen_files/app_infra")
}

output "boundary_infra_ssh_privkey" {
  description = "The raw content of the Boundary worker SSH private key."
  value = file("${path.root}/gen_files/boundary_infra")
}
