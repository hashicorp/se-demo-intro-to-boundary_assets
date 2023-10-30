#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


set -euo pipefail

create_boundary=true
export HCP_CLIENT_ID=""
export HCP_CLIENT_SECRET=""
export BOUNDARY_TOKEN=""
export BOUNDARY_ADDR=""
export TF_BASE=""
export TF_VAR_unique_name=""
export TF_VAR_boundary_cluster_admin_url=""
export TF_VAR_create_postgres=true
export TF_VAR_create_k8s=true
export TF_VAR_admin_ip_additional=""

if [[ -f ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh ]]; then
  source ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
else
  touch ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
fi

if ! grep -E "^source ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh$" ~/.bashrc > /dev/null 2>&1; then
  echo "" >> ~/.bashrc
  echo "source ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh" >> ~/.bashrc
fi

if [[ -z "$TF_BASE" ]]; then
  export TF_BASE="$(realpath $(dirname $0)/../terraform)"
  echo "export TF_BASE=\"$TF_BASE\"" >> ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
fi

default_setup_info_text=\
"This track sets up an HCP Boundary cluster (or uses an existing one you 
provide credentials for) and an AWS VPC with a self-managed worker on an 
instance in a public subnet, along with a private subnet.  By default it 
also creates:

- an instance in the private subnet running a Postgres database
- a small Kubernetes cluster in the private subnet
  - with a network load-balancer in the public subnet exposing its 
    NodePort service ports but *not* its API

If you don't want either or both of those two resources to be created, 
enter \"No\" or \"N\" here and then answer the questions about each 
resource.  Otherwise enter \"Yes\" or \"Y\" or just hit Enter.  Note 
that if you decide not to create a certain resource, challenges dealing 
with that resource will not work."
target_k8s_info_text=\
"By default, this track creates a small Kubernetes cluster and installs 
a Boundary worker, Vault and Postgres in it.  This takes some additional 
time.  If you don't want that, enter \"No\" or \"N\" here.  Otherwise 
enter \"Yes\" or \"Y\" or just press Enter."
target_db_info_text=\
"By default, a Postgres database will be created running on its own 
instance.  If you don't want that, enter \"No\" or \"N\" here.  Otherwise 
enter \"Yes\" or \"Y\" or just press Enter."
boundary_cluster_info_text=\
"If you want a Boundary cluster created for you, you only need to enter 
HCP service principal credentials, and the Boundary cluster login 
questions will be skipped.  If you already have a Boundary cluster, 
answer 'no' when asked if you want it created to skip each of the HCP 
service principal questions and enter your Boundary cluster's URL, auth 
method ID, admin login name, and admin password where prompted."
admin_ip_info_text=\
"By default the public-facing resources created in this demo are access-
restricted to the external IP of the Instruqt workstation VM.  If you 
want to be able to access them from your local desktop, you can provide 
an external IP here to be added to the relevant security group.  If you 
don't need this, just hit Enter here.

To find your external IP, you can use a public service like 
https://icanhazip.com/ (or any other one you like).

Note that if you use a service hosted on your ISP, you may get an 
address in the 100.64/10 network range (100.64.0.0 - 100.127.255.255) - 
this is a carrier-grade NAT reserved range and IPs in it probably will 
not work here.  In that case, try a different IP identification service."
boundary_admin_url_info_text=\
"Your Boundary admin URL should be just the URL scheme (typically 
https:) followed by the hostname, and if necessary, the port.  It 
should not include portions of the URL following the port number."

boundary_cluster_info_success=false

