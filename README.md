# local-cloud

A tiny Fastify + PostgreSQL app for learning Docker, then the same app on (fake, local) AWS using Floci. Built for learning, not production: the code is small and every block has a plain-English comment.

New to Docker or AWS? Read [docs/architecture.md](docs/architecture.md) first.

## Goal

1. Run a web app and its database with one command (Docker Compose).
2. Practice the AWS pieces that would run the same app in the cloud: ECR, RDS, Secrets Manager, IAM, CloudWatch Logs and ECS (EC2 launch type, no Fargate), without an AWS account.

<img width="824" height="585" alt="screen" src="https://github.com/user-attachments/assets/d0ea8719-f4fb-44bf-a850-a9816afe3145" />

## Stack

| Piece | What it is for |
| --- | --- |
| Node.js 24 + TypeScript | Runs `src/*.ts` directly (Node strips the types), so there is no build step |
| Fastify | The web server, with one page |
| PostgreSQL 16 | The database |
| Docker Compose | Starts the app and database together on your Mac |
| Floci | A fake AWS on your laptop (`http://localhost:4566`) |
| AWS CLI | Talks to Floci in the `aws/*.sh` scripts |

## Prerequisites

- Docker Desktop, running
- For the AWS stages only: `brew install awscli jq` (and optionally `brew install floci-io/floci/floci` for the `floci` helper command)
- Node is only needed if you want to run `npm run typecheck` on your Mac

## Run it locally

```bash
cp .env.example .env              # local throwaway DB settings
docker compose up --build         # starts postgres + the app
```

Open <http://localhost:3000>. You should see a table of 12 events with their statuses. `http://localhost:3000/health` answers `ok`.

Useful commands:

```bash
docker compose logs -f api        # the app's logs (one JSON line per request)
docker compose down               # stop, keep the data
docker compose down -v            # stop AND delete the database + seed data
docker compose up --build         # start again: schema and seed are re-created
```

**Reset the database:** `docker compose down -v && docker compose up --build`. The seed file `db/init.sql` only runs when the database is created empty, which is why `-v` (delete the volume) resets it. The file is also safe to run twice.

## Architecture

```
Browser --> :3000 --> [ api container: Fastify ] --> [ db container: PostgreSQL ]
                                                          |
                                                    named volume "pgdata"
```

More detail, with AWS concepts explained from zero, in [docs/architecture.md](docs/architecture.md).

## Seed data

- `status` (3 rows): `operational`, `degraded`, `outage`
- `platform_events` (12 rows): name, description, `status_id` (foreign key to `status`), timestamp. Examples: "API deploy", "Payment provider down", "Region outage".
- The app's only query joins them: `platform_events JOIN status ON status.id = platform_events.status_id` (in `src/db.ts`).

## AWS learning path (Floci)

Floci fakes AWS locally. Start it, then run the stages in order:

```bash
docker compose -f compose.floci.yaml up -d    # start Floci
./aws/01-ecr.sh       # push the app image to ECR
./aws/02-rds.sh       # create a PostgreSQL database in RDS, load the seed data
./aws/03-secrets.sh   # store the DB credentials in Secrets Manager
./aws/04-iam.sh       # create least-privilege roles for the ECS task
./aws/05-logs.sh      # create a CloudWatch log group
./aws/06-ecs.sh       # run the app on ECS (EC2 launch type)
open http://localhost:3100                    # the app, now served by "ECS" + "RDS"
./aws/99-cleanup.sh                           # remove everything from Floci
```

Each script is short and commented. What is real and what Floci only approximates is listed per stage in [docs/stages.md](docs/stages.md). Stages were run end to end against Floci 2.4.0 on Docker Desktop for Mac.

## Files

- `src/server.ts`, `src/db.ts`: the app
- `db/init.sql`: tables and seed data
- `Dockerfile`, `compose.yaml`: run the app locally
- `compose.floci.yaml`: run the fake AWS
- `aws/`: one script per AWS stage
- `docs/`: explanations
