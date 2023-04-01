output "unique_name" {
  description = "The unique name used to create resources in this workspace."
  value = local.unique_name
}

output "aws_region" {
  description = "The AWS region."
  value = var.aws_region
}

output "aws_ami" {
  description = "The Ubuntu AMI used for instances."
  value = module.aws_infra.aws_ami_ubuntu
}

output "aws_ssh_key_app_infra" {
  description = "The app infrastructure SSH keypair name."
  value = module.aws_infra.aws_ssh_keypair_app_infra
}

output "aws_subnet_public" {
  description = "The AWS VPC public subnet ID."
  value = module.aws_infra.aws_subnet_public_id
}

output "aws_subnet_private" {
  description = "The AWS VPC private subnet ID."
  value = module.aws_infra.aws_subnet_private_id
}

output "aws_secgroup_public" {
  description = "The AWS VPC public security group ID."
  value = module.aws_infra.aws_secgroup_public_id
}

output "aws_secgroup_private" {
  description = "The AWS VPC private security group ID."
  value = module.aws_infra.aws_secgroup_private_id
}

output "boundary_worker_ip_public" {
  description = "The public IP of the Boundary worker."
  value = module.boundary_setup.boundary_worker_ip_public
}

output "boundary_worker_dns_public" {
  description = "The public DNS of the Boundary worker."
  value = module.boundary_setup.boundary_worker_dns_public
}

output "postgres_server" {
  description = "The Postgres server hostname."
  value = module.postgres.dns
}

output "postgres_k8s_admin_password" {
  description = "The Kubernetes postgres server admin password."
  value = module.k8s_cluster.postgres_k8s_admin_password
}

output "k8s_cluster_api" {
  description = "The Kubernetes cluster API endpoint hostname."
  value = module.k8s_cluster.dns
}

output "vault_server" {
  description = "The Vault server hostname and IP created."
  value = module.vault_server.dns
}
