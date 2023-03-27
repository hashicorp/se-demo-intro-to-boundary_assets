variable "unique_name" {
  type = string
  default = "example"
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

variable "create_k8s" {
  type = bool
  default = true
}

variable "k8s_subnet_id" {
  type = string
}

variable "k8s_secgroup_id" {
  type = string
}

variable "k8s_instance_type" {
  type = string
  default = "t3.small"
}

variable "k8s_nodeport_lb_vpc" {
  type = string
}

variable "k8s_boundary_worker_lb_subnet_id" {
  type = string
}

variable "k8s_boundary_worker_lb_secgroup_id" {
  type = string
}

variable "k8s_ssh_keypair" {
  type = string
}

variable "boundary_cluster_admin_url" {
  type = string
}

variable "boundary_instance_worker_addr" {
  type = string
}