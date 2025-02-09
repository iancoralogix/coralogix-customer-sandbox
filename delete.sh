#!/bin/bash

kubectl delete svc frontendproxy
kubectl delete svc rum-otel-collection

cd terraform
terraform init
terraform destroy
