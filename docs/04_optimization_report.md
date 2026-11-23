# Phase 4: Query Optimization Report

**Course:** Database Management Systems  
**Project:** Duolingo Language Learning Database  
**Team No.:** T0117 (Section B)  
**Group Lead:** Akash Pansari | **Members:** Aayush Kumar, Varun Jaiswal, Vedaant Chopra  
**Database:** `duolingo_db` (PostgreSQL 18.6)  

---

## 1. Optimization Results Table

Improvement formula: `Improvement % = (Before - After) / Before * 100`

| Query | Before (ms) | Problem Found in Baseline Plan | Optimization Applied | After (ms) | Improvement | Same Result? |
| :--- | ---:| :--- | :--- | ---:| ---:| :---: |
| **R01** | 0.175 | Sequential scan on units and lessons | Covering index `idx_lessons_unit` and `idx_units_course` | 0.103 | 41.14% | ✅ |
| **R02** | 0.055 | Sequential scan on small courses catalog | PK Index scan already fast; cached catalog scan | 0.036 | 34.55% | ✅ |
| **R03** | 0.078 | Composite PK index scan with sort node | Index Only Scan on `daily_activity_pkey` | 0.055 | 29.49% | ✅ |
| **R04** | 4.294 | Non-sargable `DATE(started_at)` forced full table scan on 188k attempts | Rewrote to sargable timestamp range; covering index `idx_attempts_learner_started` | 0.039 | **99.09%** | ✅ |
| **R05** | 1.097 | Subquery used PK, but cohort retrieval scanned league table; sort node | Composite index `idx_leagues_week_cohort_xp` with pre-sorted `weekly_xp DESC` | 0.085 | **92.25%** | ✅ |
| **R06** | 5.801 | `NOT EXISTS` subquery executed repeated Seq Scans on `lesson_attempts` | Partial index `idx_attempts_completed_learner_lesson` on completed attempts | 0.073 | **98.74%** | ✅ |
| **R07** | 14.817 | Sequential scan on attempts with heap tuple fetch for mistakes | Composite covering index `idx_attempts_lesson_mistakes` for Index Only Scan | 6.126 | 58.65% | ✅ |
| **R08** | 17.154 | Full table scan on attempts with conditional filter | Reads from buffer cache; index support | 16.766 | 2.26% | ✅ |
| **R09** | 4.359 | Sequential scan across 189k rows of daily activity | Covering date index `idx_daily_act_date_xp` | 0.954 | 78.11% | ✅ |
| **R10** | 4.460 | Scanned full `daily_activity` table filtering `used_streak_freeze` | Partial index `idx_daily_act_freezes` on freeze rows | 0.946 | 78.79% | ✅ |
| **R11** | 0.031 | Direct unique index lookup | Retained optimal unique B-tree scan | 0.029 | 6.45% | ✅ |
| **R12** | 0.039 | Direct PK index lookup on learner achievements | Retained fast PK index scan | 0.045 | -15.38% | ✅ |
| **R13** | 4.362 | **SQL NULL Bug:** `NOT IN (SELECT referred_by)` evaluated to UNKNOWN, returning **0 rows** | Rewrote with `NOT EXISTS` + partial index `idx_learners_referred_by`; now returns **24,268 rows**! | 3.511 | 19.51% | **Fixed Bug** |
| **R14** | 1.786 | Sequential scan over all league weeks | Composite index `idx_leagues_week_cohort_xp` bitmap scan | 1.692 | 5.26% | ✅ |
| **R15** | 1.323 | Scanned all 30k learners to find January signups | Covering index `idx_learners_joined` on signup timestamp | 0.231 | 82.54% | ✅ |
| **R16** | 2.806 | Case-insensitive prefix search scanned username index without pattern ops | Expression pattern index `idx_learners_username_lower` using `varchar_pattern_ops` | 2.388 | 14.89% | ✅ |
| **R17** | 14.295 | Non-sargable `EXTRACT(YEAR)` forced sequential scan on 188k attempts | Sargable timestamp range rewrite + partial covering index `idx_attempts_started_device_perfect` | 5.830 | 59.22% | ✅ |
| **R18** | 6.064 | Sequential scan over 37.5k enrollments | Index `idx_enrollments_course_enrolled` | 5.885 | 2.95% | ✅ |
| **R19** | 1444.683 | **Double correlated subqueries** in SELECT projection caused 3.5M+ tuple scans | Rewrote subqueries to single `LEFT JOIN` with aggregate grouping + covering index | 6.298 | **99.56%** | ✅ |
| **R20** | 14.646 | Full table scan on attempts with date typecast | Sargable range rewrite + covering index `idx_attempts_started_xp` | 2.239 | 84.71% | ✅ |
| **R21** | 2.305 | Scanned daily activity rows across week | Index Only Scan using `idx_daily_act_date_xp` | 0.667 | 71.06% | ✅ |
| **R22** | 31.051 | `OFFSET 100000` scanned and fetched heap tuples for 100,025 rows | Backward Index Only Scan using covering index `idx_attempts_started_desc_covering` | 6.287 | 79.75% | ✅ |
| **R23** | 5.705 | Sequential scans on both daily activity and learners | Index Only Scan using `idx_daily_act_date_xp` and `idx_learners_country_sub` | 0.654 | 88.54% | ✅ |
| **R24** | 22.978 | Multi-table joins across attempts, lessons, units | Reads via buffer cache | 23.599 | -2.70% | ✅ |
| **R25** | 112.465 | Heavy aggregation across 188k attempts and 30k learners | Bound by CPU grouping of 188k rows; index support | 110.360 | 1.87% | ✅ |
| **W01** | 0.514 | Single row insert | Fast insert into heap and indexes | 0.640 | -24.51% | ✅ |
| **W02** | 0.532 | Subquery searched unindexed attempts | Subquery accelerated via `idx_attempts_started_xp` | 0.279 | 47.56% | ✅ |
| **W03** | 0.352 | Single row upsert | Maintained sub-millisecond latency | 0.467 | -32.67% | ✅ |
| **W04** | 4.789 | Weekly league close batch update | Bitmap index scan accelerated subquery | 6.118 | -27.75% | ✅ |
| **W05** | 34.249 | Scanned enrollments and achievements | Accelerated by `idx_enrollments_learner_xp` | 33.015 | 3.60% | ✅ |
| **Total** | **1,752.464** | | | **235.417** | **86.57%** | ✅ |

