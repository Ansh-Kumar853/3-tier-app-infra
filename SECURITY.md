# Security Policy

## Supported deployment posture

This repository is a reference implementation and is not production-certified until the deployment-specific security review and operational tests are completed.

## Reporting a vulnerability

Do not publish credentials, database URLs, tokens, private keys, or exploit details in a public issue. Rotate any exposed credential immediately and report the issue privately to the repository maintainer through GitHub's private vulnerability reporting feature when available.

## Required release checks

- Keep the EKS API private or allow only trusted CIDRs; Jenkins must use private connectivity.
- Require HTTPS for public application ingress. The Jenkins main-branch pipeline refuses HTTP-only deployment.
- Store database credentials in AWS Secrets Manager and protect Terraform state because it can contain sensitive values.
- Review IAM roles for least privilege and use short-lived credentials where possible.
- Scan container images and dependencies; investigate and remediate high/critical findings.
- Keep Elasticsearch and Kibana private, authenticated, TLS-enabled, and subject to retention and restore tests.
- Rotate credentials after suspected exposure and keep dependencies/base images updated.
