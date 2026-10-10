# Elastic Stack logging

Use Elastic-maintained Helm charts or Elastic Operator with pinned, compatible versions for Elasticsearch, Kibana, and Filebeat. Keep the services private. Configure TLS, authentication, encrypted persistent volumes, retention/ILM, snapshots, resource requests/limits, and restricted access before production. Filebeat requires carefully audited permissions to read node container logs. Elastic Stack is resource intensive; size based on ingest and retention.

Example outline:
```bash
helm repo add elastic https://helm.elastic.co
helm repo update
kubectl create namespace observability
# Install Elasticsearch, Kibana, and Filebeat with version-matched, reviewed values files.
```
