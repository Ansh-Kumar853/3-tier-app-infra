# Elastic Stack on EKS

This folder provides starter values for Elasticsearch, Kibana, and Filebeat using Elastic's official Helm repository. Review the chart version and values against the Elastic compatibility matrix before use. For production, prefer a managed Elasticsearch service or Elastic Operator and complete a capacity/security review.

## Install

Prerequisites: a healthy EKS cluster, Helm, a storage class for encrypted persistent volumes, and enough memory/CPU. Elasticsearch is resource-intensive. Never expose Elasticsearch directly to the public internet.

Choose a reviewed, mutually compatible Elastic Helm chart version and pass it explicitly. Do not install an unreviewed latest version.

```bash
export ELASTIC_CHART_VERSION="REPLACE_WITH_REVIEWED_CHART_VERSION"
bash deploy/observability/install.sh
```

Retrieve credentials from the chart-generated Kubernetes Secret using the exact version's documentation. Do not put credentials in Git. Port-forward Kibana for private access: `kubectl -n observability port-forward svc/kibana-kibana 5601:5601`.

## Production checklist

- Use version-matched charts, TLS and authentication; keep Elasticsearch/Kibana services internal.
- Use encrypted persistent volumes, snapshots to a separate account/bucket, tested restores, ILM retention and disk-watermark alerts.
- Set realistic resource requests/limits and storage capacity from expected ingest/retention. Three Elasticsearch replicas with hard anti-affinity require at least three schedulable nodes with enough memory.
- Restrict Filebeat permissions to required node log paths; review security contexts and Kubernetes API permissions.
- Configure Kibana access via VPN/SSO or an authenticated internal ingress. Do not expose Elasticsearch on an internet-facing ALB.
- This is an operational starter, not a guarantee of production suitability.
