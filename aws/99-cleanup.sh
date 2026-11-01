#!/usr/bin/env bash
# Cleanup: removes everything stages 1-6 created inside Floci, newest first.
# Each command ignores "not found" errors, so it is safe to run at any time.
# (Stopping Floci itself with `docker compose -f compose.floci.yaml down`
# also throws everything away.)
set -uo pipefail
cd "$(dirname "$0")/.."
source aws/env.sh

# Stage 6: stop running tasks, remove the pretend EC2 machines, delete the cluster.
for t in $(aws ecs list-tasks --cluster "$ECS_CLUSTER" --query 'taskArns[]' --output text 2>/dev/null); do
  aws ecs stop-task --cluster "$ECS_CLUSTER" --task "$t" >/dev/null
done
for i in $(aws ecs list-container-instances --cluster "$ECS_CLUSTER" --query 'containerInstanceArns[]' --output text 2>/dev/null); do
  aws ecs deregister-container-instance --cluster "$ECS_CLUSTER" --container-instance "$i" --force >/dev/null
done
aws ecs delete-cluster --cluster "$ECS_CLUSTER" >/dev/null 2>&1

# Stage 5: the log group (and all logs in it).
aws logs delete-log-group --log-group-name "$LOG_GROUP" 2>/dev/null

# Stage 4: roles. A role's inline policy must be removed before the role.
aws iam delete-role-policy --role-name local-cloud-execution --policy-name execution-access 2>/dev/null
aws iam delete-role --role-name local-cloud-execution 2>/dev/null
aws iam delete-role --role-name local-cloud-task 2>/dev/null

# Stage 3: the secret, deleted immediately (real AWS normally waits 7-30 days).
aws secretsmanager delete-secret --secret-id "$SECRET_NAME" --force-delete-without-recovery >/dev/null 2>&1

# Stage 2: the database. Skip the final backup because this is a demo.
aws rds delete-db-instance --db-instance-identifier "$DB_INSTANCE" --skip-final-snapshot >/dev/null 2>&1

# Stage 1: the image repository, including the images in it.
aws ecr delete-repository --repository-name "$ECR_REPO" --force >/dev/null 2>&1

echo "Floci cleaned up."
