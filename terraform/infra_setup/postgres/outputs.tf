output "admin_user" {
  description = "The admin username of the Postgres server."
  value = var.create_postgres == true ? var.pg_admin_user : ""
}

output "admin_password" {
  description = "The generated admin password of the Postgres server."
  value = var.create_postgres == true ? random_pet.admin_password.id : ""
}

output "vault_user" {
  description = "The user name for Vault to use for auth to manage dynamic secrets."
  value = var.create_postgres == true ? var.pg_vault_user : ""
}

output "vault_password" {
  description = "The password for Vault to use for auth to manage dynamic secrets."
  value = var.create_postgres == true ? random_pet.vault_password.id : ""
}

output "dns" {
  description = "The DNS name of the Postgres server."
  value = var.create_postgres == true ? aws_instance.postgres[0].private_dns : ""
}

output "ip_private" {
  description = "The private IP of the Postgres server."
  value = var.create_postgres == true ? aws_instance.postgres[0].private_ip : ""
}
