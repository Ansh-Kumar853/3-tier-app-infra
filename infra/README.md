# Terraform infrastructure

This configuration provisions a VPC, EKS managed node group, ECR repositories and a private Multi-AZ RDS PostgreSQL instance.

## Before apply

- Terraform >= 1.10 and AWS CLI configured for the target account.
- EKS public API CIDRs must be explicitly set to your trusted IP/VPN range. The default intentionally allows no public source IP; use private access/VPN/bastion if you do not have a stable public IP.
- Create a remote state bucket with versioning, encryption, public access block and tightly scoped IAM. Copy backend.tf.example to backend.tf and replace the bucket name. Do not commit real state or credentials.
- Supply a strong database password through TF_VAR_db_password or a secure CI secret; state still contains sensitive values and must be protected.
- Review instance sizing and estimated cost. NAT gateways, EKS nodes and Multi-AZ RDS have ongoing costs.

## Commands

terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
aws eks update-kubeconfig --region "$(terraform output -raw region)" --name "$(terraform output -raw cluster_name)"

Install AWS Load Balancer Controller with IRSA before enabling ALB ingress. RDS endpoint is emitted as an output; create the Kubernetes platform-secrets via AWS Secrets Manager and a secret operator, not by committing YAML with values.
