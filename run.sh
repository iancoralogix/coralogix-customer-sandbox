#!/bin/bash

pushd terraform
terraform init
terraform apply --auto-approve

CORALOGIX_DOMAIN="${CORALOGIX_DOMAIN:-cx498.coralogix.com}"
CLUSTER_NAME="${CLUSTER_NAME:-otel-demo}"

if [ -n "${CORALOGIX_PRIVATE_KEY}" ]; then
  helm repo add coralogix https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
  helm repo update

  kubectl create secret generic coralogix-keys --from-literal=PRIVATE_KEY="${CORALOGIX_PRIVATE_KEY}"

  helm upgrade --install otel-coralogix-integration coralogix/otel-integration \
    --version=0.0.143 \
    --render-subchart-notes \
    --set global.domain="${CORALOGIX_DOMAIN}" \
    --set global.clusterName="${CLUSTER_NAME}"
else
  echo "Error: Run \'export CORALOGIX_PRIVATE_KEY=<your_private_key>\'"
  exit 1
fi