---

## 2. In-Depth Analysis of the Wrong-Result Query (R13)

### The Defect (Problem Statement P5)
In the original `workload_30.sql`:
```sql
SELECT l.learner_id, l.username
FROM learners l
WHERE l.learner_id NOT IN (SELECT r.referred_by FROM learners r);
```
When executed, this query returned **0 rows**, directly causing Growth team ticket P5 ("The referral programme list of learners who haven't referred anyone is always empty").

### The Root Cause: SQL Three-Valued Logic
The `learners.referred_by` column contains `NULL` for organic signups (signups without a referrer). In standard SQL:
- An expression `x NOT IN (1, 2, NULL)` expands logically to:
  `NOT (x = 1 OR x = 2 OR x = NULL)`
- Because `x = NULL` evaluates to `UNKNOWN`, the whole disjunction becomes `UNKNOWN`.
- `NOT (UNKNOWN)` is `UNKNOWN`.
- SQL `WHERE` clauses discard any row that evaluates to `UNKNOWN` or `FALSE`.
- Consequently, if even a single `NULL` exists in the subquery result set, `NOT IN` evaluates to `UNKNOWN` for every single candidate row in the outer table, producing an empty result set!

### The Solution & Proof
We rewrote the query using `NOT EXISTS`, which relies on two-valued truth semantics and is immune to NULL evaluation:
```sql
SELECT l.learner_id, l.username
FROM learners l
WHERE NOT EXISTS (SELECT 1 FROM learners r WHERE r.referred_by = l.learner_id);
```
Furthermore, we created a partial index on non-null referrers:
```sql
CREATE INDEX idx_learners_referred_by ON learners (referred_by) WHERE referred_by IS NOT NULL;
```
**Outcome:** The query executes an Index Only anti-join in **3.51 ms**, correctly returning all **24,268** learners who have never referred anyone!

---

## 3. Before/After Execution Plans for Top 5 Improvements

### 1. Query R19: Curriculum Completion & Mistake Report (230× Speedup)
- **Before (1,444.68 ms):**
  Two independent correlated subqueries evaluated for every lesson of course 1:
  `SubPlan 1 -> Seq Scan on lesson_attempts (cost=0.00..3856.75 rows=1 width=8)`
  `SubPlan 2 -> Seq Scan on lesson_attempts (cost=0.00..3856.75 rows=1 width=32)`
  Total cost: `> 1,200,000`. Over 3.5 million rows evaluated sequentially.
- **After (6.30 ms):**
  Replaced subqueries with a set-based `LEFT JOIN` and single `GROUP BY`, accompanied by `idx_attempts_lesson_mistakes`:
  `-> Index Only Scan using idx_attempts_lesson_mistakes on lesson_attempts (cost=0.42..3520.10)`
  `-> Hash Aggregate (cost=3612.00..3628.00)`

### 2. Query R04: Daily Goal Ring (110× Speedup)
- **Before (4.29 ms):**
  `Filter: (date(started_at) = '2026-06-30'::date)` forced PostgreSQL to perform a `Seq Scan on lesson_attempts` across all 188,300 rows.
- **After (0.039 ms):**
  Rewritten to sargable timestamp range `started_at >= '2026-06-30' AND started_at < '2026-07-01'` and indexed with `idx_attempts_learner_started`:
  `-> Index Only Scan using idx_attempts_learner_started on lesson_attempts (cost=0.42..8.45 rows=2)`
  Heap pages visited: 0. Direct index lookup in 39 microseconds!

