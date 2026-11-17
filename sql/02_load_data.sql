\set ON_ERROR_STOP on
-- Invoke psql from the repository root; paths are client-side, relative to cwd.
-- The schema must exist and be empty. All 11 files load atomically.
BEGIN;
SET search_path TO duolingo;
SET TIME ZONE 'Asia/Kolkata';
\copy languages FROM 'seed_data/languages.csv' WITH (FORMAT csv, HEADER true)
\copy courses FROM 'seed_data/courses.csv' WITH (FORMAT csv, HEADER true)
\copy units FROM 'seed_data/units.csv' WITH (FORMAT csv, HEADER true)
\copy lessons FROM 'seed_data/lessons.csv' WITH (FORMAT csv, HEADER true)
\copy learners FROM 'seed_data/learners.csv' WITH (FORMAT csv, HEADER true)
\copy enrollments FROM 'seed_data/enrollments.csv' WITH (FORMAT csv, HEADER true)
\copy lesson_attempts FROM 'seed_data/lesson_attempts.csv' WITH (FORMAT csv, HEADER true)
\copy daily_activity FROM 'seed_data/daily_activity.csv' WITH (FORMAT csv, HEADER true)
\copy league_memberships FROM 'seed_data/league_memberships.csv' WITH (FORMAT csv, HEADER true)
\copy achievements FROM 'seed_data/achievements.csv' WITH (FORMAT csv, HEADER true)
\copy learner_achievements FROM 'seed_data/learner_achievements.csv' WITH (FORMAT csv, HEADER true)
COMMIT;
ANALYZE duolingo.languages, duolingo.courses, duolingo.units, duolingo.lessons,
        duolingo.learners, duolingo.enrollments, duolingo.lesson_attempts,
        duolingo.daily_activity, duolingo.league_memberships,
        duolingo.achievements, duolingo.learner_achievements;
