#!/usr/bin/env bash
# Stage 2: RDS (Relational Database Service).
# RDS is AWS running PostgreSQL for you: backups, patches and storage are
# handled by AWS. Floci APPROXIMATES this by starting a normal postgres
# container; there is no real cloud server, disk or backup behind it.
set -euo pipefail
cd "$(dirname "$0")/.."
source aws/env.sh

# Local-only demo password. In stage 3 it moves into Secrets Manager, which is
# where the app gets it from. Do not reuse this value anywhere real.
DB_NAME=demo
DB_USER=demo
DB_PASSWORD=demo-password

# Create the database server ("instance"). Skipped if it already exists.
if ! aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" >/dev/null 2>&1; then
  aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE" \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --master-username "$DB_USER" \
    --master-user-password "$DB_PASSWORD" \
    --db-name "$DB_NAME" \
    --allocated-storage 20 >/dev/null
fi

# Wait until the instance reports "available".
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE"

# Ask AWS where the database lives (its "endpoint": a host name and a port).
DB_HOST=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" \
  --query 'DBInstances[0].Endpoint.Address' --output text)
DB_PORT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" \
  --query 'DBInstances[0].Endpoint.Port' --output text)
echo "RDS endpoint: $DB_HOST:$DB_PORT"

# Create the tables and seed data by running db/init.sql against RDS.
# On Floci the endpoint is only reachable from inside Docker's floci_default
# network, so we run psql from a short-lived container on that network.
# (On real AWS you would run psql from your laptop or a bastion host.)
docker run --rm --network floci_default \
  -e PGPASSWORD="$DB_PASSWORD" \
  -v "$PWD/db/init.sql:/init.sql:ro" \
  postgres:16-alpine \
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f /init.sql

# Prove the seed data arrived: count the events (expect 12).
docker run --rm --network floci_default -e PGPASSWORD="$DB_PASSWORD" postgres:16-alpine \
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tc "SELECT count(*) FROM platform_events"
