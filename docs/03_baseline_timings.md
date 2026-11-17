# Phase 3 / CP2: Baseline query timings

## Method and environment

Measured on **17 November 2026**, using **PostgreSQL 18.6**, Apple M4 / 16 GiB RAM, macOS 26.5.1. All 11 original seed files are loaded, including **188,300 lesson attempts**. See [environment and reproduction commands](../benchmarks/results/baseline/environment.md).

The unchanged supplied benchmark script ran the unchanged 30-query workload **three times per query**, using `EXPLAIN (ANALYZE, BUFFERS)`. Each cell below comes from the raw plan’s **Execution Time**, in milliseconds; planning time and client/network/display time are excluded. Means include all three runs with no excluded warm-up. No extra indexes or query rewrites were introduced: there are 18 constraint-created indexes and zero tuning indexes.

Every write ran inside `BEGIN; … ROLLBACK;`. This preserves logical rows but may warm caches or create physical dead tuples. This existing CP1 database was not a forced cold-cache benchmark; background activity was not controlled. Keep the same laptop/method for optimized comparisons. No large-dataset performance claim is made here.

## All 30 queries

Query IDs link to the full plans for all three runs. The [CSV summary](../benchmarks/results/baseline/summary.csv) also contains median/min/max. Totals sum the displayed query averages; they describe this workload, not one request or user session.

