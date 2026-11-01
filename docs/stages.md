# AWS stages

Every stage was run against Floci 2.4.0 (Docker Desktop, macOS). "Real" means it behaves like AWS for our purposes. **Approximate** means Floci imitates it and the difference matters if you move to real AWS.

Run order: `01` to `06`, then `99-cleanup.sh`. Start Floci first: `docker compose -f compose.floci.yaml up -d`.

## [x] Stage 1: ECR (`aws/01-ecr.sh`)

Stores the app image. The script creates a repository, builds the image, logs Docker in and pushes.

- Real: Floci runs an actual Docker registry, so `docker push` really works.
- **Approximate:** the registry address looks like `000000000000.dkr.ecr.us-east-1.localhost:4566`. No encryption, scanning or replication.
- Worth noticing: Floci must run on its own Docker network (`compose.floci.yaml`) or the push fails with a 503 error. The Homebrew `floci start` command uses the default network and hits this.

## [x] Stage 2: RDS (`aws/02-rds.sh`)

A managed PostgreSQL database.

- Real: a genuine `postgres:16` container answers SQL.
- **Approximate:** no backups, patching, failover, storage or networking rules. The endpoint is a Docker-internal address, reachable only from containers on the `floci_default` network, so the script loads the schema from a short-lived container instead of from your Mac.

## [x] Stage 3: Secrets Manager (`aws/03-secrets.sh`)

Stores the DB credentials as one JSON secret.

- Real: create, read, update, and versions all work.
- **Approximate:** no real encryption or rotation.
- **Not supported by Floci:** injecting a secret into a container through the task definition's `secrets` field. See stage 6.

## [x] Stage 4: IAM (`aws/04-iam.sh`)

Two roles, both trusted by `ecs-tasks.amazonaws.com`:

| Role | Used by | Permissions |
| --- | --- | --- |
| `local-cloud-execution` | ECS itself | pull the one ECR repo, read the one secret, write to the one log group |
| `local-cloud-task` | our app code | none (the app never calls AWS) |

- Real: roles and policy documents are stored and returned like AWS.
- **Approximate:** Floci does not reliably block a call that a policy would deny. Treat this stage as practice writing policies, not as a test that they work.

## [x] Stage 5: CloudWatch Logs (`aws/05-logs.sh`)

Creates the log group `/local-cloud/api` with 7-day retention. Stage 6 fills it.

- Real: Floci's ECS sends container stdout/stderr to the group when the task uses the `awslogs` driver. Verified: request log lines from the app appear in a stream called `api/api/<task id>`.
- Read them: `source aws/env.sh; aws logs describe-log-streams --log-group-name $LOG_GROUP`, then `aws logs get-log-events --log-group-name $LOG_GROUP --log-stream-name <stream>`.

## [x] Stage 6: ECS, EC2 launch type (`aws/06-ecs.sh`)

Cluster, task definition, one task. The app answers on <http://localhost:3100> (3100 so it does not clash with other local apps).

- Real: Floci runs the task as a real container from the ECR image.
- **Approximate:**
  - No EC2 machine exists. The script registers a pretend "container instance" by hand. On real AWS you launch an EC2 instance running the ECS agent, and it registers itself.
  - **Secrets:** Floci does not inject secrets, so the script reads the secret and passes plain environment variables. On real AWS use this instead, and the password never appears in the task definition:

    ```json
    "secrets": [
      { "name": "DB_PASSWORD",
        "valueFrom": "arn:aws:secretsmanager:REGION:ACCOUNT:secret:local-cloud/db-XXXXXX:password::" }
    ]
    ```
  - The execution role is accepted but not checked.
  - Task state is kept in memory: restarting Floci forgets tasks.
- Left out on purpose: load balancer, auto scaling, services, VPC design, HTTPS.

## Moving to real AWS (not done here)

The same scripts mostly work with a real account: remove `AWS_ENDPOINT_URL` and the dummy keys from `aws/env.sh`, and replace the pretend container instance with a real EC2 instance running the ECS agent. Also switch to the `secrets` field above and add VPC, security groups and a load balancer. Real AWS costs money, so check pricing first.
