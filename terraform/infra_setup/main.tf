terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    boundary = {
      source = "hashicorp/boundary"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "boundary" {
  addr = var.boundary_cluster_admin_url
}

data "http" "admin_ip_dyn" {
  url = "http://whatismyip.akamai.com/"
}

resource "random_pet" "unique_name" {
}

resource "random_integer" "unique_name" {
  min = 1000000
  max = 1999999
}

locals {
  unique_name = coalesce(var.unique_name, "${random_pet.unique_name.id}-${substr(random_integer.unique_name.result, -6, -1)}")
  admin_ip_result = "${data.http.admin_ip_dyn.response_body}/32"
  aws_instance_types = [ var.aws_k8s_node_instance_type, var.aws_postgres_node_instance_type, var.aws_vault_node_instance_type ]
}

module "aws_infra" {
  source = "./aws_infra"
  unique_name = local.unique_name
  admin_ip = local.admin_ip_result
  admin_ip_additional = var.admin_ip_additional
  aws_region = var.aws_region
  aws_instance_types = local.aws_instance_types
  aws_vpc_cidr = var.aws_vpc_cidr
}

module "boundary_setup" {
  depends_on = [ module.aws_infra ]
  source = "./boundary_setup"
  unique_name = local.unique_name
  aws_region = var.aws_region
  aws_vpc = module.aws_infra.aws_vpc
  aws_ami = module.aws_infra.aws_ami_ubuntu
  aws_public_secgroup_id = module.aws_infra.aws_secgroup_public_id
  app_infra_ssh_privkey = module.aws_infra.app_infra_ssh_privkey
  boundary_worker_instance_type = var.aws_boundary_worker_instance_type
  boundary_worker_subnet_id = module.aws_infra.aws_subnet_public_id
  boundary_cluster_admin_url = var.boundary_cluster_admin_url
}

module "postgres" {
  depends_on = [ module.aws_infra ]
  source = "./postgres"
  unique_name = local.unique_name
  aws_region = var.aws_region
  aws_ami = module.aws_infra.aws_ami_ubuntu
  pg_instance_type = var.aws_postgres_node_instance_type
  pg_subnet_id = module.aws_infra.aws_subnet_private_id
  pg_secgroup_id = module.aws_infra.aws_secgroup_private_id
  pg_ssh_keypair = module.aws_infra.aws_ssh_keypair_app_infra
}

module "k8s_cluster" {
  depends_on = [ module.aws_infra, module.boundary_setup ]
  source = "./k8s_cluster"
  unique_name = local.unique_name
  aws_region = var.aws_region
  aws_vpc = module.aws_infra.aws_vpc
  aws_ami = module.aws_infra.aws_ami_ubuntu
  boundary_cluster_admin_url = var.boundary_cluster_admin_url
  boundary_instance_worker_addr = "${module.boundary_setup.boundary_worker_dns_public}:9202"
  k8s_instance_type = var.aws_k8s_node_instance_type
  k8s_subnet_id = module.aws_infra.aws_subnet_private_id
  k8s_secgroup_id = module.aws_infra.aws_secgroup_private_id
  k8s_boundary_worker_lb_subnet_id = module.aws_infra.aws_subnet_public_id
  k8s_boundary_worker_lb_secgroup_id = module.aws_infra.aws_secgroup_public_id
  k8s_ssh_keypair = module.aws_infra.aws_ssh_keypair_app_infra
  k8s_nodeport_lb_vpc = module.aws_infra.aws_vpc
}

module "vault_server" {
  depends_on = [ module.postgres, module.k8s_cluster ]
  source = "./vault_server"
  unique_name = local.unique_name
  aws_region = var.aws_region
  aws_ami = module.aws_infra.aws_ami_ubuntu
  vault_instance_type = var.aws_vault_node_instance_type
  vault_subnet_id = module.aws_infra.aws_subnet_private_id
  vault_secgroup_id = module.aws_infra.aws_secgroup_private_id
  vault_ssh_keypair = module.aws_infra.aws_ssh_keypair_app_infra
  vault_lb_vpc = module.aws_infra.aws_vpc
  create_postgres = var.create_postgres
  postgres_server = module.postgres.dns
  pg_vault_user = module.postgres.vault_user
  pg_vault_password = module.postgres.vault_password
}
