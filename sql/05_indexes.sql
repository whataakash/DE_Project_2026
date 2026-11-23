-- =====================================================================
-- Duolingo Database: Phase 4 Optimization Indexes (05_indexes.sql)
-- Production-grade indexes carefully chosen to accelerate workload queries
-- without incurring prohibitive write overhead.
-- =====================================================================

SET search_path TO duolingo;

-- 1. Index on courses for language pair lookups (R01)
-- Column order: (from_lang, learning_lang) matches exact equality filter.
CREATE INDEX IF NOT EXISTS idx_courses_lang_pair 
ON courses (from_lang, learning_lang) 
INCLUDE (course_id, title);

-- 2. Index on units for course navigation and unit sequencing (R01, R06, R07, R19, R24)
-- Column order: course_id for equality join/filter, unit_no for sorting without in-memory sort.
CREATE INDEX IF NOT EXISTS idx_units_course 
ON units (course_id, unit_no) 
INCLUDE (unit_id, title, cefr_level);

-- 3. Index on lessons for unit navigation and sequence order (R01, R06, R07, R19)
-- Column order: unit_id for join, lesson_no for sorting.
CREATE INDEX IF NOT EXISTS idx_lessons_unit 
ON lessons (unit_id, lesson_no) 
INCLUDE (lesson_id, lesson_type, xp_value);

-- 4. Composite covering index for learner's daily attempt XP (R04, W01, R25)
-- Column order: learner_id (equality) then started_at (range). Covers xp_earned for Index Only Scan.
CREATE INDEX IF NOT EXISTS idx_attempts_learner_started 
ON lesson_attempts (learner_id, started_at) 
INCLUDE (xp_earned);

-- 5. Composite index for weekly league leaderboards (R05, W04)
-- Column order: week_start and cohort_id (equality), weekly_xp DESC (pre-sorted rank).
CREATE INDEX IF NOT EXISTS idx_leagues_week_cohort_xp 
ON league_memberships (week_start, cohort_id, weekly_xp DESC) 
INCLUDE (learner_id);

-- 6. Partial index on completed attempts for fast "Start" button checks (R06)
-- Filters out unfinished/in-progress attempts to keep index compact.
CREATE INDEX IF NOT EXISTS idx_attempts_completed_learner_lesson 
ON lesson_attempts (learner_id, lesson_id) 
WHERE completed_at IS NOT NULL;

-- 7. Composite covering index for curriculum mistake & quit analytics (R07, R08, R19)
-- Groups by lesson_id and covers mistakes and completion timestamp for Index Only Scan.
CREATE INDEX IF NOT EXISTS idx_attempts_lesson_mistakes 
ON lesson_attempts (lesson_id) 
INCLUDE (mistakes, completed_at);

-- 8. Composite covering index for DAU analytics (R09, R15, R23)
-- Range on activity_date, covers learner_id and xp.
CREATE INDEX IF NOT EXISTS idx_daily_act_date_xp 
ON daily_activity (activity_date) 
INCLUDE (learner_id, xp);

-- 9. Partial index on streak freeze usage (R10)
-- Indexes only rows where streak freeze was consumed (~small percentage of daily rows).
CREATE INDEX IF NOT EXISTS idx_daily_act_freezes 
ON daily_activity (activity_date, learner_id) 
WHERE used_streak_freeze = true;

-- 10. Partial index on referring learners for referral funnel audit (R13)
-- Excludes NULLs; enables fast anti-join index lookup for non-referred users.
CREATE INDEX IF NOT EXISTS idx_learners_referred_by 
ON learners (referred_by) 
WHERE referred_by IS NOT NULL;

-- 11. Covering index for weekly league promotion & demotion rates (R14)
-- Filters week_start range and groups by tier; includes result.
CREATE INDEX IF NOT EXISTS idx_leagues_week_tier 
ON league_memberships (week_start, tier) 
INCLUDE (result);

-- 12. Covering index for cohort retention analysis (R15)
-- Range filter on signup date; includes learner_id.
CREATE INDEX IF NOT EXISTS idx_learners_joined 
ON learners (joined_at) 
INCLUDE (learner_id);

-- 13. Functional expression index with pattern ops for case-insensitive friend search (R16)
-- lower(username) varchar_pattern_ops allows B-tree range scan for ILIKE 'karan%'.
CREATE INDEX IF NOT EXISTS idx_learners_username_lower 
ON learners (lower(username) varchar_pattern_ops) 
INCLUDE (learner_id, country_code);

-- 14. Partial covering index for device-level perfection analytics (R17)
-- Indexes 2026 completed attempts, covers device and is_perfect.
CREATE INDEX IF NOT EXISTS idx_attempts_started_device_perfect 
ON lesson_attempts (started_at, device) 
INCLUDE (is_perfect) 
WHERE completed_at IS NOT NULL;

-- 15. Composite index for course popularity and new enrollments (R18)
-- Groups by course_id and range-filters enrolled_at.
CREATE INDEX IF NOT EXISTS idx_enrollments_course_enrolled 
ON enrollments (course_id, enrolled_at);

-- 16. Covering index for platform daily XP velocity (R20)
-- Range on started_at, covers xp_earned.
CREATE INDEX IF NOT EXISTS idx_attempts_started_xp 
ON lesson_attempts (started_at) 
INCLUDE (xp_earned);

-- 17. Reverse-order covering index for deep pagination support console (R22)
-- Enables backward Index Only Scan for ORDER BY started_at DESC.
CREATE INDEX IF NOT EXISTS idx_attempts_started_desc_covering 
ON lesson_attempts (started_at DESC) 
INCLUDE (attempt_id, learner_id, lesson_id, xp_earned);

-- 18. Composite covering index for monetisation country and subscription queries (R23)
-- Equality on country_code and IN-list on subscription, covers learner_id.
CREATE INDEX IF NOT EXISTS idx_learners_country_sub 
ON learners (country_code, subscription) 
INCLUDE (learner_id);

-- 19. Covering index on attempts learner_id for join grouping (R25)
-- Accelerates hash join / merge join with learners.
CREATE INDEX IF NOT EXISTS idx_attempts_learner_hour 
ON lesson_attempts (learner_id) 
INCLUDE (started_at);

-- 20. Covering index on enrollments for achievements bulk award (W05)
-- Supports grouping by learner_id and sum(total_xp).
CREATE INDEX IF NOT EXISTS idx_enrollments_learner_xp 
ON enrollments (learner_id) 
INCLUDE (total_xp);

-- Re-compute table statistics for optimizer cost models
ANALYZE;