### 3. Query R06: "Start" Button Next Unfinished Lesson (79× Speedup)
- **Before (5.80 ms):**
  `NOT EXISTS` evaluated via `Seq Scan on lesson_attempts` filtering on learner and lesson ID.
- **After (0.073 ms):**
  Supported by partial index `idx_attempts_completed_learner_lesson`:
  `-> Index Only Scan using idx_attempts_completed_learner_lesson on lesson_attempts (cost=0.29..4.31)`
  Stops immediately at the first uncompleted lesson due to `LIMIT 1`.

### 4. Query R05: Leagues Tab Leaderboard (13× Speedup)
- **Before (1.097 ms):**
  Subquery found cohort, but retrieving members required `Seq Scan on league_memberships` followed by a Sort node (`Sort Method: quicksort`).
- **After (0.085 ms):**
  Covering index `idx_leagues_week_cohort_xp` stores tuples pre-sorted by `(week_start, cohort_id, weekly_xp DESC)`.
  The query engine uses an Index Only Scan and evaluates `RANK()` via window function without any Sort operation!

### 5. Query R22: Support Console Deep Pagination (5× Speedup)
- **Before (31.05 ms):**
  `OFFSET 100000 LIMIT 25` forced a sequential scan and sort of 100,025 physical heap tuples.
- **After (6.29 ms):**
  Covering reverse-order index `idx_attempts_started_desc_covering` contains all projection columns (`attempt_id, learner_id, lesson_id, xp_earned`).
  PostgreSQL executes a backward Index Only Scan, skipping heap access completely.

---

## 4. Write Overhead & Index Storage Analysis

### 4.1 Write Overhead Evaluation
Indexes require maintenance on write operations (`INSERT`, `UPDATE`, `DELETE`). We benchmarked write operations before and after indexing:

| Write Query | Operation | Baseline (ms) | Optimized (ms) | Overhead | Assessment |
| :--- | :--- | ---:| ---:| ---:| :--- |
| **W01** | `INSERT INTO lesson_attempts` | 0.514 | 0.640 | +0.126 ms (+24.5%) | Negligible; 0.64 ms remains well below the 5 ms SLA. |
| **W02** | `UPDATE lesson_attempts` | 0.532 | 0.279 | **-0.253 ms (Faster!)** | Subquery finding target attempt was sped up by `idx_attempts_started_xp`. |
| **W03** | `UPSERT daily_activity` | 0.352 | 0.467 | +0.115 ms (+32.6%) | Absolute time remains under 0.5 ms; negligible impact. |
| **W04** | Batch update `league_memberships` | 4.789 | 6.118 | +1.329 ms (+27.7%) | Batch background job executed once per week; SLA target is < 1,000 ms. |
| **W05** | Bulk insert badges into `learner_achievements` | 34.249 | 33.015 | -1.234 ms | Enrollments pre-filter was accelerated by covering index. |

**Conclusion:** Write overhead is minimal. All OLTP write operations complete in under 1 ms, easily satisfying the 5 ms user-facing SLA.

### 4.2 Index Storage Overhead
Index sizes relative to underlying tables:

| Table Name | Table Size | Total Index Size | Index / Table Ratio | Commentary |
| :--- | ---:| ---:| ---:| :--- |
| `lesson_attempts` | 16 MB | 38.8 MB | 242% | High ratio justified: table is the primary operational workload core. |
| `daily_activity` | 9.9 MB | 10.0 MB | 101% | Compact indexes supporting DAU, streaks, and freezes. |
| `learners` | 3.1 MB | 6.5 MB | 208% | Includes username and email unique constraints + pattern ops. |
| `enrollments` | 1.9 MB | 2.8 MB | 148% | Balanced composite keys for course progression. |
| `league_memberships`| 2.2 MB | 2.8 MB | 127% | Efficient pre-sorted leaderboard indexes. |
| Catalogs (`units`, etc.) | < 0.2 MB | < 0.2 MB | — | Tiny memory footprint; permanently resident in RAM. |

---

## 5. Queries That Could Not Be Materially Sped Up

1. **R25 (Lessons started per hour per country — 110.36 ms):**
   - *Reason:* Must read all 188,300 attempts and join with 30,000 learners to extract `EXTRACT(HOUR FROM started_at)`.
   - *Remedy:* An analytical report that does not require live OLTP execution; ideal candidate for an hourly pre-aggregated summary table or materialized view.
2. **R24 (Average hearts lost by CEFR level — 23.60 ms):**
   - *Reason:* Calculates aggregate metrics across three joined tables with no selective `WHERE` filter. Reading the entire catalog is mathematically mandatory.
3. **R08 (Quit rate per lesson type — 16.77 ms):**
   - *Reason:* Full aggregation across the complete lifecycle of every attempt in the database.
