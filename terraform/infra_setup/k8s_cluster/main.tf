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

resource "random_pet" "postgres_k8s_admin_password" {
  length = 4
}

locals {
  traefik_helm_config = {
    ports = {
      web = {
        nodePort = 30080
      }
      websecure = {
        nodePort = 30443
      }
    }
  }

  k3s_traefik_helm_config = {
    apiVersion = "helm.cattle.io/v1"
    kind = "HelmChartConfig"
    metadata = {
      name = "traefik"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = yamlencode(local.traefik_helm_config)
    }
  }

  boundary_k8s_worker_config = <<-WORKER_CONFIG
    listener "tcp" {
      purpose = "proxy"
      address = "0.0.0.0"
    }

    worker {
      initial_upstreams = [ "${var.boundary_instance_worker_addr}" ]
      auth_storage_path = "/etc/boundary-worker-data"
      public_addr = "file:///etc/boundary-worker-network/boundary_worker_nodeport"
      controller_generated_activation_token = "${coalesce(boundary_worker.hcp_pki_k8s_worker[0].controller_generated_activation_token,"null")}"

      tags {
        type = "k8s_deployment"
        cloud = "aws"
        region = "${var.aws_region}"
        unique_name = "${var.unique_name}-k8s"
        exec_type = "k8s"
      }
    }
    WORKER_CONFIG

  cloudinit_config_k8s_cluster = {
    write_files = [
      {
        content = yamlencode(local.boundary_k8s_worker_configmap)
        owner = "root:root"
        path = "/tmp/k8s_manifests/boundary_worker/boundary_k8s_worker_configmap.yaml"
        permissions = "0644"
      },
      {
        content = yamlencode(local.boundary_k8s_worker_auth_storage)
        owner = "root:root"
        path = "/tmp/k8s_manifests/boundary_worker/boundary_k8s_worker_auth_pvc.yaml"
        permissions = "0644"
      },
      {
        content = yamlencode(local.boundary_k8s_worker_deployment)
        owner = "root:root"
        path = "/tmp/k8s_manifests/boundary_worker/boundary_k8s_worker_deployment.yaml"
        permissions = "0644"
      },
      {
        content = yamlencode(local.boundary_k8s_worker_service)
        owner = "root:root"
        path = "/tmp/k8s_manifests/boundary_worker/boundary_k8s_worker_svc.yaml"
        permissions = "0644"
      },
      {
        content = yamlencode(local.k3s_traefik_helm_config)
        owner = "root:root"
        path = "/var/lib/rancher/k3s/server/manifests/traefik-config.yaml"
        permissions = "0644"
      },
      {
        content = file("${path.root}/files/gpg_pubkeys/hashicorp-archive-keyring.gpg")
        owner = "root:root"
        path = "/tmp/hashicorp-archive-keyring.gpg"
        permissions = "0644"
      },
      {
        content = file("${path.root}/files/gpg_pubkeys/kubernetes-archive-keyring.gpg")
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
      [ "sh", "-c", "curl -Ss http://169.254.169.254/1.0/meta-data/local-ipv4 > /etc/private_ip" ],
      [ "sh", "-c", "host -t PTR $(cat /etc/private_ip) | awk '{print substr($NF, 1, length($NF)-1)}' > /etc/private_dns" ],
      [ "sh", "-c", "sed -e 's/$/:30922/' < /etc/private_dns > /etc/boundary_worker_nodeport" ],
      [ "sh", "-c", "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\"server\" sh -" ],
      [ "setfacl", "-m", "u:ubuntu:r", "/etc/rancher/k3s/k3s.yaml" ],
      [ "sh", "-c", "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"],
      [ "helm", "repo", "add", "bitnami", "https://charts.bitnami.com/bitnami" ],
      [ "sh", "-c", "KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm install k8s-postgres --set auth.postgresPassword=${random_pet.postgres_k8s_admin_password.id} bitnami/postgresql" ],
      [ "sh", "-c", "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl create configmap boundary-worker-nodeport --from-file /etc/boundary_worker_nodeport"]
    ]
  }
  
  boundary_k8s_worker_configmap = {
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "boundary-worker-config"
    }
    data = {
      boundary-worker-config = local.boundary_k8s_worker_config
    }
  }
  
  boundary_k8s_worker_auth_storage = {
    apiVersion = "v1"
    kind = "PersistentVolumeClaim"
    metadata = {
      name = "boundary-worker-auth"
    }
    spec = {
      accessModes = [ "ReadWriteOnce" ]
      storageClassName = "local-path"
      resources = {
        requests = {
          storage = "64Mi"
        }
      }
    }
  }
  
  boundary_k8s_worker_deployment = {
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
      name = "boundary-worker-${var.unique_name}"
      labels = {
        app = "boundary"
        component = "worker"
        env = "k3s"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app = "boundary"
          component = "worker"
          env = "k3s"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "boundary"
            component = "worker"
            env = "k3s"
          }
        }
        spec = {
          containers = [
            {
              name = "boundary-worker"
              image = "hashicorp/boundary-worker-hcp"
              command = [ "boundary-worker" ]
              args = [ "server", "-config", "/etc/boundary/boundary-worker-config" ]
              securityContext = {
                capabilities = {
                  add = [ "IPC_LOCK" ]
                }
              }
              ports = [
                {
                  containerPort = 9202
                }
              ]
              volumeMounts = [
                {
                  mountPath = "/etc/boundary"
                  name = "boundary-config"
                },
                {
                  mountPath = "/etc/boundary-worker-data"
                  name = "boundary-worker-auth"
                },
                {
                  mountPath = "/etc/boundary-worker-network"
                  name = "boundary-worker-nodeport"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "boundary-config"
              configMap = {
                name = "boundary-worker-config"
              }
            },
            {
              name = "boundary-worker-nodeport"
              configMap = {
                name = "boundary-worker-nodeport"
              }
            },
            {
              name = "boundary-worker-auth"
              persistentVolumeClaim = {
                claimName = "boundary-worker-auth"
              }
            }
          ]
        }
      }
    }
  }

  boundary_k8s_worker_service = {
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "boundary-k3s-worker"
    }
    spec = {
      type = "NodePort"
      selector = {
        app = "boundary"
        component = "worker"
        env = "k3s"
      }
      ports = [
        {
          port = 9202
          nodePort = 30922
        }
      ]
    }
  }
}

resource "boundary_worker" "hcp_pki_k8s_worker" {
  count = var.create_k8s == true ? 1 : 0
  scope_id = "global"
  name = "${var.unique_name}-k8s"
  worker_generated_auth_token = ""
}

resource "local_file" "boundary_k8s_worker_config" {
  content = local.boundary_k8s_worker_config
  filename = "${path.root}/gen_files/boundary_config/boundary-k8s-worker-config.hcl"
}

data "cloudinit_config" "k8s_cluster" {
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
  user_data_base64 = data.cloudinit_config.k8s_cluster.rendered
  tags = {
    Name = "${var.unique_name}-k8s-cluster"
    app = "kubernetes"
    region = "${var.aws_region}"
  }
}