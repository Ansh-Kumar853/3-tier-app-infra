#!/usr/bin/env bash
set -euo pipefail
NAMESPACE="${NAMESPACE:-observability}"
helm repo add elastic https://helm.elastic.co
helm repo update
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install elasticsearch elastic/elasticsearch -n "$NAMESPACE" -f "$(dirname "$0")/elasticsearch-values.yaml" --wait --timeout 20m
helm upgrade --install kibana elastic/kibana -n "$NAMESPACE" -f "$(dirname "$0")/kibana-values.yaml" --wait --timeout 10m
helm upgrade --install filebeat elastic/filebeat -n "$NAMESPACE" -f "$(dirname "$0")/filebeat-values.yaml" --wait --timeout 10m
kubectl -n "$NAMESPACE" get pods
