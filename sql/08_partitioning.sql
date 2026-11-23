-- =====================================================================
-- Duolingo Database: Phase 5 Partitioning Architecture (08_partitioning.sql)
-- Demonstrates table partitioning on high-volume lesson_attempts table
-- using RANGE partitioning on the started_at timestamp column.
-- =====================================================================

SET search_path TO duolingo;

-- ---------------------------------------------------------------------
-- 1. ARCHITECTURAL JUSTIFICATION
-- ---------------------------------------------------------------------
-- Problem: lesson_attempts is the highest volume table in the platform
-- (188k rows in seed data, ~3.6M in large data, and >70M at 100x scale).
-- Scanning or indexing a monolithic table leads to enormous B-trees that
-- exceed RAM working set sizes, along with heavy autovacuum table contention.
--
-- Solution: Declarative RANGE partitioning by started_at.
-- Benefits:
--  1. Partition Pruning: Time-bounded queries (e.g. today's attempts, June 2026)
--     scan only the relevant partition, ignoring tens of millions of older rows.
--  2. Maintenance & Archival: Old data (e.g. older than 2 years) can be detached
--     instantly via ALTER TABLE ... DETACH PARTITION or dropped with zero vacuum overhead.
--  3. Compact Local Indexes: Each partition maintains its own B-tree indexes,
--     fitting comfortably inside the PostgreSQL buffer cache.
--
-- CRITICAL PRIMARY KEY RULE FOR PARTITIONED TABLES IN POSTGRESQL:
-- PostgreSQL mandates that any UNIQUE or PRIMARY KEY constraint on a partitioned
-- table MUST include the partition key column(s). Therefore, the primary key
-- becomes composite: PRIMARY KEY (attempt_id, started_at).

-- ---------------------------------------------------------------------
-- 2. DDL: PARTITIONED TABLE DEFINITION
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS lesson_attempts_partitioned CASCADE;

CREATE TABLE lesson_attempts_partitioned (
    attempt_id BIGINT,
    learner_id INT NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    lesson_id INT NOT NULL REFERENCES lessons(lesson_id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    mistakes INT NOT NULL DEFAULT 0,
    hearts_lost INT NOT NULL DEFAULT 0,
    xp_earned INT NOT NULL DEFAULT 0,
    is_perfect BOOLEAN NOT NULL DEFAULT false,
    device VARCHAR(20) NOT NULL,
    PRIMARY KEY (attempt_id, started_at),
    CONSTRAINT chk_attempts_part_hearts CHECK (hearts_lost <= mistakes AND hearts_lost >= 0 AND mistakes >= 0),
    CONSTRAINT chk_attempts_part_completed CHECK (completed_at IS NULL OR completed_at >= started_at),
    CONSTRAINT chk_attempts_part_perfect CHECK (is_perfect = false OR (is_perfect = true AND mistakes = 0)),
    CONSTRAINT chk_attempts_part_quit CHECK ((completed_at IS NULL AND xp_earned = 0) OR completed_at IS NOT NULL),
    CONSTRAINT chk_attempts_part_device CHECK (device IN ('WEB', 'ANDROID', 'IOS'))
) PARTITION BY RANGE (started_at);

-- ---------------------------------------------------------------------
-- 3. RANGE PARTITIONS BY CALENDAR QUARTER
-- ---------------------------------------------------------------------

CREATE TABLE attempts_2025_q1 PARTITION OF lesson_attempts_partitioned
    FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-04-01 00:00:00+05:30');

CREATE TABLE attempts_2025_q2 PARTITION OF lesson_attempts_partitioned
    FOR VALUES FROM ('2025-04-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');

CREATE TABLE attempts_2025_q3 PARTITION OF lesson_attempts_partitioned
    FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2025-10-01 00:00:00+05:30');

CREATE TABLE attempts_2025_q4 PARTITION OF lesson_attempts_partitioned
    FOR VALUES FROM ('2025-10-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');

CREATE TABLE attempts_2026_q1 PARTITION OF lesson_attempts_partitioned
    FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-04-01 00:00:00+05:30');

CREATE TABLE attempts_2026_q2 PARTITION OF lesson_attempts_partitioned
    FOR VALUES FROM ('2026-04-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');

CREATE TABLE attempts_default PARTITION OF lesson_attempts_partitioned
    DEFAULT;

-- ---------------------------------------------------------------------
-- 4. LOCAL INDEXES (AUTOMATICALLY PROPAGATED TO ALL PARTITIONS)
-- ---------------------------------------------------------------------

CREATE INDEX idx_part_attempts_learner_started 
ON lesson_attempts_partitioned (learner_id, started_at) 
INCLUDE (xp_earned);

CREATE INDEX idx_part_attempts_lesson_mistakes 
ON lesson_attempts_partitioned (lesson_id) 
INCLUDE (mistakes, completed_at);

-- ---------------------------------------------------------------------
-- 5. DEMONSTRATION OF PARTITION PRUNING
-- ---------------------------------------------------------------------

-- Populate with data from June 2026 to verify pruning behavior
INSERT INTO lesson_attempts_partitioned 
SELECT * FROM lesson_attempts 
WHERE started_at >= '2026-06-01 00:00:00+05:30' AND started_at < '2026-07-01 00:00:00+05:30';

ANALYZE lesson_attempts_partitioned;

-- Query filtering for June 2026:
-- Notice in the EXPLAIN output that PostgreSQL prunes attempts_2025_q1..q4,
-- attempts_2026_q1, and attempts_default, only scanning attempts_2026_q2!
EXPLAIN (ANALYZE, BUFFERS)
SELECT started_at::date AS day, sum(xp_earned) AS total_xp
FROM lesson_attempts_partitioned
WHERE started_at >= '2026-06-01 00:00:00+05:30' AND started_at < '2026-07-01 00:00:00+05:30'
GROUP BY 1
ORDER BY day;
