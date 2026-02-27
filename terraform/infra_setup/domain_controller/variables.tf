variable "unique_name" {
  type    = string
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

variable "create_domain_controller" {
  type    = bool
  default = true
}

variable "domain_controller_subnet_id" {
  type = string
}

variable "domain_controller_secgroup_id" {
  type = string
}

variable "domain_controller_instance_type" {
  type    = string
  default = "t3.small"
}

variable "domain_controller_ssh_keypair" {
  type = string
}