echo "$boundary_cluster_info_text"
echo ""
while [ $boundary_cluster_info_success != "true" ]; do
  if [[ -z "$BOUNDARY_TOKEN" || -z "$TF_VAR_boundary_cluster_admin_url" ]]; then
    echo "This script can create the HCP Boundary cluster for you.  Note that "
    echo "if it already exists, this script will fail and you will need to "
    echo "re-run it with the login info for your existing cluster."
    read -p "Create Boundary cluster in HCP (default: yes)? " create_boundary_answer
    if ! echo $create_boundary_answer | grep -E -i '^n$|^no$' > /dev/null; then
      create_boundary=true
      if [ -z "$HCP_CLIENT_ID" ]; then
        read -p "HCP service principal client ID: " hcp_user_client_id
        HCP_CLIENT_ID="$hcp_user_client_id"
      fi
      if [ -z "$HCP_CLIENT_SECRET" ]; then
        read -sp "HCP service principal client secret (not shown): " hcp_user_client_secret
        HCP_CLIENT_SECRET="$hcp_user_client_secret"
      fi
      echo ""
    else
      create_boundary=false
    fi
    if [[ -z "$HCP_CLIENT_ID" || -z "$HCP_CLIENT_SECRET" || ! $create_boundary ]] ; then
      echo ""
      echo "User asked not to create HCP Boundary or no valid HCP service principal "
      echo "entered."
      echo "Enter info for an existing Boundary cluster."
      echo ""
      echo "$boundary_admin_url_info_text"
      echo ""
      read -p "Boundary admin URL: " TF_VAR_boundary_cluster_admin_url
      read -p "Boundary admin auth method ID (typically ampw_aaaaaaaaaa): " boundary_admin_auth_method
      read -p "Boundary admin login name: " boundary_admin_login
      read -sp "Boundary admin password: " boundary_admin_password
      echo ""
      if [[ -z "$TF_VAR_boundary_cluster_admin_url" || -z "$boundary_admin_auth_method" || -z "$boundary_admin_login" || -z "$boundary_admin_password" ]]; then
        echo ""
        echo "No valid HCP service principal or Boundary cluster admin info provided."
        echo "One set of credentials must be provided to set up this track."
        echo ""
      else
        boundary_cluster_info_success="true"
        create_boundary=false
        echo ""
        echo "Existing Boundary cluster will be used with the supplied admin "
        echo "credentials."
      fi
    else
      boundary_cluster_info_success="true"
      echo ""
      echo "Boundary cluster will be created with the supplied HCP credentials."
      echo ""
      if ! grep "export HCP_CLIENT_ID=\"$HCP_CLIENT_ID\"" ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh >/dev/null 2>&1; then
        echo "export HCP_CLIENT_ID=\"$HCP_CLIENT_ID\"" >> ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
      fi
      if ! grep "export HCP_CLIENT_SECRET=\"$HCP_CLIENT_SECRET\"" ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh >/dev/null 2>&1; then
        echo "export HCP_CLIENT_SECRET=\"$HCP_CLIENT_SECRET\"" >> ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
      fi
    fi
  else
    boundary_cluster_info_success="true"
    create_boundary=false
    echo ""
    echo "Existing Boundary cluster will be used with the existing token."
  fi
done

echo "$default_setup_info_text"
echo ""
read -p "Do you want to accept the default track setup (default: yes)? " defaults_answer
if echo $defaults_answer | grep -E -i '^n$|^no$' > /dev/null; then
  echo "$target_k8s_info_text"
  echo ""
  read -p "Do you want to create the Kubernetes cluster as described (default: yes)? " k8s_answer
  if echo $k8s_answer | grep -E -i '^n$|^no$' ; then
    TF_VAR_create_k8s=false
  fi
  echo "$target_db_info_text"
  echo ""
  read -p "Do you want to create the Postgres instance as described (default: yes)? " db_answer
  if echo $db_answer | grep -E -i '^n$|^no$' ; then
    TF_VAR_create_postgres=false
  fi
fi

if [[ -z "$TF_VAR_admin_ip_additional" ]]; then
  echo "$admin_ip_info_text"
  echo ""
  read -p "(optional) Additional IP to allow connections from (Enter to skip): " admin_ip_additional
  if [[ ! -z "$admin_ip_additional" ]] ; then
    if [[ ! "$admin_ip_additional" =~ /[0-9]{1,2}$ ]] ; then
      TF_VAR_admin_ip_additional="${admin_ip_additional}/32"
    else
      TF_VAR_admin_ip_additional="$admin_ip_additional"
    fi
  else
    TF_VAR_admin_ip_additional=""
  fi
else
  echo "Re-using previously-provided admin IP: $TF_VAR_admin_ip_additional"
fi

export TF_VAR_admin_ip_additional
if ! grep "export TF_VAR_admin_ip_additional=\"$TF_VAR_admin_ip_additional\"" ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh >/dev/null 2>&1; then
  echo "export TF_VAR_admin_ip_additional=\"$TF_VAR_admin_ip_additional\"" >> ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
fi

if [[ $TF_VAR_create_k8s || $TF_VAR_create_postgres || $create_boundary ]]; then
  echo ""
