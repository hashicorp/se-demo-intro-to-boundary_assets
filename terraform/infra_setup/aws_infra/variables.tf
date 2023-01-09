variable "unique_name" {
  type = string
  default = ""
}

variable "admin_ip" {
  type = string
  default = ""
}

variable "admin_ip_additional" {
  type = string
  default = ""
}

variable "aws_region" {
  type = string
  default = "us-east-1"
}

variable "aws_az" {
  type = string
}

variable "aws_vpc_cidr" {
  type = string
  default = "10.11.0.0/16"
}
