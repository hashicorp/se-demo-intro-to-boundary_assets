terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  vault_server_config = <<-VAULT_CONFIG
    ui = true

    mlock = true

    storage "file" {
      path = "/opt/vault/data"
    }

    listener "tcp" {
      address = "0.0.0.0:8200"
      tls_disable = 1
    }
    VAULT_CONFIG
  cloudinit_config_vault_server = {
    write_files = [
      {
        content = file("${path.root}/gpg_pubkeys/hashicorp-archive-keyring.gpg")
        owner = "root:root"
        path = "/tmp/hashicorp-archive-keyring.gpg"
        permissions = "0644"
      },
      {
        content = file("${path.module}/files/boundary_token_policy.hcl")
        owner = "vault:vault"
        path = "/opt/vault/boundary_token_policy.hcl"
        permissions = "0644"
      },
      {
        content = file("${path.module}/files/boundary_database_secret_policy.hcl")
        owner = "vault:vault"
        path = "/opt/vault/boundary_database_secret_policy.hcl"
        permissions = "0644"
      },
      {
        content = file("${path.module}/files/product_api_db_admin_role.sql")
        owner = "vault:vault"
        path = "/opt/vault/product_api_db_admin_role.sql"
        permissions = "0644"
      },
      {
        content = file("${path.module}/files/product_api_db_user_role.sql")
        owner = "vault:vault"
        path = "/opt/vault/product_api_db_user_role.sql"
        permissions = "0644"
      },
      {
        content = local.vault_server_config
        owner = "root:root"
        path = "/etc/vault.d/vault-notls.hcl"
        permissions = "0400"
      },
      {
        content = <<-VAULT_DROPIN
          [Unit]
          ConditionFileNotEmpty=/etc/vault.d/vault-notls.hcl

          [Service]
          ExecStart=
          ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault-notls.hcl
          VAULT_DROPIN
        owner = "root:root"
        path = "/etc/systemd/system/vault.service.d/10-notls-config.conf"
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
      [ "apt", "install", "-y", "bind9-dnsutils", "jq", "curl", "unzip", "docker-compose", "vault" ],
      [ "chown", "vault:vault", "/etc/vault.d/vault-notls.hcl" ],
      [ "systemctl", "enable", "--now", "apt-daily-upgrade.service", "apt-daily-upgrade.timer", "docker", "vault" ],
      [ "sh", "-c", "VAULT_ADDR=\"http://localhost:8200\" vault operator init -key-shares 1 -key-threshold 1 -format json > /root/vault-init-output.json" ],
      [ "sh", "-c", "VAULT_ADDR=\"http://localhost:8200\" vault operator unseal $(jq -r .unseal_keys_b64[0] < /root/vault-init-output.json)" ],
      [ "sh", "-c", "echo \"export VAULT_ADDR=http://127.0.0.1:8200\" >> /root/.bash_profile; echo \"export VAULT_TOKEN=$(jq '.root_token' < /root/vault-init-output.json)\" >> /root/.bash_profile" ]
    ]
  }
}

data "cloudinit_config" "vault_server" {
  gzip = false
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = yamlencode(local.cloudinit_config_vault_server)
  }
}

resource "aws_instance" "vault_server" {
  associate_public_ip_address = false
  ami = var.aws_ami
  subnet_id = var.vault_subnet_id
  instance_type = var.vault_instance_type
  vpc_security_group_ids = [ var.vault_secgroup_id ]
  key_name = var.vault_ssh_keypair
  user_data_replace_on_change = true
  user_data_base64 = data.cloudinit_config.vault_server.rendered
  tags = {
    Name = "${var.unique_name}-vault-server"
    app = "vault"
    region = "${var.aws_region}"
  }
}
