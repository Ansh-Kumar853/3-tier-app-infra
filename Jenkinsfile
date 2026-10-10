pipeline {
  agent any
  parameters {
    string(name: 'APP_HOSTNAME', defaultValue: '', description: 'Required DNS hostname for production HTTPS ingress')
    string(name: 'ACM_CERTIFICATE_ARN', defaultValue: '', description: 'Required ACM certificate ARN in ap-south-1')
  }
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
    ECR_REPOSITORY_PREFIX = 'three-tier-platform-dev'
    PLATFORM_DB_SECRET_ID = 'three-tier-platform/dev/database'
    IMAGE_TAG = ''
  }
  stages {
    stage('Initialize') {
      steps {
        script {
          if (!env.GIT_COMMIT) {
            error('Git checkout is required; configure this Jenkins job as a Pipeline from SCM.')
          }
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
        }
      }
    }
    stage('Validate production configuration') {
      when { branch 'main' }
      steps {
        script {
          if (!params.APP_HOSTNAME?.trim() || !params.ACM_CERTIFICATE_ARN?.trim()) {
            error('Production deployment requires APP_HOSTNAME and ACM_CERTIFICATE_ARN; HTTP-only deployment is disabled.')
          }
          if (!params.ACM_CERTIFICATE_ARN.startsWith("arn:aws:acm:${env.AWS_REGION}:")) {
            error("ACM certificate must be in ${env.AWS_REGION}, the same region as the ALB.")
          }
        }
      }
    }
    stage('Backend checks') {
      steps {
        sh 'python3 -m pip install -r backend/requirements-dev.txt'
        sh 'cd backend && PYTHONPATH=. python3 -m pytest -q'
        sh 'cd backend && DATABASE_URL=sqlite:////tmp/platform-migration-ci.db APP_ENV=development alembic upgrade head'
      }
    }
    stage('Frontend checks') {
      steps {
        dir('frontend') {
          sh 'npm install --no-audit --no-fund'
          sh 'npm run build'
        }
      }
    }
    stage('Deployment preflight') {
      when { branch 'main' }
      steps {
        sh '''set -eu
          set +x
          aws sts get-caller-identity
          aws eks describe-cluster --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" --query 'cluster.status' --output text | grep -qx ACTIVE
          aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$ECR_REPOSITORY_PREFIX/backend" "$ECR_REPOSITORY_PREFIX/frontend" >/dev/null
          aws secretsmanager describe-secret --region "$AWS_REGION" --secret-id "$PLATFORM_DB_SECRET_ID" >/dev/null
          export KUBECONFIG="$WORKSPACE/.kubeconfig"
          aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"
          kubectl get nodes --request-timeout=15s
          kubectl -n kube-system get deployment aws-load-balancer-controller >/dev/null
          echo "Preflight passed: AWS identity, EKS API connectivity, ECR repositories, database secret, and ALB controller are present."
        '''
      }
    }
    stage('Build and push images') {
      when { branch 'main' }
      steps {
        sh '''set -eu
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
          BACKEND_REPO="$REGISTRY/$ECR_REPOSITORY_PREFIX/backend"
          FRONTEND_REPO="$REGISTRY/$ECR_REPOSITORY_PREFIX/frontend"
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
          set +x
          test -n "$APP_HOSTNAME"
          test -n "$ACM_CERTIFICATE_ARN"
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
          export KUBECONFIG="$WORKSPACE/.kubeconfig"
          aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"
          kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$K8S_NAMESPACE"

          # Jenkins agent must have private network connectivity to the EKS API.
          # Secret Manager secret must be JSON containing DATABASE_URL.
          SECRET_JSON=$(aws secretsmanager get-secret-value \
            --region "$AWS_REGION" --secret-id "$PLATFORM_DB_SECRET_ID" \
            --query SecretString --output text)
          DATABASE_URL=$(printf '%s' "$SECRET_JSON" | jq -er '.DATABASE_URL')
          unset SECRET_JSON
          test -n "$DATABASE_URL"
          SECRET_FILE=$(mktemp)
          trap 'rm -f "$SECRET_FILE"; unset DATABASE_URL' EXIT
          chmod 600 "$SECRET_FILE"
          printf 'DATABASE_URL=%s\n' "$DATABASE_URL" > "$SECRET_FILE"
          unset DATABASE_URL
          kubectl create secret generic platform-secrets -n "$K8S_NAMESPACE" \
            --from-env-file="$SECRET_FILE" --dry-run=client -o yaml | kubectl apply -f -
          rm -f "$SECRET_FILE"
          trap - EXIT

          helm upgrade --install platform ./deploy/helm/platform --namespace "$K8S_NAMESPACE" \
            --set-string namespace="$K8S_NAMESPACE" \
            --set ingress.enabled=true \
            --set-string backend.image="$REGISTRY/$ECR_REPOSITORY_PREFIX/backend:$IMAGE_TAG" \
            --set-string frontend.image="$REGISTRY/$ECR_REPOSITORY_PREFIX/frontend:$IMAGE_TAG" \
            --set-string ingress.host="$APP_HOSTNAME" \
            --set-string ingress.certificateArn="$ACM_CERTIFICATE_ARN" \
            --atomic --cleanup-on-fail --history-max 10 --wait --timeout 12m
          kubectl rollout status deployment/backend -n "$K8S_NAMESPACE" --timeout=5m
          kubectl rollout status deployment/frontend -n "$K8S_NAMESPACE" --timeout=5m
          kubectl get ingress platform -n "$K8S_NAMESPACE"
        '''
      }
    }
  }
  post { always { sh 'rm -f "$WORKSPACE/.kubeconfig" || true'; cleanWs(deleteDirs: true, notFailBuild: true) } }
}
