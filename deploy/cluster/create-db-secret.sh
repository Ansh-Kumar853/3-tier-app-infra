#!/usr/bin/env bash
set -euo pipefail
set +x

: "${AWS_REGION:=ap-south-1}"
: "${SECRET_ID:=three-tier-platform/dev/database}"
: "${DB_NAME:=platform}"
: "${DB_USERNAME:=platformadmin}"
: "${DB_ENDPOINT:?Set DB_ENDPOINT to the RDS endpoint hostname (no port)}"

command -v aws >/dev/null || { echo "aws CLI is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
aws sts get-caller-identity >/dev/null

read -r -s -p "RDS database password: " DB_PASSWORD
printf '\n'
export DB_PASSWORD DB_ENDPOINT DB_USERNAME DB_NAME
DATABASE_URL="$(python3 - <<'PY'
import os
from urllib.parse import quote
user = quote(os.environ["DB_USERNAME"], safe="")
password = quote(os.environ["DB_PASSWORD"], safe="")
database = quote(os.environ["DB_NAME"], safe="")
host = os.environ["DB_ENDPOINT"]
print(f"postgresql+psycopg://{user}:{password}@{host}:5432/{database}")
PY
)"
export DATABASE_URL
unset DB_PASSWORD

SECRET_FILE="$(mktemp)"
trap 'rm -f "$SECRET_FILE"; unset DATABASE_URL' EXIT
chmod 600 "$SECRET_FILE"
python3 - "$SECRET_FILE" <<'PY'
import json, os, sys
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"DATABASE_URL": os.environ["DATABASE_URL"]}, f)
PY

if aws secretsmanager describe-secret --region "$AWS_REGION" --secret-id "$SECRET_ID" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value --region "$AWS_REGION" --secret-id "$SECRET_ID" --secret-string "file://$SECRET_FILE" >/dev/null
  echo "Updated Secrets Manager secret: $SECRET_ID"
else
  aws secretsmanager create-secret --region "$AWS_REGION" --name "$SECRET_ID" --description "Database connection for three-tier platform" --secret-string "file://$SECRET_FILE" >/dev/null
  echo "Created Secrets Manager secret: $SECRET_ID"
fi