| SQL query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| [R01](../benchmarks/results/baseline/R01.txt): Course path: units and lessons of the Spanish course for English speakers, in order | READ | 0.416 | 0.210 | 0.203 | 0.276 |
| [R02](../benchmarks/results/baseline/R02.txt): Home screen: learner 1042's courses with total XP | READ | 0.076 | 0.064 | 0.060 | 0.067 |
| [R03](../benchmarks/results/baseline/R03.txt): Streak counter: learner 1042's current streak (consecutive days up to 30 June 2026, freezes count) | READ | 0.482 | 0.124 | 0.115 | 0.240 |
| [R04](../benchmarks/results/baseline/R04.txt): Daily goal ring: XP learner 1042 earned on 30 June 2026 vs their daily goal | READ | 10.801 | 7.327 | 7.352 | 8.493 |
| [R05](../benchmarks/results/baseline/R05.txt): Leagues tab: leaderboard of learner 1042's cohort for the week starting 29 June 2026 | READ | 2.633 | 1.846 | 1.873 | 2.117 |
| [R06](../benchmarks/results/baseline/R06.txt): "Start" button: the first lesson of learner 1042's Spanish course they have not completed yet | READ | 11.335 | 11.575 | 11.410 | 11.440 |
| [R07](../benchmarks/results/baseline/R07.txt): Curriculum team: lessons of the Spanish course with the most mistakes per attempt (100+ attempts) | READ | 33.780 | 32.757 | 32.568 | 33.035 |
| [R08](../benchmarks/results/baseline/R08.txt): Product analytics: quit rate per lesson type | READ | 32.869 | 35.107 | 33.190 | 33.722 |
| [R09](../benchmarks/results/baseline/R09.txt): Growth: daily active learners in June 2026 | READ | 10.342 | 8.470 | 8.287 | 9.033 |
| [R10](../benchmarks/results/baseline/R10.txt): Monetisation: streak freezes used per subscription tier in 2026 | READ | 9.067 | 8.315 | 8.289 | 8.557 |
| [R11](../benchmarks/results/baseline/R11.txt): Sign-in by username | READ | 0.057 | 0.032 | 0.035 | 0.041 |
| [R12](../benchmarks/results/baseline/R12.txt): Profile: learner 1042's achievements, newest first | READ | 0.103 | 0.096 | 0.083 | 0.094 |
| [R13](../benchmarks/results/baseline/R13.txt): Referral programme: learners who have not referred anyone yet | READ | 9.097 | 8.852 | 9.159 | 9.036 |
| [R14](../benchmarks/results/baseline/R14.txt): Leagues team: promotion and demotion rates per tier over the last 4 completed weeks | READ | 4.134 | 3.913 | 3.935 | 3.994 |
| [R15](../benchmarks/results/baseline/R15.txt): Retention: learners who joined in January 2026 and were still active in June 2026 | READ | 2.743 | 2.810 | 2.547 | 2.700 |
| [R16](../benchmarks/results/baseline/R16.txt): Friends: search learners by username starting with "Karan" | READ | 5.448 | 4.638 | 4.346 | 4.811 |
| [R17](../benchmarks/results/baseline/R17.txt): Product analytics: perfect-lesson rate per device in 2026 | READ | 25.600 | 25.398 | 26.154 | 25.717 |
| [R18](../benchmarks/results/baseline/R18.txt): Course popularity: enrollments per course, and how many started in 2026 | READ | 12.018 | 11.550 | 11.807 | 11.792 |
| [R19](../benchmarks/results/baseline/R19.txt): Curriculum report: completions and average mistakes of every lesson in the Spanish course | READ | 2893.224 | 2869.939 | 2885.707 | 2882.957 |
| [R20](../benchmarks/results/baseline/R20.txt): Growth: XP earned per day across the platform and running total, June 2026 | READ | 14.626 | 14.971 | 14.811 | 14.803 |
| [R21](../benchmarks/results/baseline/R21.txt): Streak reminders: learners active every day from 23 to 29 June but not yet on 30 June | READ | 4.669 | 4.100 | 4.349 | 4.373 |
| [R22](../benchmarks/results/baseline/R22.txt): Support console: all lesson attempts, newest first, page 4,001 (25 per page) | READ | 61.075 | 65.064 | 68.813 | 64.984 |
| [R23](../benchmarks/results/baseline/R23.txt): Monetisation: Super and Max learners in India who were active in the last 7 days of June 2026 | READ | 11.061 | 11.244 | 11.292 | 11.199 |
| [R24](../benchmarks/results/baseline/R24.txt): Curriculum team: average hearts lost per lesson, by CEFR level | READ | 44.742 | 45.673 | 43.882 | 44.766 |
| [R25](../benchmarks/results/baseline/R25.txt): Notifications team: lessons started per hour of the day, per country | READ | 199.096 | 208.126 | 208.172 | 205.131 |
| [W01](../benchmarks/results/baseline/W01.txt): Lesson start: learner 1042 starts lesson 1 | WRITE | 3.048 | 1.391 | 0.965 | 1.801 |
| [W02](../benchmarks/results/baseline/W02.txt): Lesson end: finish the most recent unfinished attempt of 30 June 2026 with 2 mistakes | WRITE | 1.427 | 1.022 | 1.049 | 1.166 |
| [W03](../benchmarks/results/baseline/W03.txt): Daily activity: add 20 XP to learner 1042's 1 July 2026 (creating the row if needed) | WRITE | 0.713 | 0.698 | 0.684 | 0.698 |
| [W04](../benchmarks/results/baseline/W04.txt): Weekly league close (week of 29 June 2026): rank everyone in their cohort and set promotion results | WRITE | 10.478 | 10.345 | 10.396 | 10.406 |
| [W05](../benchmarks/results/baseline/W05.txt): Achievements catch-up: award the "100 XP" badge to every learner who has 100+ XP but not the badge | WRITE | 74.599 | 74.479 | 73.164 | 74.081 |
| **Total (sum of all 30)** | | 3489.759 | 3470.136 | 3484.697 | **3481.530** |

## Scan types and plan interpretation

**Seq Scan** reads a table broadly; **Index Scan** uses an index and fetches matching table rows; **Index Only Scan** can answer from the index after checking visibility. Parallel scans share work across workers. Small catalogue scans are often reasonable; a scan is not automatically a problem.

The table below preserves parallel/backward and CTE scan details from the raw plans across all runs. The supplied CSV helper strips parallel/backward qualifiers and reports scan nodes from the last run only; raw plans are the authoritative evidence. INSERT operations can enforce indexes/FKs without a visible scan node in the top-level plan.

