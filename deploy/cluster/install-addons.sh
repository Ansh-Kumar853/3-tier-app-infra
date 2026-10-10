#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=ap-south-1}"
: "${EKS_CLUSTER_NAME:=three-tier-platform-dev}"
: "${AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN:?Set the IAM role ARN with the AWS Load Balancer Controller policy attached}"
: "${VPC_ID:?Set VPC_ID from terraform output}"

helm repo add eks https://aws.github.io/eks-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system --wait --timeout 5m

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system --set clusterName="$EKS_CLUSTER_NAME" \
  --set region="$AWS_REGION" --set vpcId="$VPC_ID" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN" \
  --wait --timeout 10m

kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=5m
kubectl -n kube-system rollout status deployment/metrics-server --timeout=5m
