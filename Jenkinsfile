pipeline {
 agent any
 options { timestamps(); disableConcurrentBuilds(); timeout(time: 45, unit: 'MINUTES'); buildDiscarder(logRotator(numToKeepStr: '20')) }
 environment { AWS_REGION = 'ap-south-1'; EKS_CLUSTER_NAME = 'three-tier-platform-dev'; K8S_NAMESPACE = 'platform'; IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}" }
 stages {
  stage('Backend tests') { steps { sh 'python3 -m pip install -r backend/requirements.txt && python3 -m compileall -q backend/app' } }
  stage('Frontend build') { steps { dir('frontend') { sh 'npm ci --no-audit --no-fund && npm run build' } } }
  stage('Build and push') { when { branch 'main' } steps { sh '''set -eu
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
   aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
   docker build -t "$REGISTRY/three-tier-platform-dev/backend:$IMAGE_TAG" ./backend
   docker build -t "$REGISTRY/three-tier-platform-dev/frontend:$IMAGE_TAG" ./frontend
   docker push "$REGISTRY/three-tier-platform-dev/backend:$IMAGE_TAG"
   docker push "$REGISTRY/three-tier-platform-dev/frontend:$IMAGE_TAG"
  ''' } } }
 }
}
