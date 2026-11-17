#!/usr/bin/env python3
"""Validate 90 real execution times and build the CP2 report; never invent timings."""
from pathlib import Path
from decimal import Decimal, ROUND_HALF_UP
import csv
import re

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'benchmarks/results/baseline'
expected = [f'R{i:02}' for i in range(1, 26)] + [f'W{i:02}' for i in range(1, 6)]
rows = list(csv.DictReader((BASE / 'summary.csv').open()))
assert [r['query_id'] for r in rows] == expected, 'Missing/duplicate/out-of-order query IDs'
workload = (ROOT / 'queries/workload_30.sql').read_text()
labels = dict(re.findall(r'^-- @(\w+)\n-- ([^\n]+)', workload, re.M))
reasons = {
'R01': 'Tiny course/unit tables are inexpensive to scan; the (unit_id, lesson_no) unique index retrieves each unit’s lessons, followed by a small sort.',
'R02': 'The enrollment PK starts with learner_id, so it finds this learner’s enrollment directly; joining the 11-row course catalogue and sorting are cheap.',
'R03': 'The (learner_id, activity_date) PK supplies this learner’s dates in order with zero heap fetches; CTE/window processing handles only 39 dates.',
'R04': 'The learner lookup is indexed, but a parallel attempt-table scan applies learner/date filters; no selective attempt index exists and DATE(started_at) is evaluated.',
'R05': 'The PK locates the learner’s cohort, but finding its 30 members scans league_memberships; learner PK lookups and the small ranking sort are inexpensive.',
'R06': 'Curriculum lookups use unique indexes, but finding this learner’s completed attempts requires scanning the whole attempts table before the anti-join/limit can finish.',
'R07': 'Scans all attempts and joins the curriculum before grouping and filtering 100+ attempts; the top-20 result does not avoid the underlying aggregate work.',
'R08': 'Parallel scan/join processes all attempts to calculate quit rates; a four-type result still needs the full input.',
'R09': 'Parallel sequential scan filters all daily_activity rows for positive XP in June, then aggregates dates; the PK is learner-first, not date-first.',
'R10': 'Parallel scan evaluates freeze/year filters on daily_activity, then performs learner PK lookups for matching rows; extracting the year adds per-row evaluation.',
'R11': 'Exact equality on the UNIQUE username index locates one learner immediately; this is the fastest mean in the measured workload.',
'R12': 'The bridge PK starts with learner_id, retrieving four awards directly; scanning ten badge definitions and sorting four rows is cheap.',
'R13': 'Two learner scans build/probe a hashed NOT IN subplan. It returns zero rows: NULL referrers make nonmatching comparisons UNKNOWN, so timing alone hides an incorrect business answer.',
'R14': 'Scans league memberships to select four weeks (9,552 rows in run 1), then calculates rates by tier; no week-first index exists.',
'R15': 'Scans learners to select the January signup cohort (344 rows), then uses the daily_activity PK for each learner’s activity existence check.',
'R16': 'Uses the username index for ordered output but applies ILIKE as a filter, rejecting 9,600 rows in run 1 before returning 20; this is not a selective prefix Index Cond.',
'R17': 'Parallel attempt scan evaluates completion/year filters, then sorts and aggregates by device; the year expression is not a selective index condition.',
'R18': 'Reads all enrollments and the tiny course catalogue before counting totals and new enrollments; whole-course popularity needs broad aggregation.',
'R19': 'For 160 lessons, each of two correlated subqueries sequentially scans 188,300 attempts: 320 full attempt scans per execution, approximately 60.3 million row examinations.',
'R20': 'Parallel attempt scan evaluates started_at::date for filtering, then aggregates daily XP and computes the running total; no selective time-range access path is used.',
'R21': 'Index-only scans avoid most heap access, but the initial date-only condition uses a learner-first PK and reads 524 shared buffers in run 1; later learner/date probes are selective.',
'R22': 'Scans all attempts, sorts by descending start time using an external merge (6,648 kB temporary disk), then discards 100,000 rows to return only 25.',
'R23': 'Parallel scans filter activity and paid Indian learners, then join and deduplicate; the available keys do not directly select these combined segments/date filters.',
'R24': 'Parallel full-attempt scan joins lessons/units before grouping hearts lost by level; a small result still summarises the whole attempt history.',
'R25': 'Reads and joins all 188,300 attempts with learners, extracts hours, and sorts for grouping; external merge uses 3,312 kB temporary disk in run 1.',
'W01': 'Inserts one row with PK/check/FK enforcement, not a table scan; FK trigger time is included and the first run is slower than later runs.',
'W02': 'A backward PK scan finds the maximum eligible unfinished attempt after filtering 8,301 rows in run 1; a direct PK lookup then updates the selected row.',
'W03': 'A single-row upsert checks the composite PK and learner FK; all three runs take the INSERT branch (one inserted, zero conflicts), because each execution is rolled back.',
'W04': 'Scans memberships, sorts/ranks the 847 current-week rows and joins back to update them; ranking, two broad reads and write work determine its cost.',
'W05': 'Scans/groups all enrollments, attempts 11,909 awards, inserts 4,016 and skips 7,893 conflicts per run; PK conflict checks and FK triggers add substantial write cost.'
}
quantum = Decimal('0.001')
def fmt(value):
    return str(value.quantize(quantum, rounding=ROUND_HALF_UP))

