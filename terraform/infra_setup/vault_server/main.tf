/*
This module is suitable ONLY for demo use of Vault.  DO NOT use this to provision a Vault server in any real-world context as it takes shortcuts for ease of demonstration that make it unsuitable for deployment elsewhere.
*/

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

    disable_mlock = false

    storage "file" {
      path = "/opt/vault/data"
    }

    listener "tcp" {
      address = "0.0.0.0:8200"
      tls_disable = 1
    }
    VAULT_CONFIG
  vault_dropin = <<-VAULT_DROPIN
    [Unit]
    ConditionFileNotEmpty=/etc/vault.d/vault-notls.hcl

    [Service]
    ExecStart=
    ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault-notls.hcl
    VAULT_DROPIN
  vault_init = <<-VAULT_INIT
    #!/bin/bash

    export VAULT_ADDR="http://localhost:8200"

    VAULT_INIT_OUTPUT=$(vault operator init -key-shares 1 -key-threshold 1 -format json)

    vault operator unseal $(echo $VAULT_INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')

    echo "VAULT_ADDR=http://127.0.0.1:8200" > /etc/vault.d/vault.env

    echo "VAULT_TOKEN=$(echo $VAULT_INIT_OUTPUT | jq '.root_token')" >> /etc/vault.d/vault.env
    VAULT_INIT
  vault_pg_auth = <<-VAULT_PG_AUTH
    PG_USER=${var.pg_vault_user}
    PG_PASSWORD=${var.pg_vault_password}
    PG_HOST=${var.postgres_server}
    VAULT_PG_AUTH
  vault_init_postgres = <<-VAULT_INIT_POSTGRES
    #!/bin/bash

    if [[ -z "$PG_HOST" ]]; then
      echo "Not setting up Postgres dynamic secrets in Vault because \
      Postgres wasn't provisioned."
      exit 0
    fi

    vault secrets enable -path postgres database

    vault write postgres/config/product-api \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@$PG_HOST/products?sslmode=disable" \
    allowed_roles=product-api-readonly,product-api-admin \
    username=$PG_USER \
    password=$PG_PASSWORD

    vault write -force postgres/rotate-root/product-api

    vault write postgres/roles/product-api-readonly \
    db_name=product-api \
    creation_statements=@/opt/vault/product_api_db_readonly_role.sql \
    default_ttl=5m max_ttl=1h

    vault write postgres/roles/product-api-admin \
    db_name=product-api \
    creation_statements=@/opt/vault/product_api_db_admin_role.sql \
    default_ttl=1h max_ttl=6h
    VAULT_INIT_POSTGRES
  vault_init_unit = <<-VAULT_INIT_UNIT
    [Unit]
    Description=A oneshot unit for initial Vault config
    Requires=vault.service
    After=vault.service

    [Service]
    EnvironmentFile=/etc/vault.d/vault.env
    User=vault
    Group=vault
    Type=oneshot
    Restart=on-failure
    RemainAfterExit=true
    ExecStart=/usr/local/bin/vault-init.sh

    [Install]
    WantedBy=multi-user.target
    VAULT_INIT_UNIT
  vault_init_postgres_unit = <<-VAULT_INIT_POSTGRES_UNIT
    [Unit]
    Description=A oneshot unit for Vault Postgres dynamic secret config
    Requires=vault-init.service
    After=vault-init.service

    [Service]
    EnvironmentFile=/etc/vault.d/vault.env
    EnvironmentFile=-/etc/vault.d/postgres.env
    User=vault
    Group=vault
    Type=oneshot
    Restart=on-failure
    RemainAfterExit=true
    ExecStart=/usr/local/bin/vault-init-postgres.sh

    [Install]
    WantedBy=multi-user.target
    VAULT_INIT_POSTGRES_UNIT
  cloudinit_config_vault_server = {
    write_files = [
      {
        content = file("${path.root}/files/gpg_pubkeys/hashicorp-archive-keyring.gpg")
        owner = "root:root"
        path = "/tmp/hashicorp-archive-keyring.gpg"
        permissions = "0644"
      },
      {
        content = file("${path.module}/files/boundary_token_policy.hcl")
        owner = "root:root"
        path = "/opt/vault/boundary_token_policy.hcl"
        permissions = "0644"
      },
      {
        content = file("${path.module}/files/boundary_database_secret_policy.hcl")
        owner = "root:root"
        path = "/opt/vault/boundary_database_secret_policy.hcl"
        permissions = "0644"
      },
      {
        content = file("${path.module}/files/product_api_db_admin_role.sql")
        owner = "root:root"
        path = "/opt/vault/product_api_db_admin_role.sql"
        permissions = "0644"
      },
      {
        content = file("${path.module}/files/product_api_db_readonly_role.sql")
        owner = "root:root"
        path = "/opt/vault/product_api_db_readonly_role.sql"
        permissions = "0644"
      },
      {
        content = local.vault_server_config
        owner = "root:root"
        path = "/etc/vault.d/vault-notls.hcl"
        permissions = "0400"
      },
      {
        content = local.vault_dropin
        owner = "root:root"
        path = "/etc/systemd/system/vault.service.d/10-notls-config.conf"
        permissions = "0644"
      },
      {
        content = local.vault_init
        owner = "root:root"
        path = "/usr/local/bin/vault-init.sh"
        permissions = "0744"
      },
      {
        content = local.vault_pg_auth
        owner = "root:root"
        path = "/etc/vault.d/postgres.env"
        permissions = "0644"
      },
      {
        content = local.vault_init_postgres
        owner = "root:root"
        path = "/usr/local/bin/vault-init-postgres.sh"
        permissions = "0744"
      },
      {
        content = local.vault_init_unit
        owner = "root:root"
        path = "/etc/systemd/system/vault-init.service"
        permissions = "0644"
      },
      {
        content = local.vault_init_postgres_unit
        owner = "root:root"
        path = "/etc/systemd/system/vault-init-postgres.service"
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
      [ "sh", "-c", "chown vault:vault /usr/local/bin/vault-*.sh" ],
      [ "systemctl", "enable", "--now", "apt-daily-upgrade.service", "apt-daily-upgrade.timer", "docker", "vault", "vault-init", "vault-init-postgres" ],
      [ "sh", "-c", "echo \"\" >> /root/.bash_profile"],
      [ "sh", "-c", "echo \"source /etc/vault.d/vault.env\" >> /root/.bash_profile"],
      [ "sh", "-c", "echo \"export VAULT_ADDR VAULT_TOKEN\" >> /root/.bash_profile"]
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