fi

if $create_boundary ; then
  echo "Will create the Boundary cluster."
fi

if $TF_VAR_create_k8s ; then
  echo "Will create the Kubernetes cluster."
fi

if $TF_VAR_create_postgres ; then
  echo "Will create the Postgres database instance."
fi

if [[ ! -z "$TF_VAR_admin_ip_additional" ]] ; then
  echo ""
  echo "Will allow access to this IP: $TF_VAR_admin_ip_additional"
fi

read -p "If everything above looks correct, press Enter to deploy the infrastructure." wait_for_ok

if $create_boundary ; then
  cd ${TF_BASE}/hcp
  if ! terraform init ; then
    echo "HCP Boundary cluster workspace init failed." >&2
    exit 1
  fi
  if ! terraform plan ; then
    echo "HCP Boundary cluster plan failed." >&2
    exit 1
  fi
  if ! terraform apply -auto-approve ; then
    echo "HCP Boundary cluster apply failed." >&2
    exit 1
  else
    hcp_output="$(terraform output -json)"
    echo "$hcp_output" > ${TF_BASE}/hcp_output.json
    TF_VAR_unique_name=$(jq -r .unique_name.value <(echo "$hcp_output"))
    TF_VAR_boundary_cluster_admin_url=$(jq -r .boundary_cluster_admin_url.value <(echo "$hcp_output"))
    export boundary_admin_auth_method=$(jq -r .boundary_cluster_admin_auth_method.value <(echo "$hcp_output"))
    export boundary_admin_login=$(jq -r .boundary_admin_login.value <(echo "$hcp_output"))
    boundary_admin_password=$(jq -r .boundary_admin_password.value <(echo "$hcp_output"))
  fi
else
  echo "Not creating a Boundary server because one already exists."
fi

echo "HCP Boundary admin URL: $TF_VAR_boundary_cluster_admin_url"

if ! grep "export TF_VAR_boundary_cluster_admin_url=\"$TF_VAR_boundary_cluster_admin_url\"" ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh >/dev/null 2>&1; then
  echo "export TF_VAR_boundary_cluster_admin_url=\"$TF_VAR_boundary_cluster_admin_url\"" >> ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
fi

BOUNDARY_ADDR="$TF_VAR_boundary_cluster_admin_url"

if ! grep "export BOUNDARY_ADDR=\"$TF_VAR_boundary_cluster_admin_url\"" ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh >/dev/null 2>&1; then
  echo "export BOUNDARY_ADDR=\"$TF_VAR_boundary_cluster_admin_url\"" >> ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
fi

if [[ -z "$BOUNDARY_TOKEN" ]]; then
  export BOUNDARY_PASSWORD=$boundary_admin_password
  BOUNDARY_TOKEN=$(boundary authenticate password -format json -auth-method-id $boundary_admin_auth_method -login-name $boundary_admin_login -password env://BOUNDARY_PASSWORD | jq -r '.item.attributes.token')
  echo "export BOUNDARY_TOKEN=\"$BOUNDARY_TOKEN\"" >> ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
else
  echo "Re-using existing Boundary auth token."
fi

cd ${TF_BASE}/infra_setup
if ! terraform init ; then
  echo "Infrastructure workspace init failed." >&2
  exit 1
fi
if ! terraform plan ; then
  echo "Infrastructure plan failed." >&2
  exit 1
fi
if ! terraform apply -auto-approve ; then
  echo "Infrastructure apply failed." >&2
  exit 1
else
  infra_output=$(terraform output -json)
  echo "$infra_output" > ${TF_BASE}/infra_output.json

  TF_VAR_unique_name=$(jq -r .unique_name.value <(echo "$infra_output"))
  if ! grep "export TF_VAR_unique_name=\"$TF_VAR_unique_name\"" ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh >/dev/null 2>&1; then
    echo "export TF_VAR_unique_name=\"$TF_VAR_unique_name\"" >> ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
  fi

  TF_VAR_aws_region=$(jq -r .aws_region.value <(echo "$infra_output"))
  if ! grep "export TF_VAR_aws_region=\"$TF_VAR_aws_region\"" ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh >/dev/null 2>&1; then
    echo "export TF_VAR_aws_region=\"$TF_VAR_aws_region\"" >> ~/.${INSTRUQT_PARTICIPANT_ID}-env.sh
  fi
fi
