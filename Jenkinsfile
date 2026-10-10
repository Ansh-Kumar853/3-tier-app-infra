pipeline {
  agent any
  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 45, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }
  environment {
    AWS_REGION = 'ap-south-1'
    EKS_CLUSTER_NAME = 'three-tier-platform-dev'
    K8S_NAMESPACE = 'platform'
    IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
  }
  stages {
    stage('Backend checks') {
      steps {
        sh 'python3 -m pip install -r backend/requirements.txt -r backend/requirements-dev.txt'
        sh 'cd backend && python3 -m pytest -q'
      }
    }
    stage('Frontend checks') {
      steps {
        dir('frontend') {
          sh 'npm ci --no-audit --no-fund'
          sh 'npm run build'
        }
      }
    }
    stage('Build and push images') {
      when { branch 'main' }
      steps {
        sh '''set -eu
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
          BACKEND_REPO="$REGISTRY/three-tier-platform-dev/backend"
          FRONTEND_REPO="$REGISTRY/three-tier-platform-dev/frontend"
          aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
          docker build --pull -t "$BACKEND_REPO:$IMAGE_TAG" ./backend
          docker build --pull -t "$FRONTEND_REPO:$IMAGE_TAG" ./frontend
          docker push "$BACKEND_REPO:$IMAGE_TAG"
          docker push "$FRONTEND_REPO:$IMAGE_TAG"
        '''
      }
    }
    stage('Deploy to EKS') {
      when { branch 'main' }
      steps {
        sh '''set -eu
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
          aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"
          kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$K8S_NAMESPACE"
          helm upgrade --install platform ./deploy/helm/platform --namespace "$K8S_NAMESPACE" \
            --set namespace="$K8S_NAMESPACE" \
            --set backend.image="$REGISTRY/three-tier-platform-dev/backend:$IMAGE_TAG" \
            --set frontend.image="$REGISTRY/three-tier-platform-dev/frontend:$IMAGE_TAG" \
            --wait --timeout 5m
        '''
      }
    }
  }
  post { always { cleanWs(deleteDirs: true, notFailBuild: true) } }
}
