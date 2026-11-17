\set ON_ERROR_STOP on
\pset pager off
SET search_path TO duolingo;
SET TIME ZONE 'Asia/Kolkata';
SELECT version();
-- All 11 row counts, compared to the brief.
WITH expected(table_name, expected_rows) AS (VALUES
 ('languages',10),('courses',11),('units',220),('lessons',1760),
 ('learners',30000),('enrollments',37500),('lesson_attempts',188300),
 ('daily_activity',189109),('league_memberships',28598),
 ('achievements',10),('learner_achievements',38860)),
actual AS (
 SELECT 'languages' table_name,count(*) actual_rows FROM languages UNION ALL
 SELECT 'courses',count(*) FROM courses UNION ALL
 SELECT 'units',count(*) FROM units UNION ALL SELECT 'lessons',count(*) FROM lessons UNION ALL
 SELECT 'learners',count(*) FROM learners UNION ALL SELECT 'enrollments',count(*) FROM enrollments UNION ALL
 SELECT 'lesson_attempts',count(*) FROM lesson_attempts UNION ALL
 SELECT 'daily_activity',count(*) FROM daily_activity UNION ALL
 SELECT 'league_memberships',count(*) FROM league_memberships UNION ALL
 SELECT 'achievements',count(*) FROM achievements UNION ALL
 SELECT 'learner_achievements',count(*) FROM learner_achievements)
SELECT *,actual_rows=expected_rows AS matches FROM expected JOIN actual USING(table_name) ORDER BY table_name;

-- I1: Does every attempt belong to an enrolled course?
SELECT 'I1_attempt_without_enrollment' AS check_name,count(*) AS violations
FROM lesson_attempts a JOIN lessons l USING(lesson_id) JOIN units u USING(unit_id)
WHERE NOT EXISTS (SELECT 1 FROM enrollments e WHERE e.learner_id=a.learner_id AND e.course_id=u.course_id);

-- I2: Full outer comparison catches missing summary days on either side.
WITH actual AS (
 SELECT learner_id,(started_at AT TIME ZONE 'Asia/Kolkata')::date activity_date,
 sum(xp_earned) xp,count(completed_at) lessons_completed
 FROM lesson_attempts GROUP BY 1,2)
SELECT 'I2_daily_summary_mismatch' AS check_name,count(*) AS violations
FROM actual a FULL JOIN daily_activity d USING(learner_id,activity_date)
WHERE coalesce(a.xp,0)<>coalesce(d.xp,0)
 OR coalesce(a.lessons_completed,0)<>coalesce(d.lessons_completed,0);

-- I3: The advertised cohort size is a cross-row rule.
SELECT 'I3_cohort_over_30' AS check_name,count(*) AS violations
FROM (SELECT week_start,cohort_id FROM league_memberships GROUP BY 1,2
 HAVING count(*)>30) bad;
-- A natural business expectation, not a constraint supported by this export.
SELECT 'D0_cohort_with_mixed_tiers' AS check_name,count(*) AS rows_found
FROM (SELECT week_start,cohort_id FROM league_memberships GROUP BY 1,2
 HAVING count(DISTINCT tier)>1) bad;

-- I4: Cached course XP matches source attempts.
WITH actual AS (
 SELECT a.learner_id,u.course_id,sum(a.xp_earned) xp FROM lesson_attempts a
 JOIN lessons l USING(lesson_id) JOIN units u USING(unit_id) GROUP BY 1,2)
SELECT 'I4_enrollment_xp_mismatch' AS check_name,count(*) AS violations
FROM enrollments e FULL JOIN actual a USING(learner_id,course_id)
WHERE coalesce(e.total_xp,0)<>coalesce(a.xp,0);

-- I5: League XP uses India-local started dates, Monday through Sunday.
WITH actual AS (
 SELECT learner_id,date_trunc('week',started_at AT TIME ZONE 'Asia/Kolkata')::date week_start,
 sum(xp_earned) xp FROM lesson_attempts GROUP BY 1,2)
SELECT 'I5_membership_xp_mismatch' AS check_name,count(*) AS violations
FROM league_memberships l LEFT JOIN actual a USING(learner_id,week_start)
WHERE l.weekly_xp<>coalesce(a.xp,0);

-- Temporal diagnostics: report findings without rejecting supplied rows.
SELECT 'D1_attempt_before_enrollment' AS check_name,count(*) AS rows_found
FROM lesson_attempts a JOIN lessons l USING(lesson_id) JOIN units u USING(unit_id)
JOIN enrollments e ON e.learner_id=a.learner_id AND e.course_id=u.course_id
WHERE a.started_at<e.enrolled_at;
SELECT 'D2_attempt_before_join' AS check_name,count(*) AS rows_found
FROM lesson_attempts a JOIN learners l USING(learner_id) WHERE a.started_at<l.joined_at;
SELECT 'D3_enrollment_after_export_end' AS check_name,count(*) AS rows_found
FROM enrollments WHERE enrolled_at>='2026-07-01 00:00:00+05:30';
SELECT 'D4_badge_after_export_end' AS check_name,count(*) AS rows_found
FROM learner_achievements WHERE earned_at>='2026-07-01 00:00:00+05:30';
SELECT 'D5_badge_before_join' AS check_name,count(*) AS rows_found
FROM learner_achievements a JOIN learners l USING(learner_id) WHERE a.earned_at<l.joined_at;
SELECT 'D6_referral_after_join' AS check_name,count(*) AS rows_found
FROM learners child JOIN learners parent ON parent.learner_id=child.referred_by
WHERE parent.joined_at>child.joined_at;
SELECT 'D7_attempt_before_course_launch' AS check_name,count(*) AS rows_found
FROM lesson_attempts a JOIN lessons l USING(lesson_id) JOIN units u USING(unit_id)
JOIN courses c USING(course_id) WHERE a.started_at::date<c.launched_on;
SELECT 'D8_missing_rank_by_week' AS diagnostic,week_start,count(*)
FROM league_memberships WHERE final_rank IS NULL GROUP BY week_start ORDER BY week_start;
SELECT 'D9_completion_after_export_end' AS check_name,count(*) AS rows_found
FROM lesson_attempts WHERE completed_at>='2026-07-01 00:00:00+05:30';

-- Profile valid NULLs and cohort size to support the design decisions.
SELECT 'missing_referrer' AS field,count(*) FROM learners WHERE referred_by IS NULL
UNION ALL SELECT 'missing_completion',count(*) FROM lesson_attempts WHERE completed_at IS NULL
UNION ALL SELECT 'missing_rank_and_result',count(*) FROM league_memberships WHERE final_rank IS NULL AND result IS NULL;
SELECT count(*) AS cohorts,max(members) AS largest_cohort FROM
 (SELECT count(*) AS members FROM league_memberships GROUP BY week_start,cohort_id) c;

-- Inventory confirms every index is backed by PK or UNIQUE.
SELECT c.relname table_name,i.relname index_name,con.contype constraint_type,
 pg_get_indexdef(i.oid) definition
FROM pg_index x JOIN pg_class c ON c.oid=x.indrelid
JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_class i ON i.oid=x.indexrelid
LEFT JOIN pg_constraint con ON con.conindid=i.oid AND con.contype IN ('p','u')
WHERE n.nspname='duolingo' ORDER BY c.relname,i.relname;
