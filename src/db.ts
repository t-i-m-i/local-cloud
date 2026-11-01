import pg from "pg";

// Connection pool: a small set of open connections to PostgreSQL that the app
// reuses, so each web request does not pay the cost of connecting again.
// Every setting comes from environment variables, so no password lives in the
// code. Locally Docker Compose sets them; on AWS the ECS task definition does
// (the password there comes from Secrets Manager).
export const pool = new pg.Pool({
  host: process.env.DB_HOST ?? "localhost",
  port: Number(process.env.DB_PORT ?? 5432),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// The one SQL query of the app: join each event to its status name.
// The join works because platform_events.status_id points at status.id.
export const EVENTS_SQL = `
  SELECT e.id, e.name, e.description, s.name AS status, e.occurred_at
  FROM platform_events e
  JOIN status s ON s.id = e.status_id
  ORDER BY e.occurred_at DESC
`;

// Wait-for-database helper: tries a trivial query until PostgreSQL answers.
// Compose has a health check for this, but ECS has no "wait for" feature, so
// the app protects itself. Gives up after about 30 seconds.
export async function waitForDatabase(log: (msg: string) => void): Promise<void> {
  for (let attempt = 1; attempt <= 15; attempt++) {
    try {
      await pool.query("SELECT 1");
      return;
    } catch (err) {
      log(`database not ready (attempt ${attempt}/15): ${(err as Error).message}`);
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
  throw new Error("database never became ready");
}
