terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.aws_region
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

data "aws_ec2_instance_type_offerings" "instance_types" {
  for_each = toset(var.aws_instance_types)
  location_type = "availability-zone"
  filter {
    name = "instance-type"
    values = [ each.key ]
  }
}

locals {
  usable_azs = sort(flatten(tolist(setintersection([ for az_set in data.aws_ec2_instance_type_offerings.instance_types : toset(az_set.locations) ]))))
}

resource "tls_private_key" "aws_infra_ssh_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "app_infra" {
  key_name = "${var.unique_name}-app-infra"
  public_key = tls_private_key.aws_infra_ssh_key.public_key_openssh
}

resource "local_file" "aws_infra_ssh_privkey" {
  content = tls_private_key.aws_infra_ssh_key.private_key_openssh
  filename = "${path.root}/gen_files/ssh_keys/app_infra"
  file_permission = "0600"
}

resource "aws_vpc" "boundary_demo" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "boundary_demo_private" {
  vpc_id            = aws_vpc.boundary_demo.id
  cidr_block        = cidrsubnet(aws_vpc.boundary_demo.cidr_block, 1, 1)
  availability_zone = local.usable_azs[0]
}

resource "aws_subnet" "boundary_demo_public" {
  vpc_id            = aws_vpc.boundary_demo.id
  cidr_block        = cidrsubnet(aws_vpc.boundary_demo.cidr_block, 1, 0)
  availability_zone = aws_subnet.boundary_demo_private.availability_zone
}

resource "aws_security_group" "boundary_demo_public" {
  name = "${var.unique_name}-public"
  vpc_id = aws_vpc.boundary_demo.id
  ingress {
    description = "Unrestricted admin access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = compact(flatten([aws_vpc.boundary_demo.cidr_block, var.admin_ip, var.admin_ip_additional]))
  }
  egress {
    description = "Unrestricted egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_security_group" "boundary_demo_private" {
  name = "${var.unique_name}-private"
  vpc_id = aws_vpc.boundary_demo.id
  ingress {
    description = "VPC-local access only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.boundary_demo.cidr_block]
  }
  egress { 
    description = "Unrestricted egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_internet_gateway" "boundary_demo" {
  vpc_id = aws_vpc.boundary_demo.id
}

resource "aws_eip" "boundary_demo_nat_gw" {
  depends_on = [aws_internet_gateway.boundary_demo]
}

resource "aws_nat_gateway" "boundary_demo_private" {
  allocation_id = aws_eip.boundary_demo_nat_gw.allocation_id
  subnet_id  = aws_subnet.boundary_demo_public.id
  depends_on = [aws_internet_gateway.boundary_demo]
}

resource "aws_route_table" "boundary_demo_public" {
  vpc_id = aws_vpc.boundary_demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.boundary_demo.id
  }
}

resource "aws_route_table_association" "boundary_demo_public" {
  subnet_id      = aws_subnet.boundary_demo_public.id
  route_table_id = aws_route_table.boundary_demo_public.id
}

resource "aws_route_table" "boundary_demo_private" {
  vpc_id = aws_vpc.boundary_demo.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.boundary_demo_private.id
  }
}

resource "aws_route_table_association" "boundary_demo_private" {
  subnet_id      = aws_subnet.boundary_demo_private.id
  route_table_id = aws_route_table.boundary_demo_private.id
}