| Query | Scan nodes observed | Why it is fast or slow |
|---|---|---|
| R01 | `Seq Scan on units`<br>`Seq Scan on courses`<br>`Index Scan using lessons_unit_id_lesson_no_key on lessons` | Tiny course/unit tables are inexpensive to scan; the (unit_id, lesson_no) unique index retrieves each unit’s lessons, followed by a small sort. |
| R02 | `Index Scan using enrollments_pkey on enrollments`<br>`Seq Scan on courses` | The enrollment PK starts with learner_id, so it finds this learner’s enrollment directly; joining the 11-row course catalogue and sorting are cheap. |
| R03 | `Index Only Scan using daily_activity_pkey on daily_activity`<br>`CTE Scan on days` | The (learner_id, activity_date) PK supplies this learner’s dates in order with zero heap fetches; CTE/window processing handles only 39 dates. |
| R04 | `Index Scan using learners_pkey on learners`<br>`Parallel Seq Scan on lesson_attempts` | The learner lookup is indexed, but a parallel attempt-table scan applies learner/date filters; no selective attempt index exists and DATE(started_at) is evaluated. |
| R05 | `Index Scan using league_memberships_pkey on league_memberships`<br>`Seq Scan on league_memberships`<br>`Index Scan using learners_pkey on learners` | The PK locates the learner’s cohort, but finding its 30 members scans league_memberships; learner PK lookups and the small ranking sort are inexpensive. |
| R06 | `Index Scan using units_course_id_unit_no_key on units`<br>`Index Scan using lessons_unit_id_lesson_no_key on lessons`<br>`Seq Scan on lesson_attempts` | Curriculum lookups use unique indexes, but finding this learner’s completed attempts requires scanning the whole attempts table before the anti-join/limit can finish. |
| R07 | `Seq Scan on lesson_attempts`<br>`Seq Scan on lessons`<br>`Seq Scan on units` | Scans all attempts and joins the curriculum before grouping and filtering 100+ attempts; the top-20 result does not avoid the underlying aggregate work. |
| R08 | `Parallel Seq Scan on lesson_attempts`<br>`Seq Scan on lessons` | Parallel scan/join processes all attempts to calculate quit rates; a four-type result still needs the full input. |
| R09 | `Parallel Seq Scan on daily_activity` | Parallel sequential scan filters all daily_activity rows for positive XP in June, then aggregates dates; the PK is learner-first, not date-first. |
| R10 | `Parallel Seq Scan on daily_activity`<br>`Index Scan using learners_pkey on learners` | Parallel scan evaluates freeze/year filters on daily_activity, then performs learner PK lookups for matching rows; extracting the year adds per-row evaluation. |
| R11 | `Index Scan using learners_username_key on learners` | Exact equality on the UNIQUE username index locates one learner immediately; this is the fastest mean in the measured workload. |
| R12 | `Index Scan using learner_achievements_pkey on learner_achievements`<br>`Seq Scan on achievements` | The bridge PK starts with learner_id, retrieving four awards directly; scanning ten badge definitions and sorting four rows is cheap. |
| R13 | `Seq Scan on learners` | Two learner scans build/probe a hashed NOT IN subplan. It returns zero rows: NULL referrers make nonmatching comparisons UNKNOWN, so timing alone hides an incorrect business answer. |
| R14 | `Seq Scan on league_memberships` | Scans league memberships to select four weeks (9,552 rows in run 1), then calculates rates by tier; no week-first index exists. |
| R15 | `Seq Scan on learners`<br>`Index Scan using daily_activity_pkey on daily_activity` | Scans learners to select the January signup cohort (344 rows), then uses the daily_activity PK for each learner’s activity existence check. |
| R16 | `Index Scan using learners_username_key on learners` | Uses the username index for ordered output but applies ILIKE as a filter, rejecting 9,600 rows in run 1 before returning 20; this is not a selective prefix Index Cond. |
| R17 | `Parallel Seq Scan on lesson_attempts` | Parallel attempt scan evaluates completion/year filters, then sorts and aggregates by device; the year expression is not a selective index condition. |
| R18 | `Seq Scan on enrollments`<br>`Seq Scan on courses` | Reads all enrollments and the tiny course catalogue before counting totals and new enrollments; whole-course popularity needs broad aggregation. |
| R19 | `Index Scan using units_course_id_unit_no_key on units`<br>`Index Scan using lessons_unit_id_lesson_no_key on lessons`<br>`Seq Scan on lesson_attempts` | For 160 lessons, each of two correlated subqueries sequentially scans 188,300 attempts: 320 full attempt scans per execution, approximately 60.3 million row examinations. |
| R20 | `Parallel Seq Scan on lesson_attempts` | Parallel attempt scan evaluates started_at::date for filtering, then aggregates daily XP and computes the running total; no selective time-range access path is used. |
| R21 | `Index Only Scan using daily_activity_pkey on daily_activity` | Index-only scans avoid most heap access, but the initial date-only condition uses a learner-first PK and reads 524 shared buffers in run 1; later learner/date probes are selective. |
| R22 | `Seq Scan on lesson_attempts` | Scans all attempts, sorts by descending start time using an external merge (6,648 kB temporary disk), then discards 100,000 rows to return only 25. |
| R23 | `Parallel Seq Scan on daily_activity`<br>`Seq Scan on learners` | Parallel scans filter activity and paid Indian learners, then join and deduplicate; the available keys do not directly select these combined segments/date filters. |
| R24 | `Parallel Seq Scan on lesson_attempts`<br>`Seq Scan on lessons`<br>`Seq Scan on units` | Parallel full-attempt scan joins lessons/units before grouping hearts lost by level; a small result still summarises the whole attempt history. |
| R25 | `Seq Scan on lesson_attempts`<br>`Seq Scan on learners` | Reads and joins all 188,300 attempts with learners, extracts hours, and sorts for grouping; external merge uses 3,312 kB temporary disk in run 1. |
| W01 | No explicit scan; single-row INSERT / Result node | Inserts one row with PK/check/FK enforcement, not a table scan; FK trigger time is included and the first run is slower than later runs. |
| W02 | `Index Scan Backward using lesson_attempts_pkey on lesson_attempts`<br>`Index Scan using lesson_attempts_pkey on lesson_attempts` | A backward PK scan finds the maximum eligible unfinished attempt after filtering 8,301 rows in run 1; a direct PK lookup then updates the selected row. |
| W03 | No explicit scan; single-row INSERT / Result node | A single-row upsert checks the composite PK and learner FK; all three runs take the INSERT branch (one inserted, zero conflicts), because each execution is rolled back. |
| W04 | `Seq Scan on league_memberships` | Scans memberships, sorts/ranks the 847 current-week rows and joins back to update them; ranking, two broad reads and write work determine its cost. |
| W05 | `Seq Scan on achievements`<br>`Seq Scan on enrollments` | Scans/groups all enrollments, attempts 11,909 awards, inserts 4,016 and skips 7,893 conflicts per run; PK conflict checks and FK triggers add substantial write cost. |

