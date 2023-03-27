terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  cloudinit_config_postgres = {
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
      [ "apt", "install", "-y", "bind9-dnsutils", "jq", "curl", "unzip", "docker-compose" ], 
      [ "systemctl", "enable", "--now", "apt-daily-upgrade.service", "apt-daily-upgrade.timer", "docker" ],
      [ "docker", "run", "-d", "--restart", "unless-stopped", "-p", "5432:5432", "--name", "product-api-db", "-e", "POSTGRES_USER=${var.pg_admin_user}", "-e", "POSTGRES_PASSWORD=${random_pet.admin_password.id}", "-e", "POSTGRES_DB=products", "hashicorpdemoapp/product-api-db:v0.0.22" ],
      [ "sleep", "10" ],
      [ "docker", "exec", "product-api-db", "bash", "-c", "psql -U ${var.pg_admin_user} -d products -c \"CREATE ROLE ${var.pg_vault_user} WITH SUPERUSER LOGIN PASSWORD '${random_pet.vault_password.id}'; REVOKE CREATE ON SCHEMA public FROM PUBLIC;\"" ]
    ]
  }
}

resource "random_pet" "admin_password" {
  length = 4
}

resource "random_pet" "vault_password" {
  length = 4
}

data "cloudinit_config" "postgres" {
  gzip = false
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = yamlencode(local.cloudinit_config_postgres)
  }
}

resource "aws_instance" "postgres" {
  count = var.create_postgres == true ? 1 : 0
  associate_public_ip_address = false
  ami = var.aws_ami
  subnet_id = var.pg_subnet_id
  instance_type = var.pg_instance_type
  vpc_security_group_ids = [ var.pg_secgroup_id ]
  key_name = var.pg_ssh_keypair
  user_data_replace_on_change = true
  user_data_base64 = data.cloudinit_config.postgres.rendered
  tags = {
    Name = "${var.unique_name}-postgres"
    app = "postgres"
    region = "${var.aws_region}"
  }
}
