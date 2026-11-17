\set ON_ERROR_STOP on
-- Run once on an empty database. No tuning indexes: only PK/UNIQUE indexes.
BEGIN;
CREATE SCHEMA duolingo;
SET search_path TO duolingo;
SET TIME ZONE 'Asia/Kolkata';

CREATE TABLE languages (
    language_code varchar(2) PRIMARY KEY CHECK (language_code ~ '^[a-z]{2}$'),
    language_name text NOT NULL UNIQUE CHECK (btrim(language_name) <> '')
);
CREATE TABLE courses (
    course_id integer PRIMARY KEY CHECK (course_id > 0),
    from_lang varchar(2) NOT NULL REFERENCES languages ON DELETE RESTRICT,
    learning_lang varchar(2) NOT NULL REFERENCES languages ON DELETE RESTRICT,
    title text NOT NULL CHECK (btrim(title) <> ''),
    launched_on date NOT NULL,
    UNIQUE (from_lang, learning_lang),
    CHECK (from_lang <> learning_lang)
);
CREATE TABLE units (
    unit_id integer PRIMARY KEY CHECK (unit_id > 0),
    course_id integer NOT NULL REFERENCES courses ON DELETE RESTRICT,
    unit_no smallint NOT NULL CHECK (unit_no > 0),
    title text NOT NULL CHECK (btrim(title) <> ''),
    cefr_level varchar(2) NOT NULL CHECK (cefr_level IN ('A1','A2','B1','B2','C1','C2')),
    UNIQUE (course_id, unit_no)
);
CREATE TABLE lessons (
    lesson_id integer PRIMARY KEY CHECK (lesson_id > 0),
    unit_id integer NOT NULL REFERENCES units ON DELETE RESTRICT,
    lesson_no smallint NOT NULL CHECK (lesson_no > 0),
    lesson_type text NOT NULL CHECK (lesson_type IN ('LEARN','PRACTICE','STORY','LEGENDARY')),
    xp_value smallint NOT NULL CHECK (xp_value > 0),
    UNIQUE (unit_id, lesson_no)
);
CREATE TABLE learners (
    learner_id integer PRIMARY KEY CHECK (learner_id > 0),
    username varchar(64) NOT NULL UNIQUE CHECK (username ~ '^[A-Za-z0-9_]{3,64}$'),
    email text NOT NULL UNIQUE CHECK (email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'),
    country_code varchar(2) NOT NULL CHECK (country_code ~ '^[A-Z]{2}$'),
    daily_goal_xp smallint NOT NULL CHECK (daily_goal_xp IN (10,20,30,50)),
    subscription text NOT NULL DEFAULT 'FREE' CHECK (subscription IN ('FREE','SUPER','MAX')),
    referred_by integer REFERENCES learners ON DELETE SET NULL,
    joined_at timestamptz NOT NULL,
    CHECK (referred_by IS NULL OR referred_by <> learner_id)
);
CREATE TABLE enrollments (
    learner_id integer NOT NULL REFERENCES learners ON DELETE CASCADE,
    course_id integer NOT NULL REFERENCES courses ON DELETE RESTRICT,
    enrolled_at timestamptz NOT NULL,
    total_xp integer NOT NULL DEFAULT 0 CHECK (total_xp >= 0),
    is_active boolean NOT NULL DEFAULT true,
    PRIMARY KEY (learner_id, course_id)
);
CREATE TABLE lesson_attempts (
    attempt_id bigint PRIMARY KEY CHECK (attempt_id > 0),
    learner_id integer NOT NULL REFERENCES learners ON DELETE CASCADE,
    lesson_id integer NOT NULL REFERENCES lessons ON DELETE RESTRICT,
    started_at timestamptz NOT NULL,
    completed_at timestamptz,
    mistakes smallint NOT NULL DEFAULT 0 CHECK (mistakes >= 0),
    hearts_lost smallint NOT NULL DEFAULT 0 CHECK (hearts_lost BETWEEN 0 AND 5),
    xp_earned smallint NOT NULL DEFAULT 0 CHECK (xp_earned >= 0),
    is_perfect boolean NOT NULL DEFAULT false,
    device text NOT NULL CHECK (device IN ('ANDROID','IOS','WEB')),
    CHECK (completed_at IS NULL OR completed_at >= started_at),
    CHECK (hearts_lost <= mistakes),
    CHECK (NOT is_perfect OR (mistakes = 0 AND completed_at IS NOT NULL)),
    CHECK (completed_at IS NOT NULL OR (xp_earned = 0 AND NOT is_perfect))
);
CREATE TABLE daily_activity (
    learner_id integer NOT NULL REFERENCES learners ON DELETE CASCADE,
    activity_date date NOT NULL,
    xp integer NOT NULL DEFAULT 0 CHECK (xp >= 0),
    lessons_completed integer NOT NULL DEFAULT 0 CHECK (lessons_completed >= 0),
    used_streak_freeze boolean NOT NULL DEFAULT false,
    PRIMARY KEY (learner_id, activity_date),
    CHECK (NOT used_streak_freeze OR (xp = 0 AND lessons_completed = 0))
);
CREATE TABLE league_memberships (
    learner_id integer NOT NULL REFERENCES learners ON DELETE CASCADE,
    week_start date NOT NULL CHECK (extract(isodow FROM week_start) = 1),
    tier text NOT NULL CHECK (tier IN ('BRONZE','SILVER','GOLD','SAPPHIRE','RUBY','EMERALD','AMETHYST','DIAMOND')),
    cohort_id integer NOT NULL CHECK (cohort_id > 0),
    weekly_xp integer NOT NULL DEFAULT 0 CHECK (weekly_xp >= 0),
    final_rank smallint CHECK (final_rank BETWEEN 1 AND 30),
    result text CHECK (result IN ('PROMOTED','DEMOTED','STAYED')),
    PRIMARY KEY (learner_id, week_start),
    CHECK ((final_rank IS NULL) = (result IS NULL))
);
CREATE TABLE achievements (
    achievement_id integer PRIMARY KEY CHECK (achievement_id > 0),
    code text NOT NULL UNIQUE CHECK (code ~ '^[A-Z][A-Z0-9_]*$'),
    name text NOT NULL CHECK (btrim(name) <> '')
);
CREATE TABLE learner_achievements (
    learner_id integer NOT NULL REFERENCES learners ON DELETE CASCADE,
    achievement_id integer NOT NULL REFERENCES achievements ON DELETE RESTRICT,
    earned_at timestamptz NOT NULL,
    PRIMARY KEY (learner_id, achievement_id)
);
COMMIT;
