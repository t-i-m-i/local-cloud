-- Schema + seed data. Safe to run more than once: every statement checks
-- whether the thing already exists, so a second run changes nothing.
-- Locally, the postgres image runs this file automatically on the FIRST start
-- of an empty database (see compose.yaml). On AWS (RDS) a script runs it.

-- "status" is a small lookup table: one row per possible health state.
CREATE TABLE IF NOT EXISTS status (
  id    SERIAL PRIMARY KEY,
  name  TEXT NOT NULL UNIQUE
);

-- "platform_events" holds the things that happened. Each event points at one
-- status through status_id (a foreign key), so the database refuses an event
-- with a status that does not exist.
CREATE TABLE IF NOT EXISTS platform_events (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  description  TEXT NOT NULL,
  status_id    INTEGER NOT NULL REFERENCES status (id),
  occurred_at  TIMESTAMPTZ NOT NULL
);

-- Seed the statuses. Fixed ids + ON CONFLICT make re-running harmless.
INSERT INTO status (id, name) VALUES
  (1, 'operational'),
  (2, 'degraded'),
  (3, 'outage')
ON CONFLICT DO NOTHING;

-- Seed exactly 12 events (fixed ids again, so no duplicates on re-run).
INSERT INTO platform_events (id, name, description, status_id, occurred_at) VALUES
  (1,  'API deploy',            'Version 1.4.0 rolled out to all regions',        1, '2026-10-01 09:00+00'),
  (2,  'Database backup',       'Nightly backup finished in 14 minutes',          1, '2026-10-02 02:30+00'),
  (3,  'Slow search',           'Search latency above 2s for some users',         2, '2026-10-03 13:15+00'),
  (4,  'Certificate renewal',   'TLS certificate renewed automatically',          1, '2026-10-05 07:00+00'),
  (5,  'Queue backlog',         'Email queue delayed by about 20 minutes',        2, '2026-10-07 16:40+00'),
  (6,  'Payment provider down', 'Card payments failing at the provider',          3, '2026-10-09 11:05+00'),
  (7,  'Payment provider back', 'Provider recovered, payments processing again',  1, '2026-10-09 12:20+00'),
  (8,  'Cache restart',         'Cache nodes restarted during maintenance',       1, '2026-10-12 03:00+00'),
  (9,  'Login errors',          'Intermittent 500 errors on the login page',      2, '2026-10-15 08:45+00'),
  (10, 'Region outage',         'One cloud region unreachable for 35 minutes',    3, '2026-10-18 21:10+00'),
  (11, 'Failover complete',     'Traffic moved to the healthy region',            1, '2026-10-18 21:45+00'),
  (12, 'Disk usage warning',    'Log volume at 85%, cleanup scheduled',           2, '2026-10-22 10:30+00')
ON CONFLICT DO NOTHING;
