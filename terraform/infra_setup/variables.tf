variable "unique_name" {
  type = string
  default=""
}

variable "aws_region" {
  type = string
  default = "us-east-1"
}

variable "aws_vpc_cidr" {
  type = string
  default = "10.11.0.0/16"
}

variable "aws_boundary_worker_instance_type" {
  type = string
  default = "t3.medium"
}

variable "aws_vault_node_instance_type" {
  type = string
  default = "t3.medium"
}

variable "aws_k8s_node_instance_type" {
  type = string
  default = "t3.large"
}

variable "aws_postgres_node_instance_type" {
  type = string
  default = "t3.medium"
}

variable "create_postgres" {
  type = bool
  default = true
}

variable "create_k8s" {
  type = bool
  default = true
}

variable "admin_ip_additional" {
  type = string
  default = ""
}

variable "boundary_cluster_admin_url" {
  type = string
}
