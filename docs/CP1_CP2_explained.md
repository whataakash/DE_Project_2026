# CP1 and CP2 in simple words

## What CP1 did

We turned 11 CSV exports into a working PostgreSQL database for the Duolingo project.

1. **Understand the product:** explained P1–P7, who faces each problem, and why it matters. We added a proposed ICP, learner segments and metrics such as starting lessons, completing them, retention and referrals. The ICP is an assumption, not research evidence.
2. **Organise the records:** created 11 related tables for learners, courses, lessons, attempts, activity, leagues and badges. We selected number/date/time/boolean types instead of storing every value as text.
3. **Add rules:** primary keys identify records, foreign keys connect valid records, UNIQUE prevents duplicate identities, and CHECK rules reject impossible values such as negative XP. Optional fields remain nullable when the data needs that.
4. **Load and verify:** loaded all files, matched every expected row count, and checked enrollment relationships, daily/course/league XP and cohort size. Five core checks passed.
5. **Explain the design:** produced an ER diagram and documented normalization, cached totals and actual data anomalies. We preserved the supplied records and recorded inconsistencies instead of silently changing them.

**Example:** an attempt belongs to a learner and a lesson. The lesson belongs to a unit, which belongs to a course. Those links let us work out which course the learner practised.

Important files: [problem understanding](01_problem_understanding.md), [schema design](02_schema_design.md), [ER diagram](../diagrams/er_diagram.png), [table definitions](../sql/01_schema.sql), [load script](../sql/02_load_data.sql).

## What CP2 did

We measured how fast the original database queries run **before optimization**. This starting measurement is called the **baseline**.

- Ran **25 read queries** (fetch information) and **5 write queries** (insert/update information).
- Ran each query **three times**: **90 measured executions** in total.
- Used `EXPLAIN (ANALYZE, BUFFERS)` to execute the query and record its plan, execution time and buffer activity.
- Saved all three plans for every query, calculated the averages, and explained the scan types.
- Wrapped each write in a transaction and rolled it back, so benchmark inserts/updates did not persist.
- Kept the original queries and the existing 18 PK/UNIQUE indexes; no tuning indexes were added.
- Rechecked row counts and the five core integrity checks after the benchmark; they still pass.

**Average = (run 1 + run 2 + run 3) ÷ 3.** For R19, `(2893.224 + 2869.939 + 2885.707) ÷ 3 = 2882.957 ms`.

## What the measurements show

| Example | Average | Simple explanation |
|---|---:|---|
| R11: find a learner by username | 0.041 ms | An existing UNIQUE index finds one learner directly. |
| R04: fetch one learner’s daily XP | 8.493 ms | It still scans the attempts table to find that learner’s day. |
| R19: report completions and mistakes for each Spanish lesson | 2,882.957 ms (about 2.88 seconds) | It scans all attempts twice for each of 160 lessons: 320 scans. |
| R22: deep support-console page | 64.984 ms | It sorts attempts and skips 100,000 rows before returning 25. |
| R25: lessons by hour and country | 205.131 ms | It joins all attempts with learners and sorts data, using temporary disk. |

R19 accounts for about **82.8%** of the sum of all 30 query averages (**3,481.530 ms**). That sum describes this test workload, not the loading time of one app screen.

We also confirmed **R13 returns the wrong empty referral list**. Its `NOT IN` condition encounters missing referrer values (NULL), so SQL cannot treat the nonmatches as true. CP2 records the original behavior; Phase 4 must explain and fix it.

## Terms to remember

| Term | Meaning here |
|---|---|
| Primary key | A column or combination that uniquely identifies a row. |
| Foreign key | A rule requiring a referenced record to exist. |
| Normalization | Organising facts to reduce unnecessary repetition and inconsistent updates; the report explains deliberate exceptions. |
| Index | A lookup structure that can help find/order rows quickly; it also takes storage and adds write work. |
| Sequential scan | Reading a table broadly to check its rows. Often fine for small tables or whole-table reports. |
| Index scan | Following an index to locate rows in the table. |
| Index-only scan | Answering from index values when visibility checks allow it, reducing table reads. |
| Execution plan | PostgreSQL’s steps for completing a query. |
| Rollback | Undoing the transaction’s logical changes. Physical pages and caches can still change. |

## What comes next

Phase 4 will add justified indexes or rewrite queries, prove that results remain correct (and separately explain the intentional R13 bug fix), and measure the same workload again on this laptop. CP2 provides the evidence for comparing before and after. These timings are local seed-data measurements, not proof of performance with 20× data or many simultaneous users.

Full evidence: [30-query timing report](03_baseline_timings.md), [CSV summary](../benchmarks/results/baseline/summary.csv), [environment and commands](../benchmarks/results/baseline/environment.md).
