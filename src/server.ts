import Fastify from "fastify";
import { pool, EVENTS_SQL, waitForDatabase } from "./db.ts";

// The web server. logger: true makes Fastify print one JSON line per request
// and per error to stdout/stderr. Docker captures those lines (docker compose
// logs), and later CloudWatch Logs will collect them the same way.
const app = Fastify({ logger: true });

// Escape text before putting it in HTML, so data containing < or & cannot
// break the page. The data is our own seed data, but it is a good habit.
function esc(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

// GET / : the only page. Runs the SQL query and returns a plain HTML table.
// If the database fails, we log the real error (for us) and show a short
// message (for the visitor), never the raw error.
app.get("/", async (request, reply) => {
  try {
    const { rows } = await pool.query(EVENTS_SQL);
    const tableRows = rows
      .map(
        (r) =>
          `<tr><td>${r.id}</td><td>${esc(r.name)}</td><td>${esc(r.description)}</td>` +
          `<td>${esc(r.status)}</td><td>${new Date(r.occurred_at).toISOString()}</td></tr>`,
      )
      .join("");
    reply.type("text/html").send(
      `<!doctype html><html><head><meta charset="utf-8"><title>Platform events</title></head>` +
        `<body><h1>Platform events</h1><p>${rows.length} events, read from PostgreSQL.</p>` +
        `<table border="1" cellpadding="6"><tr><th>ID</th><th>Event</th><th>Description</th><th>Status</th><th>Time (UTC)</th></tr>` +
        `${tableRows}</table></body></html>`,
    );
  } catch (err) {
    request.log.error({ err }, "database query failed");
    reply.code(500).type("text/plain").send("Could not read events from the database.");
  }
});

// GET /health : answers "ok" without touching the database. Handy for checking
// that the container itself is alive.
app.get("/health", async () => "ok");

// Start-up: wait until the database answers, then listen. Host 0.0.0.0 means
// "accept connections from outside the container"; the default (localhost)
// would make the app unreachable through Docker's port mapping.
try {
  await waitForDatabase((msg) => app.log.warn(msg));
  await app.listen({ host: "0.0.0.0", port: Number(process.env.PORT ?? 3000) });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
