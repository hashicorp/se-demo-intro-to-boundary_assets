terraform {
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "0.75.0"
    }
  }
}

provider "hcp" {}

resource "random_pet" "unique_name" {
}

resource "random_integer" "unique_name" {
  min = 1000000
  max = 1999999
}

resource "random_pet" "boundary_admin_password" {
  length = 4
}

resource "hcp_boundary_cluster" "boundary_demo" {
  cluster_id = substr(local.unique_name, 0, 32)
  username   = var.boundary_admin_login
  password   = random_pet.boundary_admin_password.id
  tier       = "Plus"
}

resource "time_sleep" "wait_for_boundary" {
  depends_on = [hcp_boundary_cluster.boundary_demo]

  create_duration = "30s"
}

data "http" "boundary_cluster_auth_methods" {
  depends_on = [time_sleep.wait_for_boundary, hcp_boundary_cluster.boundary_demo]
  url        = "${hcp_boundary_cluster.boundary_demo.cluster_url}/v1/auth-methods?scope_id=global"
}

locals {
  unique_name                        = coalesce(var.unique_name, "${random_pet.unique_name.id}-${substr(random_integer.unique_name.result, -6, -1)}")
  boundary_cluster_admin_url         = hcp_boundary_cluster.boundary_demo.cluster_url
  boundary_cluster_admin_auth_method = jsondecode(data.http.boundary_cluster_auth_methods.response_body).items[0].id
  boundary_admin_login               = var.boundary_admin_login
  boundary_admin_password            = random_pet.boundary_admin_password.id
}