## Main findings and next optimization priorities

- **R19 dominates:** 2,882.957 ms, about 82.8% of the 3481.530 ms total. The plan shows 160 loops for each of two attempt-table subplans. Investigate set-based aggregation and lesson lookup indexes in Phase 4.
- **R25:** 205.131 ms. Broad join/hour aggregation and a disk-spilling sort dominate; inspect an appropriate database summary or aggregation rewrite.
- **R22:** 64.984 ms. Deep OFFSET and external sorting do unnecessary work before returning 25 rows; investigate ordered access and pagination semantics.
- **Learner-facing R04/R06:** 8.493 / 11.440 ms on seed data. Both scan attempts despite asking about a single learner; selective access paths are a priority. The README’s final targets apply to the later large dataset, not a CP2 pass/fail test.
- **W05:** 74.081 ms. Candidate aggregation, repeated conflict handling and FK checks dominate; future read optimizations must also account for write overhead.
- **R13 correctness issue:** all three plans return zero rows because NOT IN reads NULL referrers. SQL uses UNKNOWN rather than TRUE for a nonmatching value when the list contains NULL; WHERE discards UNKNOWN. Preserve this original baseline, then fix and explain the intended business result in Phase 4 (typically with NOT EXISTS).

## Verification and scope

`python3 benchmarks/build_baseline_report.py` validates query coverage, all 90 raw execution times, run markers, mean/median/min/max consistency and regenerates this report. It reads recorded results; it does not run or simulate the benchmark.

After benchmarking, the [saved integrity verification](../benchmarks/results/baseline/integrity_after.txt) confirms all 11 expected row counts, zero violations in the five CP1 core integrity checks, and only the 18 PK/UNIQUE indexes. Previously documented data-quality anomalies remain visible. The source workload and benchmark script are unchanged.

This completes the **DE** CP2 artifacts. AP CP2 requires an ER diagram and schema for the separate AP application and is outside this repository’s work. The optimization priorities above start the analysis for Phase 4; no tuning has been applied to this baseline.
