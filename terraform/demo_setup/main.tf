terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.48.0"
    }
    boundary = {
      source = "hashicorp/boundary"
      version = "1.1.3"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "boundary" {
  addr = var.boundary_cluster_admin_url
}

resource "boundary_worker" "hcp_pki_worker" {
  scope_id = "global"
  name = "boundary-worker-${var.unique_name}"
  worker_generated_auth_token = ""
}

locals {
  boundary_worker_unit_dropin = <<-WORKER_UNIT_DROPIN
    [Service]
    ProtectSystem=off
    ExecStart=
    ExecStart=/usr/bin/boundary-worker server -config=/etc/boundary.d/boundary-pki-worker-config.hcl
    WORKER_UNIT_DROPIN

  boundary_worker_config = <<-WORKER_CONFIG
    hcp_boundary_cluster_id = "${split(".", split("//", var.boundary_cluster_admin_url)[1])[0]}"

    listener "tcp" {
      purpose = "proxy"
      address = "0.0.0.0"
    }

    worker {
      auth_storage_path = "/etc/boundary-worker-data"
      public_addr = "file:///etc/public_dns"
      controller_generated_activation_token = "${boundary_worker.hcp_pki_worker.controller_generated_activation_token}"

      tags {
        type = "public_instance"
        cloud = "aws"
        region = "${var.aws_region}"
      }
    }
    WORKER_CONFIG

  cloudinit_config_boundary_worker = {
    write_files = [
      {
        content = file("${path.root}/gpg_pubkeys/hashicorp-archive-keyring.gpg")
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
        content = local.boundary_worker_config
        owner = "root:root"
        path = "/etc/boundary.d/boundary-pki-worker-config.hcl"
        permissions = "0644"
      }
    ]
    runcmd = [
      [ "systemctl", "disable", "--now", "unattended-upgrades.service", "apt-daily-upgrade.service", "apt-daily-upgrade.timer" ],
      [ "apt", "install", "-y", "software-properties-common" ],
      [ "apt-add-repository", "universe" ],
      [ "sh", "-c", "gpg --dearmor < /tmp/hashicorp-archive-keyring.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg" ],
      [ "sh", "-c", "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list" ],
      [ "apt", "update" ],
      [ "sh", "-c", "UCF_FORCE_CONFFOLD=true apt upgrade -y" ],
      [ "mkdir", "/etc/boundary-worker-data" ],
      [ "apt", "install", "-y", "bind9-dnsutils", "jq", "curl", "unzip", "docker-compose", "boundary-worker-hcp" ],
      [ "chown", "boundary:boundary", "/etc/boundary-worker-data" ],
      [ "sh", "-c", "curl -Ss https://checkip.amazonaws.com > /etc/public_ip" ],
      [ "sh", "-c", "host -t PTR $(curl -Ss https://checkip.amazonaws.com) | awk '{print $NF}' > /etc/public_dns" ],
      [ "systemctl", "disable", "--now", "boundary" ], 
      [ "systemctl", "enable", "--now", "apt-daily-upgrade.service", "apt-daily-upgrade.timer", "docker" ]
    ]
  }
}

resource "local_file" "boundary_worker_config" {
  content = local.boundary_worker_config
  filename = "/root/boundary_config/boundary-pki-worker-config.hcl"
}

data "cloudinit_config" "boundary_worker" {
  gzip = false
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = yamlencode(local.cloudinit_config_boundary_worker)
  }
}

resource "aws_instance" "boundary_worker" {
  associate_public_ip_address = true
  ami = var.aws_ami
  subnet_id = var.aws_boundary_worker_subnet_id
  instance_type = var.aws_boundary_worker_instance_type
  vpc_security_group_ids = [ var.aws_boundary_worker_secgroup_id ]
  key_name = var.aws_boundary_worker_ssh_keypair
  user_data_replace_on_change = true
  user_data_base64 = data.cloudinit_config.boundary_worker.rendered
  tags = {
    Name = "${var.unique_name}-boundary-worker"
  }
}
