variable "unique_name" {
  type = string
  default = "example"
}

variable "aws_region" {
  type = string
}

variable "aws_ami" {
  type = string
}

variable "create_postgres" {
  type = bool
  default = true
}

variable "pg_subnet_id" {
  type = string
}

variable "pg_secgroup_id" {
  type = string
}

variable "pg_instance_type" {
  type = string
  default = "t3.small"
}

variable "pg_ssh_keypair" {
  type = string
}

variable "pg_admin_user" {
  type = string
  default = "pg_admin"
}
