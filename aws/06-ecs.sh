#!/usr/bin/env bash
# Stage 6: ECS (Elastic Container Service) with the EC2 launch type.
# ECS runs your containers. Vocabulary:
#   cluster          a named group of machines that run containers
#   container instance  one EC2 machine in that cluster (EC2 launch type: YOU
#                    own and manage these machines; Fargate would hide them)
#   task definition  the recipe: which image, memory, ports, logs, roles, env
#   task             one running copy made from that recipe
#
# Floci APPROXIMATES several things here (see docs/stages.md):
#   - There is no real EC2 machine. We register a made-up "container instance"
#     and Floci runs the container in Docker on your laptop.
#   - Floci does not inject Secrets Manager values into containers, so this
#     script reads the secret and passes the values as plain environment
#     variables. On real AWS you would use the "secrets" field (shown in docs).
set -euo pipefail
cd "$(dirname "$0")/.."
source aws/env.sh

# Host port the app will answer on. 3100, so it does not clash with the
# Docker Compose app on 3000.
HOST_PORT=3100

# Create the cluster (the group of machines). Safe to repeat.
aws ecs create-cluster --cluster-name "$ECS_CLUSTER" >/dev/null

# Register a pretend EC2 machine into the cluster. On real AWS an agent on the
# machine does this by itself; Floci needs it done by hand.
# The identity document is the machine's "ID card". These values are made up.
aws ecs register-container-instance \
  --cluster "$ECS_CLUSTER" \
  --instance-identity-document '{"instanceId":"i-0123456789abcdef0","region":"us-east-1","accountId":"000000000000"}' \
  --instance-identity-document-signature "fake-signature" \
  --total-resources name=CPU,type=INTEGER,integerValue=2048 \
  --total-resources name=MEMORY,type=INTEGER,integerValue=4096 >/dev/null

# Read the database details from Secrets Manager (stage 3).
# Floci cannot inject them for us, so we fetch them here.
SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query SecretString --output text)
DB_HOST=$(echo "$SECRET" | jq -r .host)
DB_PORT=$(echo "$SECRET" | jq -r .port)
DB_NAME=$(echo "$SECRET" | jq -r .dbname)
DB_USER=$(echo "$SECRET" | jq -r .username)
DB_PASSWORD=$(echo "$SECRET" | jq -r .password)

# The task definition: the recipe for our one container.
# - image: the one we pushed to ECR in stage 1
# - portMappings: container port 3000 is published on the machine's port 3100
# - environment: the settings src/db.ts reads
# - logConfiguration: send stdout/stderr to the CloudWatch log group (stage 5)
# - executionRoleArn / taskRoleArn: the two roles from stage 4
TASK_DEF=$(jq -n \
  --arg image "$ECR_HOST/$ECR_REPO:latest" \
  --arg host "$DB_HOST" --arg port "$DB_PORT" --arg name "$DB_NAME" \
  --arg user "$DB_USER" --arg pass "$DB_PASSWORD" \
  --arg group "$LOG_GROUP" --arg region "$AWS_DEFAULT_REGION" \
  --argjson hostPort "$HOST_PORT" \
  '[{
    name: "api", image: $image, essential: true, cpu: 256, memory: 512,
    portMappings: [{containerPort: 3000, hostPort: $hostPort, protocol: "tcp"}],
    environment: [
      {name: "DB_HOST", value: $host}, {name: "DB_PORT", value: $port},
      {name: "DB_NAME", value: $name}, {name: "DB_USER", value: $user},
      {name: "DB_PASSWORD", value: $pass}
    ],
    logConfiguration: {logDriver: "awslogs", options: {
      "awslogs-group": $group, "awslogs-region": $region, "awslogs-stream-prefix": "api"
    }}
  }]')

aws ecs register-task-definition \
  --family local-cloud-api \
  --requires-compatibilities EC2 \
  --network-mode bridge \
  --execution-role-arn "arn:aws:iam::$ACCOUNT_ID:role/local-cloud-execution" \
  --task-role-arn "arn:aws:iam::$ACCOUNT_ID:role/local-cloud-task" \
  --container-definitions "$TASK_DEF" >/dev/null

# Start one task (one running copy of the recipe) on our EC2 machine.
aws ecs run-task --cluster "$ECS_CLUSTER" --task-definition local-cloud-api \
  --launch-type EC2 --count 1 \
  --query 'tasks[0].[taskArn,lastStatus]' --output text

# Give the container a few seconds to start, then show the task state.
sleep 8
aws ecs list-tasks --cluster "$ECS_CLUSTER" --query 'taskArns' --output text
echo "Open http://localhost:$HOST_PORT"
