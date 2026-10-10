# Elastic Stack on EKS

This folder provides starter values for Elasticsearch, Kibana, and Filebeat using Elastic's official Helm repository. Review the chart versions and values against the Elastic compatibility matrix before use. For production, prefer a managed Elasticsearch service or Elastic Operator and complete a capacity/security review.

## Install

Prerequisites: a healthy EKS cluster, Helm, storage class for encrypted persistent volumes, and enough memory/CPU. Elasticsearch is resource-intensive. Never expose Elasticsearch directly to the public internet.

```bash
helm repo add elastic https://helm.elastic.co
helm repo update
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install elasticsearch elastic/elasticsearch --namespace observability -f deploy/observability/elasticsearch-values.yaml --wait --timeout 15m
helm upgrade --install kibana elastic/kibana --namespace observability -f deploy/observability/kibana-values.yaml --wait --timeout 10m
helm upgrade --install filebeat elastic/filebeat --namespace observability -f deploy/observability/filebeat-values.yaml --wait --timeout 10m
```

Retrieve credentials using the chart's documented secret names and the exact version's instructions. Do not put credentials in Git. Port-forward Kibana for private access: `kubectl -n observability port-forward svc/kibana-kibana 5601:5601`.

## Production checklist

- Use version-matched charts, TLS and authentication; keep Elasticsearch/Kibana services internal.
- Use encrypted persistent volumes, snapshots to a separate account/bucket, tested restores, ILM retention and disk-watermark alerts.
- Set realistic resource requests/limits and storage capacity from expected ingest/retention. Multi-node Elasticsearch needs sufficient memory and disk.
- Restrict Filebeat permissions to required node log paths; review security contexts and Kubernetes API permissions.
- Configure Kibana access via VPN/SSO or an authenticated internal ingress. Do not expose Elasticsearch on an internet-facing ALB.
- This is an operational starter, not a guarantee of production suitability.
