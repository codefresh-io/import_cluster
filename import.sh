#!/bin/sh

set -e

# helper functions

msg() { echo "\033[0;32m INFO ---> $1\033[m"; }
err() { echo "\033[0;31m ERROR ---> $1\033[m" ; exit 1; }
check() { command -v "$1" >/dev/null 2>&1 || err "$1 utility is requiered!"; }

if [[ $# -eq 0 ]] ; then
    err "Need to provide a Codefresh API token and (optionally) desired Kubernetes cluster name. Get it here: https://g.codefresh.io/api/"
fi
cfapi_token=${1}

msg "This script will try to add current Kubernetes context into Codefresh as a new Kubernetes cluster"

# =---
# MAIN
# =---

check kubectl

# get CA key
ca=$(kubectl get secret -o go-template='{{index .data "ca.crt" }}' $(kubectl get sa default -o go-template="{{range .secrets}}{{.name}}{{end}}"))

# get secret token
service_account_token=$(kubectl get secret -o go-template='{{index .data "token" }}' $(kubectl get sa default -o go-template="{{range .secrets}}{{.name}}{{end}}"))

# get current context
current_context=$(kubectl config current-context)
msg "Kubernetes context: $current_context"

current_cluster=$(kubectl config view -o go-template="{{\$curr_context := \"$current_context\" }}{{range .contexts}}{{if eq .name \$curr_context}}{{.context.cluster}}{{end}}{{end}}")
msg "Kubernetes cluster: $current_cluster"

ip=$(kubectl config view -o go-template="{{\$cluster_context := \"$current_cluster\"}}{{range .clusters}}{{if eq .name \$cluster_context}}{{.cluster.server}}{{end}}{{end}}")
msg "Kubernetes cluster public IP: $ip"

# override CF_API url
cf_api=${CF_API:-https://g.codefresh.io/api/clusters/local/cluster}

# Use second (optional) argument as cluster name; if mnissing use current_cluster
cluster_name=${2:-$current_cluster}

# add new cluster with Codefresh API
wget -qO- \
  --header="Content-Type: application/json" \
  --header="x-access-token: $cfapi_token" \
  --post-data "{\"selector\": \"$cluster_name\", \"serviceAccountToken\": \"$service_account_token\", \"clientCa\": \"$ca\", \"host\": \"$ip\", \"type\": \"sat\"}" $cf_api
