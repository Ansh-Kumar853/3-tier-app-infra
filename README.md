# Three-Tier AWS Platform

A full-stack reference project with a React frontend, FastAPI API, PostgreSQL database, Terraform-managed AWS infrastructure, Amazon EKS, Jenkins CI/CD, Helm, Docker, and Elastic Stack log collection.

**Honest status:** Files and pipeline templates are committed to this repository. No AWS resources have been created and no real deployment has been run from this chat. Run the validation and deployment steps below in your own AWS/Jenkins environment before treating it as production-ready.

## Architecture

- Frontend: React/Vite served by Nginx container.
- API: FastAPI REST endpoints for notes, health, and readiness.
- Database: Private, encrypted, Multi-AZ Amazon RDS for PostgreSQL.
- Infrastructure: Terraform VPC with public/private/database subnets, EKS managed node group, ECR repositories and lifecycle policies.
- Deployment: Helm chart with probes, resource limits, HPA, PodDisruptionBudgets and a backend ingress NetworkPolicy.
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

## Provision AWS

1. Install Terraform >= 1.10, AWS CLI, kubectl and Helm. Authenticate with an IAM role/SSO profile using least privilege.
2. Read infra/README.md and infra/terraform.tfvars.example. Set your trusted EKS API CIDR in a private tfvars file. The public endpoint is intentionally not open to the internet by default.
3. Configure remote Terraform state using infra/backend.tf.example. Use a private, encrypted, versioned S3 bucket and restricted IAM access. State can contain database credentials.
4. Set TF_VAR_db_password through a secure secret mechanism, not in Git. From infra/, run terraform init, terraform fmt -recursive, terraform validate, terraform plan, and then terraform apply.
5. Install AWS Load Balancer Controller with IRSA and verify subnet discovery tags before using the ALB ingress.
6. Configure the Kubernetes Secret platform-secrets with DATABASE_URL using AWS Secrets Manager + External Secrets Operator (recommended). Do not commit a Kubernetes Secret with real values.
7. Build and deploy images through Jenkins. The Jenkins agent needs Python 3, Node.js 22, Docker, AWS CLI, kubectl, Helm and the Workspace Cleanup plugin. Configure an IAM role with ECR push permissions and EKS access/RBAC. Set the pipeline's cluster, region and repository names to match Terraform outputs.

## Install Elastic Stack

See deploy/observability/README.md. Elastic Stack is a separate deployment and is not installed by Terraform. Elasticsearch requires significant memory and persistent storage. Use internal services, TLS/authentication, encrypted volumes, backups, ILM retention and restricted Kibana access. Review and pin compatible chart versions before installation.

## Production readiness checklist

- Restrict the EKS API to trusted CIDRs and enable private connectivity.
- Keep Terraform state encrypted, versioned and tightly permissioned.
- Use Secrets Manager and a secret operator for database credentials.
- Configure HTTPS with a real ACM certificate and DNS hostname before public use.
- Add Alembic migrations; the demo currently creates tables at application startup.
- Test RDS restore, Elastic snapshots, alerts, retention and disaster recovery.
- Scan container images/dependencies, pin dependencies and run deployment tests.
- Add a staged rollout/approval process for production and a rollback procedure.
- Estimate costs before apply: EKS nodes, NAT gateways, Multi-AZ RDS, load balancers and Elastic storage all incur charges.

## Tear down

After backing up anything important, run terraform destroy from infra/. RDS deletion protection and final snapshots are enabled; handle those deliberately.
