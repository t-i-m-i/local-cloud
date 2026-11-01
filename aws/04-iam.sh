#!/usr/bin/env bash
# Stage 4: IAM (Identity and Access Management).
# IAM decides WHO may do WHAT in AWS. A "role" is an identity that a service
# (here: ECS) can take on. A "policy" lists allowed actions on named resources.
# Least privilege = each role gets only what it needs, nothing more.
# Floci APPROXIMATES IAM: policies are stored and can be evaluated, but
# enforcement is limited, so treat this as practice writing policies, not as a
# security test.
set -euo pipefail
cd "$(dirname "$0")/.."
source aws/env.sh

# Look up the addresses (ARNs) the policies must point at.
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --query ARN --output text)
REPO_ARN="arn:aws:ecr:$AWS_DEFAULT_REGION:$ACCOUNT_ID:repository/$ECR_REPO"
LOG_ARN="arn:aws:logs:$AWS_DEFAULT_REGION:$ACCOUNT_ID:log-group:$LOG_GROUP:*"

# Trust policy: says "the ECS tasks service may take on this role".
# Both roles below use it.
TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# Role 1: the EXECUTION role. Used by ECS itself, before and around starting
# the container: to pull the image, write logs and read the secret that is
# injected as environment variables.
aws iam create-role --role-name local-cloud-execution --assume-role-policy-document "$TRUST" >/dev/null 2>&1 || true

# Its permissions: exactly these actions on exactly these resources.
# (GetAuthorizationToken cannot be limited to one repository, so it uses "*".)
EXEC_POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "*" },
    { "Effect": "Allow",
      "Action": ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"],
      "Resource": "$REPO_ARN" },
    { "Effect": "Allow", "Action": "secretsmanager:GetSecretValue", "Resource": "$SECRET_ARN" },
    { "Effect": "Allow", "Action": ["logs:CreateLogStream", "logs:PutLogEvents"], "Resource": "$LOG_ARN" }
  ]
}
JSON
)
aws iam put-role-policy --role-name local-cloud-execution --policy-name execution-access \
  --policy-document "$EXEC_POLICY"

# Role 2: the TASK role. Used by YOUR code inside the container when it calls
# AWS. Our app only talks to PostgreSQL, never to AWS, so this role has NO
# permissions at all. That is least privilege: if the app is compromised, the
# attacker gets no AWS access through it.
aws iam create-role --role-name local-cloud-task --assume-role-policy-document "$TRUST" >/dev/null 2>&1 || true

# Show the result.
aws iam get-role --role-name local-cloud-execution --query 'Role.Arn' --output text
aws iam get-role --role-name local-cloud-task --query 'Role.Arn' --output text
aws iam list-role-policies --role-name local-cloud-execution
