#!/usr/bin/env bash
# Shared settings for every aws/*.sh script. Each script loads this first.
# Usage by hand:  source aws/env.sh

# Send every `aws` command to Floci on your laptop instead of the real AWS.
# Without this line the AWS CLI would try to reach the real cloud.
export AWS_ENDPOINT_URL=http://localhost:4566

# Floci accepts any credentials. These dummy values only satisfy the CLI.
# Never put real AWS keys in these scripts.
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Do not open a pager (less) for long command output.
export AWS_PAGER=""

# Names used by all the stages, kept in one place.
export APP_NAME=local-cloud
export ECR_REPO=local-cloud-api
# Floci's fake AWS account number is always 000000000000.
export ACCOUNT_ID=000000000000
export ECR_HOST="$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.localhost:4566"
export LOG_GROUP=/local-cloud/api
export SECRET_NAME=local-cloud/db
export DB_INSTANCE=local-cloud-db
export ECS_CLUSTER=local-cloud
