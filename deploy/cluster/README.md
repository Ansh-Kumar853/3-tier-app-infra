# EKS add-ons

Run install-addons.sh after Terraform has created the cluster and after creating an IAM role for the AWS Load Balancer Controller using the official AWS policy for the controller version you install. Do not use administrator credentials for workloads.

Example environment setup:

- EKS_CLUSTER_NAME: value from terraform output cluster_name
- AWS_REGION: value from terraform output region
- VPC_ID: value from terraform output vpc_id
- AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN: IAM role ARN with the reviewed controller policy

Then run: bash deploy/cluster/install-addons.sh

This installs metrics-server for HPA metrics and AWS Load Balancer Controller for the chart's ALB Ingress. Review chart versions and the AWS policy release notes before production.
