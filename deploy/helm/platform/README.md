# Helm deployment

The chart expects a Kubernetes Secret named platform-secrets in the same namespace, with a DATABASE_URL key. Use AWS Secrets Manager with External Secrets Operator or Secrets Store CSI Driver for production; never commit secret values. The DATABASE_URL format is postgresql+psycopg://USER:PASSWORD@RDS_ENDPOINT:5432/DB_NAME. URL-encode special characters in the password.

Install AWS Load Balancer Controller with least-privilege IAM and verify public/private subnet discovery tags. Set an ACM certificate ARN and DNS hostname in the chart values before enabling HTTPS. The ALB sends traffic to the frontend service; Nginx routes /api requests to the internal backend service. The NetworkPolicy permits backend ingress from frontend pods.

Before installing, confirm EKS metrics are available for HPA and install metrics-server if needed.

```bash
helm lint deploy/helm/platform
helm upgrade --install platform deploy/helm/platform --namespace platform --create-namespace \
  --set-string backend.image="$BACKEND_IMAGE" --set-string frontend.image="$FRONTEND_IMAGE" --wait
```

For local/manual deployment, create the Secret securely before Helm installation. Example shape only; replace values in your shell and do not save the command to Git or shell history:

```bash
kubectl create secret generic platform-secrets -n platform \
  --from-literal=DATABASE_URL='postgresql+psycopg://USER:URL_ENCODED_PASSWORD@RDS_ENDPOINT:5432/DB_NAME'
```
