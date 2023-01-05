terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    boundary = {
      source = "hashicorp/boundary"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "boundary" {
  addr = var.boundary_url
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_eip" "boundary_demo_worker" {
}

resource "boundary_worker" "boundary_demo_worker" {
  scope_id = "global"
  description = "An instance-based self-managed worker in a public AWS VPC subnet."
  name = "${var.unique_name}-aws"
}

resource "aws_key_pair" "boundary_demo_worker" {
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "boundary_demo_worker" {
  associate_public_ip_address = true
  ami = data.aws_ami.ubuntu.id
  subnet_id = var.worker_subnet
  instance_type = var.worker_instance_type
  vpc_security_group_ids = [ var.worker_secgroup ]
  key_name = aws_key_pair.boundary_demo_worker.key_name
}
