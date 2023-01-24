terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  cloudinit_config_k8s_cluster = {
    write_files = [
      {
        content = file("${path.root}/gpg_pubkeys/hashicorp-archive-keyring.gpg")
        owner = "root:root"
        path = "/tmp/hashicorp-archive-keyring.gpg"
        permissions = "0644"
      },
      {
        content = file("${path.root}/gpg_pubkeys/kubernetes-archive-keyring.gpg")
        owner = "root:root"
        path = "/tmp/kubernetes-archive-keyring.gpg"
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
      [ "sh", "-c", "gpg --dearmor < /tmp/kubernetes-archive-keyring.gpg > /usr/share/keyrings/kubernetes-archive-keyring.gpg" ],
      [ "sh", "-c", "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list" ],
      [ "sh", "-c", "echo \"deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main\" > /etc/apt/sources.list.d/kubernetes.list" ],
      [ "apt", "update" ],
      [ "sh", "-c", "UCF_FORCE_CONFFOLD=true apt upgrade -y" ],
      [ "apt", "install", "-y", "bind9-dnsutils", "jq", "curl", "unzip", "docker-compose", "kubectl", "acl" ],
      [ "systemctl", "enable", "--now", "apt-daily-upgrade.service", "apt-daily-upgrade.timer", "docker" ],
      [ "sh", "-c", "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\"server\" sh -" ],
      [ "setfacl", "-m", "u:ubuntu:r", "/etc/rancher/k3s/k3s.yaml" ]
    ]
  }
}

data "cloudinit_config" "k8s_cluster" {
  count = var.create_k8s == true ? 1 : 0
  gzip = false
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = yamlencode(local.cloudinit_config_k8s_cluster)
  }
}

resource "aws_instance" "k8s_cluster" {
  count = var.create_k8s == true ? 1 : 0
  associate_public_ip_address = false
  ami = var.aws_ami
  subnet_id = var.k8s_subnet_id
  instance_type = var.k8s_instance_type
  vpc_security_group_ids = [ var.k8s_secgroup_id ]
  key_name = var.k8s_ssh_keypair
  user_data_replace_on_change = true
  user_data_base64 = data.cloudinit_config.k8s_cluster[0].rendered
  tags = {
    Name = "${var.unique_name}-k8s-cluster"
  }
}

resource "aws_lb" "k8s_worker" {
  name = var.unique_name
  load_balancer_type = "network"
  subnets = [ var.k8s_boundary_worker_lb_subnet_id ]
}

/*
resource "aws_lb_target_group" "k8s_api" {
  
}

resource "aws_lb_target_group_attachment" "k8s_api_lb_targets" {
  
}

resource "aws_lb_listener" "k8s_api" {
  
}

resource "aws_lb_listener_rule" {

}
*/
