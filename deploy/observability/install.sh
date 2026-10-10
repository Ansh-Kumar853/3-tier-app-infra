#!/usr/bin/env bash
set -euo pipefail
NAMESPACE="${NAMESPACE:-observability}"
: "${ELASTIC_CHART_VERSION:?Set ELASTIC_CHART_VERSION to a reviewed, compatible chart version}"
helm repo add elastic https://helm.elastic.co
helm repo update
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install elasticsearch elastic/elasticsearch -n "$NAMESPACE" --version "$ELASTIC_CHART_VERSION" -f "$(dirname "$0")/elasticsearch-values.yaml" --wait --timeout 20m
helm upgrade --install kibana elastic/kibana -n "$NAMESPACE" --version "$ELASTIC_CHART_VERSION" -f "$(dirname "$0")/kibana-values.yaml" --wait --timeout 10m
helm upgrade --install filebeat elastic/filebeat -n "$NAMESPACE" --version "$ELASTIC_CHART_VERSION" -f "$(dirname "$0")/filebeat-values.yaml" --wait --timeout 10m
kubectl -n "$NAMESPACE" get pods
