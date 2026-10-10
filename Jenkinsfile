pipeline {
  agent any
  parameters {
    string(name: 'APP_HOSTNAME', defaultValue: '', description: 'DNS hostname for HTTPS ingress; leave blank only for temporary HTTP testing')
    string(name: 'ACM_CERTIFICATE_ARN', defaultValue: '', description: 'ACM certificate ARN in the same region as the ALB')
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
    stage('Backend checks') {
      steps {
        sh 'python3 -m pip install -r backend/requirements-dev.txt'
        sh 'cd backend && PYTHONPATH=. python3 -m pytest -q'
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
    stage('Build and push images') {
      when { expression { env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'origin/main' || env.GIT_BRANCH == 'main' } }
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
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
          aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"
          kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$K8S_NAMESPACE"

          # Secret Manager secret must be JSON containing DATABASE_URL.
          # Never print the secret or commit it to the repository.
          SECRET_JSON=$(aws secretsmanager get-secret-value \
            --region "$AWS_REGION" --secret-id "$PLATFORM_DB_SECRET_ID" \
            --query SecretString --output text)
          DATABASE_URL=$(printf '%s' "$SECRET_JSON" | jq -er '.DATABASE_URL')
          unset SECRET_JSON
          test -n "$DATABASE_URL"
          SECRET_FILE=$(mktemp)
          trap 'rm -f "$SECRET_FILE"' EXIT
          chmod 600 "$SECRET_FILE"
          printf 'DATABASE_URL=%s\n' "$DATABASE_URL" > "$SECRET_FILE"
          unset DATABASE_URL
          kubectl create secret generic platform-secrets -n "$K8S_NAMESPACE" \
            --from-env-file="$SECRET_FILE" --dry-run=client -o yaml | kubectl apply -f -
          rm -f "$SECRET_FILE"
          trap - EXIT

          if [ -n "$APP_HOSTNAME" ] && [ -n "$ACM_CERTIFICATE_ARN" ]; then
            helm upgrade --install platform ./deploy/helm/platform --namespace "$K8S_NAMESPACE" \
              --set-string namespace="$K8S_NAMESPACE" \
              --set-string backend.image="$REGISTRY/$ECR_REPOSITORY_PREFIX/backend:$IMAGE_TAG" \
              --set-string frontend.image="$REGISTRY/$ECR_REPOSITORY_PREFIX/frontend:$IMAGE_TAG" \
              --set-string ingress.host="$APP_HOSTNAME" \
              --set-string ingress.certificateArn="$ACM_CERTIFICATE_ARN" \
              --wait --timeout 8m
          elif [ -z "$APP_HOSTNAME" ] && [ -z "$ACM_CERTIFICATE_ARN" ]; then
            echo "WARNING: deploying HTTP-only ingress for temporary testing; configure hostname and ACM certificate for production."
            helm upgrade --install platform ./deploy/helm/platform --namespace "$K8S_NAMESPACE" \
              --set-string namespace="$K8S_NAMESPACE" \
              --set-string backend.image="$REGISTRY/$ECR_REPOSITORY_PREFIX/backend:$IMAGE_TAG" \
              --set-string frontend.image="$REGISTRY/$ECR_REPOSITORY_PREFIX/frontend:$IMAGE_TAG" \
              --wait --timeout 8m
          else
            echo "APP_HOSTNAME and ACM_CERTIFICATE_ARN must either both be set or both be empty." >&2
            exit 1
          fi
          kubectl rollout status deployment/backend -n "$K8S_NAMESPACE" --timeout=5m
          kubectl rollout status deployment/frontend -n "$K8S_NAMESPACE" --timeout=5m
          kubectl get ingress platform -n "$K8S_NAMESPACE"
        '''
      }
    }
  }
  post { always { cleanWs(deleteDirs: true, notFailBuild: true) } }
}
