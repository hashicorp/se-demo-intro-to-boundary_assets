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

locals {
  admin_ip_result = "${data.http.admin_ip_dyn.response_body}/32"
  unique_name = coalesce(var.unique_name, "${random_pet.unique_name.id}-${substr(random_integer.unique_name.result, -6, -1)}")
}

module "aws_infra" {
  source = "./aws_infra"
  unique_name = local.unique_name
  admin_ip = local.admin_ip_result
  admin_ip_additional = var.admin_ip_additional
  aws_region = var.aws_region
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
}
