#!/bin/bash

set -eiou pipefail

pushd terraform
terraform init
terraform apply --auto-approve
popd

CORALOGIX_DOMAIN="${CORALOGIX_DOMAIN:-cx498.coralogix.com}"

#TODO this is hardcoded in Terraform for now, and Terraform adds "-eks". Don't touch.
CLUSTER_NAME="otel-coralogix-demo"

aws eks update-kubeconfig --name "${CLUSTER_NAME}-eks"

if [ -n "${CORALOGIX_PRIVATE_KEY}" ] && [ -n "${CORALOGIX_RUM_KEY}" ]; then
  helm repo add coralogix https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
  helm repo update

  if ! kubectl get secret coralogix-keys >/dev/null 2>&1; then
    kubectl create secret generic coralogix-keys --from-literal=PRIVATE_KEY="${CORALOGIX_PRIVATE_KEY}"
  fi

  if ! kubectl get secret coralogix-rum-key >/dev/null 2>&1; then
    kubectl create secret generic coralogix-rum-key --from-literal=RUM_KEY="${CORALOGIX_RUM_KEY}"
  fi

  echo "Deploying OpenTelemetry contrib collector and emit data to Coralogix"
  helm upgrade --install otel-coralogix-integration coralogix/otel-integration \
    --version=0.0.143 \
    --render-subchart-notes \
    --set global.domain="${CORALOGIX_DOMAIN}" \
    --set global.clusterName="${CLUSTER_NAME}-eks" \
    --set opentelemetry-agent.fullnameOverride="my-otel-demo-otelcol" \
    --set opentelemetry-agent.mode="deployment"

  echo "Creating OTel collector load balancer for frontend traces"
  if ! kubectl get svc rum-otel-collection >/dev/null 2>&1; then
    kubectl expose deployment coralogix-opentelemetry-collector \
      --port=8080 \
      --target-port=4318 \
      --name=rum-otel-collection \
      --type=LoadBalancer
  fi

  until ! kubectl get svc rum-otel-collection | grep -q pending; do
    sleep 1
  done

  OTEL_LOADBALANCER_ENDPOINT="http://$(kubectl get svc rum-otel-collection -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):8080/v1/traces"

  if [ -z "${OTEL_LOADBALANCER_ENDPOINT}" ]; then
    echo "Error: OTEL_LOADBALANCER_ENDPOINT is not set."
    exit 1
  fi

  # helm get values my-otel-demo -o yaml | grep -A2 PUBLIC_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
  cat <<EOF > tmp.yaml
components:
  loadgenerator:
    enabled: true

  frontend:
    envOverrides:
      - name: PUBLIC_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
        value: "${OTEL_LOADBALANCER_ENDPOINT}"
EOF

  echo "Deploying OpenTelemetry Astronomy Shop demo"
  # Set opentelemetry-collector.enabled to false and use the contrib collector provided by Cx Helm chart.
  helm upgrade --install my-otel-demo open-telemetry/opentelemetry-demo \
    --set opentelemetry-collector.enabled=false \
    --set jaeger.enabled=false \
    --set prometheus.enabled=false \
    --set grafana.enabled=false \
    --set opensearch.enabled=false \
    -f values.yaml \
    -f tmp.yaml

  rm tmp.yaml

  echo "Deploying frontend clicker for to generate RUM data"
  kubectl apply -f frontendclicker-deployment.yaml

  echo "Waiting for frontend proxy pod to be ready"
  if kubectl get pod -l app.kubernetes.io/name=my-otel-demo-frontendproxy --no-headers 2>/dev/null | grep -q .; then
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=my-otel-demo-frontendproxy --timeout=300s
  else
    echo "No frontend proxy pods found. Skipping wait."
  fi

  echo "Creating LoadBalancer for frontend proxy"
  if ! kubectl get svc frontendproxy >/dev/null 2>&1; then
    kubectl expose deployment my-otel-demo-frontendproxy \
      --port=8080 --target-port=8080 \
      --name=frontendproxy --type=LoadBalancer
  fi

  until kubectl get svc frontendproxy -o jsonpath='{.status.loadBalancer.ingress}' | grep -q -v "pending"; do
    echo "Waiting for frontend proxy load balancer to be ready"
    sleep 2
  done

  URL=$(kubectl get svc frontendproxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  EXPOSE="http://${URL}:8080"

  echo "---------------------------------------------------"
  echo "OpenTelemetry Demo is now available at:"
  echo "${EXPOSE}"
  echo "---------------------------------------------------"

else
  echo "Error: Run \'export CORALOGIX_PRIVATE_KEY=<your_private_key>\'"
  echo "Error: Run \'export CORALOGIX_RUM_KEY=<your_rum_key>\'"
  echo "Error: Both CORALOGIX_PRIVATE_KEY and CORALOGIX_RUM_KEY must be set."
  exit 1
fi
