#!/usr/bin/env bash
# Stage 5: CloudWatch Logs.
# CloudWatch Logs collects the text your containers print (stdout/stderr).
# A "log group" is a folder for one app; inside it each container writes to
# its own "log stream". This stage creates the folder; ECS fills it (stage 6).
set -euo pipefail
cd "$(dirname "$0")/.."
source aws/env.sh

# Create the log group. Skipped quietly if it already exists.
aws logs create-log-group --log-group-name "$LOG_GROUP" 2>/dev/null || true

# Keep logs for 7 days only. Old logs cost money on real AWS.
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7

# Show the group.
aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query 'logGroups[].[logGroupName,retentionInDays]' --output text