data = []
for row in rows:
    qid = row['query_id']
    assert row['type'] == ('WRITE' if qid.startswith('W') else 'READ')
    raw = (BASE / f'{qid}.txt').read_text()
    assert re.findall(rf'^=== {qid} run (\d+) ===$', raw, re.M) == ['1', '2', '3'], qid
    times = [Decimal(v) for v in re.findall(r'^Execution Time: ([0-9.]+) ms$', raw, re.M)]
    assert len(times) == 3, (qid, 'Expected three execution times')
    avg = sum(times) / 3
    assert abs(avg - Decimal(row['avg_ms'])) <= Decimal('0.0005'), (qid, 'Average mismatch')
    assert min(times) == Decimal(row['min_ms']), qid
    assert max(times) == Decimal(row['max_ms']), qid
    assert sorted(times)[1] == Decimal(row['median_ms']), qid
    scans = list(dict.fromkeys(re.findall(
        r'(?:Parallel )?(?:Index Only Scan|Index Scan|Seq Scan|Bitmap Heap Scan|Bitmap Index Scan|CTE Scan)(?: Backward)?(?: using \S+)? on \S+', raw)))
    data.append((row, times, scans))

lines = ['# Phase 3 / CP2: Baseline query timings', '',
'## Method and environment', '',
'Measured on **17 November 2026**, using **PostgreSQL 18.6**, Apple M4 / 16 GiB RAM, macOS 26.5.1. All 11 original seed files are loaded, including **188,300 lesson attempts**. See [environment and reproduction commands](../benchmarks/results/baseline/environment.md).', '',
'The unchanged supplied benchmark script ran the unchanged 30-query workload **three times per query**, using `EXPLAIN (ANALYZE, BUFFERS)`. Each cell below comes from the raw plan’s **Execution Time**, in milliseconds; planning time and client/network/display time are excluded. Means include all three runs with no excluded warm-up. No extra indexes or query rewrites were introduced: there are 18 constraint-created indexes and zero tuning indexes.', '',
'Every write ran inside `BEGIN; … ROLLBACK;`. This preserves logical rows but may warm caches or create physical dead tuples. This existing CP1 database was not a forced cold-cache benchmark; background activity was not controlled. Keep the same laptop/method for optimized comparisons. No large-dataset performance claim is made here.', '',
'## All 30 queries', '',
'Query IDs link to the full plans for all three runs. The [CSV summary](../benchmarks/results/baseline/summary.csv) also contains median/min/max. Totals sum the displayed query averages; they describe this workload, not one request or user session.', '',
'| SQL query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |',
'|---|---|---:|---:|---:|---:|']
for row, times, scans in data:
    qid = row['query_id']
    label = labels[qid].replace('|', '\\|')
    lines.append(f'| [{qid}](../benchmarks/results/baseline/{qid}.txt): {label} | {row["type"]} | '+ ' | '.join(fmt(t) for t in times)+f' | {row["avg_ms"]} |')
