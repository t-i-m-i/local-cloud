# How it works

Written for someone who has never used Docker or AWS.

## 1. The problem Docker solves

"It works on my machine" happens because every computer has different versions of Node, PostgreSQL and settings. Docker packages a program together with everything it needs, so it runs the same everywhere.

Three words to know:

- **Image**: a frozen package (a minimal Linux, Node, our code). Like an installer. It never changes while running.
- **Container**: a running copy of an image. Like an app launched from the installer. You can run many from one image. Deleting a container deletes what it wrote, unless it wrote to a volume.
- **Dockerfile**: the recipe for building *our* image. Ours is `Dockerfile`, about ten commented lines.

## 2. The app

`src/server.ts` is a web server (Fastify). When your browser asks for `/`, it:

1. asks PostgreSQL for the events (`src/db.ts` holds the SQL),
2. builds an HTML table,
3. sends it back.

The database has two tables. `status` is a short list of states (`operational`, `degraded`, `outage`). `platform_events` has 12 rows, each with a `status_id` that points at a row in `status`. That pointer is a **foreign key**, and the SQL `JOIN` follows it to show the status name next to each event.

The app never contains the database password. It reads `DB_HOST`, `DB_USER`, `DB_PASSWORD` and so on from **environment variables**, which are settings handed to a program when it starts. That one habit is what lets the same image run on your laptop and on AWS.

It prints logs (one JSON line per request) to the terminal, called stdout/stderr. It does not write log files. Docker, and later AWS, collect whatever the program prints.

## 3. Docker Compose: two containers, one command

`compose.yaml` describes the two containers and `docker compose up` starts them.

```
 your Mac
 ┌─────────────────────────────────────────────┐
 │  Docker                                     │
 │   ┌──────────────┐        ┌──────────────┐  │
 │   │ api          │ ─────► │ db           │  │
 │   │ Fastify:3000 │ "db"   │ PostgreSQL   │  │
 │   └──────┬───────┘        └──────┬───────┘  │
 │          │                       │          │
 └──────────┼───────────────────────┼──────────┘
   localhost:3000              volume "pgdata"
```

- **Network names**: Compose puts both containers on a private network. The app reaches the database at the host name `db`, which is just the service name.
- **Port mapping** `3000:3000`: containers are sealed boxes. This line opens one door from your Mac's port 3000 to the app's port 3000.
- **Volume** `pgdata`: containers forget everything when removed. A named volume is a folder managed by Docker that survives. That is where PostgreSQL keeps its data. `docker compose down -v` deletes it, which is how you reset.
- **Seeding**: the PostgreSQL image runs every file in `/docker-entrypoint-initdb.d` once, when its data folder is empty. We put `db/init.sql` there, so tables and the 12 events appear on first start. After a reset it happens again. The SQL is also written so running it twice does no harm.
- **Health check + `depends_on`**: the database takes a few seconds to be ready. Compose runs `pg_isready` repeatedly and starts the app only when it passes. The app also retries by itself for up to 30 seconds, because AWS ECS has no such "wait for" feature.

## 4. AWS in plain words

AWS rents you computers and services by the hour, over the internet. Each service does one job:

| Service | Plain description | In this project |
| --- | --- | --- |
| **ECR** (Elastic Container Registry) | A private shelf for Docker images | Stores our app image |
| **ECS** (Elastic Container Service) | Tells machines which containers to run and keeps them running | Runs our app container |
| **EC2** | Rented virtual machines | The machines ECS uses (our "launch type") |
| **RDS** (Relational Database Service) | PostgreSQL run for you | Replaces our `db` container |
| **IAM** (Identity and Access Management) | Who may do what | Gives the container only the access it needs |
| **Secrets Manager** | A safe for passwords | Holds the DB password |
| **CloudWatch Logs** | A place to read what your programs printed | Receives the app's log lines |

**EC2 vs Fargate launch type.** ECS can run containers two ways. With **EC2** you rent and look after the machines yourself, and ECS puts containers on them. With **Fargate** AWS hides the machines. This project uses EC2, because it shows what is underneath.

**Task definition, task.** A task definition is the recipe (image, memory, ports, env vars, log destination, roles). A task is one running copy of that recipe.

**IAM and least privilege.** An IAM *role* is an identity a service can borrow. A *policy* lists allowed actions on named things, such as "read this one secret". Least privilege means giving each role the minimum. We make two roles:

- an *execution role* for ECS to pull the image, read the secret and write logs,
- a *task role* for our code. It has no permissions, because the app only talks to PostgreSQL.

## 5. Floci: fake AWS on your laptop

Real AWS needs an account and costs money. **Floci** is a program that answers the same API calls, so the `aws` command works against it by changing one setting, `AWS_ENDPOINT_URL=http://localhost:4566`. Floci itself runs in Docker (`compose.floci.yaml`), and when you ask it for an RDS database or an ECS task, it starts a real Docker container for it.

That makes it great for learning, but it is an imitation. For example, there is no actual EC2 machine, security rules are weak, and secrets are not injected into containers. [stages.md](stages.md) says exactly what is real and what is approximate.

```
 aws CLI ──► Floci :4566 ──► starts containers via Docker
                              ├─ registry   (ECR)
                              ├─ postgres   (RDS)
                              └─ our app    (ECS task) ──► logs into CloudWatch (Floci)
```

## 6. The AWS flow, end to end

1. **ECR**: build the image, push it to the registry.
2. **RDS**: create the database, load `db/init.sql`.
3. **Secrets Manager**: store the DB connection details.
4. **IAM**: create the two roles and the minimal policy.
5. **CloudWatch Logs**: create the log group.
6. **ECS**: register a machine, define the task (image from ECR, secrets as env vars, logs to CloudWatch), run it. The app now serves the page at <http://localhost:3100> from "AWS".

The application code did not change between local and AWS. Only the environment variables came from a different place. That is the main lesson.
