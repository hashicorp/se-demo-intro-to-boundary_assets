variable "unique_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_vpc" {
  type = string
}

variable "aws_ami" {
  type = string
}

variable "aws_public_secgroup_id" {
  type = string
}

variable "app_infra_ssh_privkey" {
  type = string
}

variable "boundary_worker_subnet_id" {
  type = string
}

variable "boundary_cluster_admin_url" {
  type = string
}

variable "boundary_worker_instance_type" {
  type = string
  default = "t3.small"
}

variable "create_k8s" {
  type = bool
  default = true
}