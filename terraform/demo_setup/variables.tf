variable "unique_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_ami" {
  type = string
}

variable "aws_boundary_worker_instance_type" {
  type = string
  default = "t3.small"
}

variable "aws_boundary_worker_subnet_id" {
  type = string
}

variable "aws_boundary_worker_secgroup_id" {
  type = string
}

variable "aws_boundary_worker_ssh_keypair" {
  type = string
}

variable "boundary_cluster_admin_url" {
  type = string
}