totals = [sum(times[i] for _, times, _ in data) for i in range(3)]
total_avg = sum(Decimal(row['avg_ms']) for row, _, _ in data)
lines.append('| **Total (sum of all 30)** | | '+' | '.join(fmt(t) for t in totals)+f' | **{fmt(total_avg)}** |')
lines += ['', '## Scan types and plan interpretation', '',
'**Seq Scan** reads a table broadly; **Index Scan** uses an index and fetches matching table rows; **Index Only Scan** can answer from the index after checking visibility. Parallel scans share work across workers. Small catalogue scans are often reasonable; a scan is not automatically a problem.', '',
'The table below preserves parallel/backward and CTE scan details from the raw plans across all runs. The supplied CSV helper strips parallel/backward qualifiers and reports scan nodes from the last run only; raw plans are the authoritative evidence. INSERT operations can enforce indexes/FKs without a visible scan node in the top-level plan.', '',
'| Query | Scan nodes observed | Why it is fast or slow |', '|---|---|---|']
for row, times, scans in data:
    qid = row['query_id']
    scantext = '<br>'.join(f'`{s}`' for s in scans) if scans else 'No explicit scan; single-row INSERT / Result node'
    lines.append(f'| {qid} | {scantext} | {reasons[qid]} |')
share = Decimal(next(r['avg_ms'] for r in rows if r['query_id']=='R19'))/total_avg*100
lines += ['', '## Main findings and next optimization priorities', '',
f'- **R19 dominates:** 2,882.957 ms, about {share.quantize(Decimal("0.1"))}% of the {fmt(total_avg)} ms total. The plan shows 160 loops for each of two attempt-table subplans. Investigate set-based aggregation and lesson lookup indexes in Phase 4.',
'- **R25:** 205.131 ms. Broad join/hour aggregation and a disk-spilling sort dominate; inspect an appropriate database summary or aggregation rewrite.',
'- **R22:** 64.984 ms. Deep OFFSET and external sorting do unnecessary work before returning 25 rows; investigate ordered access and pagination semantics.',
'- **Learner-facing R04/R06:** 8.493 / 11.440 ms on seed data. Both scan attempts despite asking about a single learner; selective access paths are a priority. The README’s final targets apply to the later large dataset, not a CP2 pass/fail test.',
'- **W05:** 74.081 ms. Candidate aggregation, repeated conflict handling and FK checks dominate; future read optimizations must also account for write overhead.',
'- **R13 correctness issue:** all three plans return zero rows because NOT IN reads NULL referrers. SQL uses UNKNOWN rather than TRUE for a nonmatching value when the list contains NULL; WHERE discards UNKNOWN. Preserve this original baseline, then fix and explain the intended business result in Phase 4 (typically with NOT EXISTS).', '',
'## Verification and scope', '',
'`python3 benchmarks/build_baseline_report.py` validates query coverage, all 90 raw execution times, run markers, mean/median/min/max consistency and regenerates this report. It reads recorded results; it does not run or simulate the benchmark.', '',
'After benchmarking, the [saved integrity verification](../benchmarks/results/baseline/integrity_after.txt) confirms all 11 expected row counts, zero violations in the five CP1 core integrity checks, and only the 18 PK/UNIQUE indexes. Previously documented data-quality anomalies remain visible. The source workload and benchmark script are unchanged.', '',
'This completes the **DE** CP2 artifacts. AP CP2 requires an ER diagram and schema for the separate AP application and is outside this repository’s work. The optimization priorities above start the analysis for Phase 4; no tuning has been applied to this baseline.', '']
(ROOT / 'docs/03_baseline_timings.md').write_text('\n'.join(lines))
print(f'Validated 30 queries / 90 runs; mean-total {fmt(total_avg)} ms; report generated.')
