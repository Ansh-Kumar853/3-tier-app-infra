# Helm deployment

Create a Kubernetes Secret named `platform-secrets` in namespace `platform` containing `DATABASE_URL` and `APP_SECRET_KEY`. Use AWS Secrets Manager with External Secrets Operator or Secrets Store CSI Driver for production; do not commit secret values.

Install AWS Load Balancer Controller with least-privilege IAM and verify subnet discovery tags. Add ACM HTTPS listener and redirect annotations before production. Ensure the cluster supports NetworkPolicy enforcement and allow required database/DNS egress explicitly.

```bash
helm lint deploy/helm/platform
helm upgrade --install platform deploy/helm/platform --namespace platform --create-namespace \
  --set-string backend.image="$BACKEND_IMAGE" --set-string frontend.image="$FRONTEND_IMAGE" --wait
```
