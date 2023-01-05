variable "unique_name" {
  type = string
  default = ""
}

variable "aws_region" {
  type = string
}

variable "worker_subnet" {
  type = string
}

variable "worker_secgroup" {
  type = string
}

variable "worker_instance_type" {
  type = string
  default = "t3.small"
}

