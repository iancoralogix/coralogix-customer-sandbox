# Coralogix OTEL Demo Sandbox

## Overview
- Deploys an Amazon EKS cluster and installs the [OpenTelemetry demo application](https://github.com/open-telemetry/opentelemetry-helm-charts), which sends telemetry to Coralogix with this Helm chart [https://github.com/coralogix/telemetry-shippers/tree/master/otel-integration/k8s-helm](https://github.com/coralogix/telemetry-shippers/tree/master/otel-integration/k8s-helm).
- Includes scripts to provision and tear down infrastructure, plus a “frontend clicker” deployment for RUM data generation.

## Prerequisites
- AWS CLI configured with enough privileges to create EKS resources
- Terraform
- Helm for chart installations
- kubectl to interact with the EKS cluster
- Environment variables for Coralogix:
  - **CORALOGIX_PRIVATE_KEY** (Coralogix private key)
  - **CORALOGIX_RUM_KEY** (Coralogix RUM key)
  - (Optional) **CORALOGIX_DOMAIN** (defaults to `cx498.coralogix.com`)
    
## Deployment Steps
1. Ensure `CORALOGIX_PRIVATE_KEY` and `CORALOGIX_RUM_KEY` are exported in your shell.
2. Run `./run.sh`
3. Wait for the script to finish. It will display a LoadBalancer URL for the demo’s frontend.

## Verification
- After the script is complete, open the printed URL in a browser.
- The OpenTelemetry demo UI should load, and data should flow into Coralogix.

## Teardown
- To remove all resources, run `./delete.sh`
- This deletes the Kubernetes services and destroys the Terraform-managed EKS infrastructure.

## Files
- **run.sh**
  - Initializes and applies Terraform in the `terraform` folder to create a new EKS cluster named `otel-coralogix-demo-eks`.
  - Updates local kubeconfig to point to the new cluster.
  - Creates Kubernetes secrets for Coralogix keys (if not already present).
  - Installs the Coralogix OpenTelemetry integration via Helm.
  - Exposes a collector service (`rum-otel-collection`) as a LoadBalancer and retrieves its endpoint.
  - Installs the OpenTelemetry Demo (microservices) with custom values from `values.yaml`, injecting the collector endpoint for RUM data.
  - Deploys `frontendclicker-deployment.yaml` for generating RUM traffic.
  - Exposes the `frontendproxy` service and prints the external load balancer URL.

- **delete.sh**
  - Deletes the `frontendproxy` and `rum-otel-collection` services from Kubernetes.
  - Runs `terraform destroy` in the `terraform` folder to remove all AWS resources.

- **frontendclicker-deployment.yaml**
  - Kubernetes Deployment and Service for a container that simulates user clicks on the demo’s frontend, generating RUM traffic.

- **values.yaml**
  - Helm values for the OpenTelemetry Demo chart.
  - Configures microservices, Jaeger, Prometheus, Grafana, and other components.
  - Sets environment variables, resource limits, and references to Coralogix collectors.

