# Three-Tier AWS Platform

A full-stack reference project with a React frontend, FastAPI API, PostgreSQL database, Terraform-managed AWS infrastructure, Amazon EKS, Jenkins CI/CD, Helm, Docker, and Elastic Stack log collection.

**Honest status:** The repository includes production-oriented controls and CI checks, but this session has not verified the app deployment against your existing AWS/EKS environment, nor completed load tests, a security assessment, restore drills, or ELK runtime validation. Passing CI does not mean the live service is production-certified.

## Architecture

- Frontend: React/Vite served by Nginx container.
- API: FastAPI REST endpoints for notes, health, and readiness.
- Database: Private, encrypted, Multi-AZ Amazon RDS for PostgreSQL.
- Infrastructure: Terraform VPC with public/private/database subnets, EKS managed node group, ECR repositories and lifecycle policies.
- Deployment: Helm chart with probes, resource limits, HPA, PodDisruptionBudgets, restricted pod security, backend ingress NetworkPolicy, and a pre-install/pre-upgrade database migration Job.
- CI/CD: Jenkins tests, builds immutable image tags, pushes to ECR and deploys to EKS on main.
- Logs: Elasticsearch, Kibana and Filebeat Helm values/scripts under deploy/observability.
- CI validation: GitHub Actions for backend tests, frontend build and Terraform validation.

## Repository layout

- backend/: FastAPI API, tests, Dockerfile
- frontend/: React/Vite UI, Nginx config, Dockerfile
- infra/: Terraform VPC, EKS, ECR and RDS
- deploy/helm/platform/: Kubernetes Helm chart
- deploy/observability/: Elastic Stack values and installer
- .github/workflows/ci.yml: pull-request and main-branch checks
- Jenkinsfile: image build/push and EKS deployment
- docker-compose.yml: local development

## Run locally

Install Docker and Docker Compose, then run: docker compose up --build

Open http://localhost:8080. API health: http://localhost:8000/healthz. API docs: http://localhost:8000/docs. Local database credentials in Compose are for local development only.

## Provision and connect to AWS

**If your EKS cluster already exists, do not run `terraform apply` blindly.** First verify that this repository's Terraform state manages those exact resources. If it does not, reconcile/import the existing resources or use a reviewed migration plan; otherwise Terraform may try to create duplicate resources.

1. Install Terraform >= 1.10, AWS CLI, kubectl and Helm. Authenticate using a least-privilege IAM role or SSO profile.
2. Confirm the intended region, cluster name, ECR repositories, RDS endpoint, and VPC IDs match the Jenkinsfile and Terraform outputs. The defaults use `ap-south-1` and cluster `three-tier-platform-dev`.
3. Protect remote Terraform state with an encrypted, versioned private S3 bucket and tightly scoped IAM. State may contain the database password.
4. For a new infrastructure deployment only, set `TF_VAR_db_password` through a secure secret mechanism and review `terraform plan` before applying.
5. Install the AWS Load Balancer Controller with IRSA and verify public subnet discovery tags. The deployment preflight now checks that the controller deployment exists.
6. Create/update the Secrets Manager secret expected by Jenkins: `DB_ENDPOINT=$(cd infra && terraform output -raw rds_endpoint) bash deploy/cluster/create-db-secret.sh`. Enter the **same database password** that was used for the RDS instance. The script stores a TLS-enabled `DATABASE_URL`; do not put secrets in Git or logs.
7. Configure Jenkins as a multibranch Pipeline from SCM. Its agent needs Python 3, Node.js 22, Docker, AWS CLI, kubectl, Helm, jq and the Workspace Cleanup plugin, plus least-privilege ECR push, Secrets Manager read, and EKS deployment permissions.
8. The EKS API is private by default. The Jenkins agent must run inside the VPC or have private network connectivity to the cluster endpoint. The preflight stage checks AWS identity, cluster status/connectivity, ECR repositories, the database secret and the ALB controller before images are pushed.
9. On the `main` branch, provide `APP_HOSTNAME` and an ACM certificate ARN from `ap-south-1`. The pipeline intentionally refuses HTTP-only deployment. Ensure DNS points to the ALB and the certificate covers the hostname.
10. The Helm pre-install/pre-upgrade Job runs `alembic upgrade head` before application pods roll out. Review migrations before release and verify the rollout, API readiness, TLS endpoint and logs after deployment.

## Install Elastic Stack

See deploy/observability/README.md. Elastic Stack is a separate deployment and is not installed by Terraform. Elasticsearch requires significant memory and persistent storage. Use internal services, TLS/authentication, encrypted volumes, backups, ILM retention and restricted Kibana access. Review and pin compatible chart versions before installation.

## Production readiness checklist

- Restrict the EKS API to trusted CIDRs and enable private connectivity.
- Keep Terraform state encrypted, versioned and tightly permissioned.
- Store the database connection in AWS Secrets Manager; Jenkins syncs it to the application namespace only during deployment.
- Configure HTTPS with a real ACM certificate and DNS hostname before public use.
- Database schema is versioned with Alembic; review each migration and test upgrade/rollback behavior before production changes.
- Test RDS restore, Elastic snapshots, alerts, retention and disaster recovery.
- Add enforced container/dependency vulnerability scanning and SBOM generation; review findings before release.
- Generate and retain an SBOM for release images.
- Run end-to-end, load, failover and restore tests in a non-production AWS environment.
- Add production alerting, log retention/ILM policies, secret rotation, backup monitoring and a documented incident/rollback process.
- Add a staged rollout/approval process for production and a rollback procedure.
- Estimate costs before apply: EKS nodes, NAT gateways, Multi-AZ RDS, load balancers and Elastic storage all incur charges.

## Tear down

After backing up anything important, run terraform destroy from infra/. RDS deletion protection and final snapshots are enabled; handle those deliberately.
