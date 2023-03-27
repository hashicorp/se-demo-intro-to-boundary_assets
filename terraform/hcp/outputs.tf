output "unique_name" {
  description = "The unique name used to create resources in this workspace."
  value = local.unique_name
}

output "boundary_cluster_admin_url" {
  description = "The admin URL of the created Boundary cluster."
  value = local.boundary_cluster_admin_url
}

output "boundary_cluster_admin_auth_method" {
  description = "The initial auth method ID of the created Boundary cluster."
  value = local.boundary_cluster_admin_auth_method
}

output "boundary_admin_login" {
  description = "The admin username used to create the cluster."
  value = local.boundary_admin_login
}

output "boundary_admin_password" {
  description = "The admin password randomly generated for the cluster."
  value = local.boundary_admin_password
  sensitive = true
}