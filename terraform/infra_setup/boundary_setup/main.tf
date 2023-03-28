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

resource "aws_security_group" "boundary_demo_worker_inet" {
  name = "${var.unique_name}-inet"
  vpc_id = var.aws_vpc
  ingress {
    description = "Unrestricted Internet access"
    from_port   = 9202
    to_port     = 9202
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "tls_private_key" "boundary_instance_worker_ssh_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "boundary_infra" {
  key_name = "${var.unique_name}-boundary-infra"
  public_key = tls_private_key.boundary_instance_worker_ssh_key.public_key_openssh
}

resource "local_file" "boundary_instance_ssh_privkey" {
  content = tls_private_key.boundary_instance_worker_ssh_key.private_key_openssh
  filename = "${path.root}/gen_files/ssh_keys/boundary_infra"
  file_permission = "0600"
}

resource "boundary_worker" "hcp_pki_instance_worker" {
  scope_id = "global"
  name = "${var.unique_name}-vm"
  worker_generated_auth_token = ""
}

locals {
  boundary_worker_unit_dropin = <<-WORKER_UNIT_DROPIN
    [Service]
    ProtectSystem=off
    ExecStart=
    ExecStart=/usr/bin/boundary-worker server -config=/etc/boundary.d/boundary-pki-worker-config.hcl
    WORKER_UNIT_DROPIN

  boundary_instance_worker_config = <<-WORKER_CONFIG
    hcp_boundary_cluster_id = "${split(".", split("//", var.boundary_cluster_admin_url)[1])[0]}"

    listener "tcp" {
      purpose = "proxy"
      address = "0.0.0.0"
    }

    worker {
      auth_storage_path = "/etc/boundary-worker-data"
      public_addr = "file:///etc/public_dns"
      controller_generated_activation_token = "${boundary_worker.hcp_pki_instance_worker.controller_generated_activation_token}"

      tags {
        type = "public_instance"
        cloud = "aws"
        region = "${var.aws_region}"
        unique_name = "${var.unique_name}-vm"
        exec_type = "systemd"
      }
    }
    WORKER_CONFIG


  cloudinit_config_boundary_instance_worker = {
    write_files = [
      {
        content = file("${path.root}/files/gpg_pubkeys/hashicorp-archive-keyring.gpg")
        owner = "root:root"
        path = "/tmp/hashicorp-archive-keyring.gpg"
        permissions = "0644"
      },
      {
        content = <<-APT_NO_PROMPT_CONFIG
          Dpkg::Options {
            "--force-confdef";
            "--force-confold";
          }
          APT_NO_PROMPT_CONFIG
        owner = "root:root"
        path = "/etc/apt/apt.conf.d/no-update-prompt"
        permissions = "0644"
      },
      {
        content = local.boundary_worker_unit_dropin
        owner = "root:root"
        path = "/etc/systemd/system/boundary.service.d/10-execstart.conf"
        permissions = "0644"
      },
      {
        content = local.boundary_instance_worker_config
        owner = "root:root"
        path = "/etc/boundary.d/boundary-pki-worker-config.hcl"
        permissions = "0644"
      },
      {
        content = var.app_infra_ssh_privkey
        owner = "root:root"
        path = "/tmp/app_infra"
        permissions = "0600"
      }

    ]
    runcmd = [
      [ "systemctl", "disable", "--now", "unattended-upgrades.service", "apt-daily-upgrade.service", "apt-daily-upgrade.timer" ],
      [ "apt", "install", "-y", "software-properties-common" ],
      [ "apt-add-repository", "universe" ],
      [ "sh", "-c", "gpg --dearmor < /tmp/hashicorp-archive-keyring.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg" ],
      [ "sh", "-c", "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list" ],
      [ "sh", "-c", "cp /tmp/app_infra /home/ubuntu/.ssh && chown ubuntu:ubuntu /home/ubuntu/.ssh/app_infra" ],
      [ "apt", "update" ],
      [ "sh", "-c", "UCF_FORCE_CONFFOLD=true apt upgrade -y" ],
      [ "mkdir", "/etc/boundary-worker-data" ],
      [ "apt", "install", "-y", "bind9-dnsutils", "jq", "curl", "unzip", "docker-compose", "boundary-worker-hcp" ],
      [ "chown", "boundary:boundary", "/etc/boundary-worker-data" ],
      [ "sh", "-c", "curl -Ss https://checkip.amazonaws.com > /etc/public_ip" ],
      [ "sh", "-c", "host -t PTR $(curl -Ss https://checkip.amazonaws.com) | awk '{print substr($NF, 1, length($NF)-1)}' > /etc/public_dns" ],
      [ "systemctl", "disable", "--now", "boundary" ], 
      [ "systemctl", "enable", "--now", "apt-daily-upgrade.service", "apt-daily-upgrade.timer", "docker" ]
    ]
  }
}

resource "local_file" "boundary_instance_worker_config" {
  content = local.boundary_instance_worker_config
  filename = "${path.root}/gen_files/boundary_config/boundary-instance-worker-config.hcl"
}

data "cloudinit_config" "boundary_instance_worker" {
  gzip = false
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = yamlencode(local.cloudinit_config_boundary_instance_worker)
  }
}

resource "aws_instance" "boundary_worker" {
  associate_public_ip_address = true
  ami = var.aws_ami
  subnet_id = var.boundary_worker_subnet_id
  instance_type = var.boundary_worker_instance_type
  vpc_security_group_ids = [ var.aws_public_secgroup_id, aws_security_group.boundary_demo_worker_inet.id ]
  key_name = aws_key_pair.boundary_infra.key_name
  user_data_replace_on_change = true
  user_data_base64 = data.cloudinit_config.boundary_instance_worker.rendered
  tags = {
    Name = "${var.unique_name}-boundary-worker"
    app = "boundary"
    region = "${var.aws_region}"
  }
}