#!/usr/bin/env bash
# Stage 3: Secrets Manager.
# Secrets Manager stores sensitive values (like database passwords) encrypted,
# so they are not written into code, images or task definitions. Access to
# them is controlled by IAM (stage 4).
set -euo pipefail
cd "$(dirname "$0")/.."
source aws/env.sh

# Look up the RDS address created in stage 2.
DB_HOST=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" \
  --query 'DBInstances[0].Endpoint.Address' --output text)
DB_PORT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" \
  --query 'DBInstances[0].Endpoint.Port' --output text)

# One secret holding all connection details as JSON. Same demo values as stage 2.
SECRET_JSON=$(printf '{"host":"%s","port":"%s","dbname":"demo","username":"demo","password":"demo-password"}' \
  "$DB_HOST" "$DB_PORT")

# Create the secret, or add a new version of it if it exists already.
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value --secret-id "$SECRET_NAME" --secret-string "$SECRET_JSON" >/dev/null
else
  aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string "$SECRET_JSON" >/dev/null
fi

# Show the secret's address (ARN). Policies and the ECS task definition use it.
# We print the metadata only, never the secret value.
aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --query '[Name,ARN]' --output text
