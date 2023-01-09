terraform {
}

resource "random_pet" "unique_name" {
}

resource "random_integer" "unique_name" {
  min = 1000000
  max = 1999999
}

data "http" "admin_ip_dyn" {
  url = "http://whatismyip.akamai.com/"
}

data "aws_ec2_instance_type_offerings" "postgres_azs" {
  location_type = "availability-zone"
  filter {
    name = "instance-type"
    values = [ var.aws_postgres_node_instance_type ]
  }
}

data "aws_ec2_instance_type_offerings" "k8s_azs" {
  location_type = "availability-zone"
  filter {
    name = "instance-type"
    values = [ "aws_k8s_node_instance_type" ]
  }
}

data "aws_ec2_instance_type_offerings" "vault_azs" {
  location_type = "availability-zone"
  filter {
    name = "instance-type"
    values = [ var.vault_node_instance_type ]
  }
}

locals {
  admin_ip_result = "${data.http.admin_ip_dyn.response_body}/32"
  usable_azs = tolist(setintersection(data.aws_ec2_instance_type_offerings.k8s_azs.locations, data.aws_ec2_instance_type_offerings.postgres_azs.locations, data.aws_ec2_instance_type_offerings.vault_azs.locations))
  unique_name = coalesce(var.unique_name, "${random_pet.unique_name.id}-${substr(random_integer.unique_name.result, -6, -1)}")
}

module "aws_infra" {
  source = "./aws_infra"
  unique_name = local.unique_name
  admin_ip = local.admin_ip_result
  admin_ip_additional = var.admin_ip_additional
  aws_region = var.aws_region
  aws_az = local.usable_azs[0]
  aws_vpc_cidr = var.aws_vpc_cidr
}

module "postgres" {
  source = "./postgres"
  unique_name = local.unique_name
  aws_region = var.aws_region
  aws_ami = module.aws_infra.aws_ami_ubuntu
  pg_instance_type = var.aws_postgres_node_instance_type
  pg_subnet_id = module.aws_infra.aws_subnet_private_id
  pg_secgroup_id = module.aws_infra.aws_secgroup_private_id
  pg_ssh_keypair = module.aws_infra.aws_ssh_keypair_app_infra
}

module "vault_server" {
  source = "./vault_server"
  unique_name = local.unique_name
  aws_region = var.aws_region
  aws_ami = module.aws_infra.aws_ami_ubuntu
  vault_instance_type = var.aws_vault_node_instance_type
  vault_subnet_id = module.aws_infra.aws_subnet_private_id
  vault_secgroup_id = module.aws_infra.aws_secgroup_private_id
  vault_ssh_keypair = module.aws_infra.aws_ssh_keypair_app_infra
  vault_lb_vpc = module.aws_infra.aws_vpc
}

module "k8s_cluster" {
  source = "./k8s_cluster"
  unique_name = local.unique_name
  aws_region = var.aws_region
  aws_ami = module.aws_infra.aws_ami_ubuntu
  k8s_instance_type = var.aws_k8s_node_instance_type
  k8s_subnet_id = module.aws_infra.aws_subnet_private_id
  k8s_secgroup_id = module.aws_infra.aws_secgroup_private_id
  k8s_boundary_worker_lb_subnet_id = module.aws_infra.aws_subnet_public_id
  k8s_boundary_worker_lb_secgroup_id = module.aws_infra.aws_secgroup_public_id
  k8s_ssh_keypair = module.aws_infra.aws_ssh_keypair_app_infra
  k8s_nodeport_lb_vpc = module.aws_infra.aws_vpc
}
