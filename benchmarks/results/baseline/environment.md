# Baseline benchmark environment

- Measured: 17 November 2026 (Asia/Kolkata).
- Hardware: Apple M4, 16 GiB RAM, model Mac16,1 (reported by sysctl).
- OS: macOS 26.5.1, build 25F80, arm64.
- Database: PostgreSQL 18.6 (Postgres.app), database duolingo_cp1.
- Connection: local Unix socket /private/tmp/duolingo-cp1-pg, port 55432.
- Dataset: all 11 supplied seed CSVs, including 188,300 attempts and 30,000 learners.
- Indexes before the benchmark: 18 PK/UNIQUE indexes, zero nonconstraint indexes.
- Query source: unchanged queries/workload_30.sql.
- Runner: unchanged benchmarks/run_benchmark.sh; 3 runs per query, in query-ID order.
- Timezone: Asia/Kolkata, explicitly set in PGOPTIONS for the benchmark.
- shared_buffers: 128 MiB (16384 × 8 KiB).
- work_mem: 4 MiB (4096 KiB), default.
- effective_cache_size: 4 GiB (524288 × 8 KiB), default estimate.
- max_parallel_workers_per_gather: 2, default.
- jit: on, default.
- No PostgreSQL server settings changed to improve timings.
- Existing CP1 database reused; normal OS/PostgreSQL caches, no forced cold-cache reset or excluded warm-up runs. CP1 verification had already accessed the data.
- Background activity was not controlled; these are local baseline measurements, not a concurrency or production load test.
- R01–R25 executed as reads; each W01–W05 execution used BEGIN / EXPLAIN (ANALYZE, BUFFERS) / ROLLBACK.
- All row counts, five aggregate/relationship checks, and the constraint-only index inventory were checked again after benchmarking; see integrity_after.txt. Rollback preserves logical data, although physical pages, dead tuples and caches can change.

Reproduce on this running local instance from the repository root:

```bash
export PATH="/Applications/Postgres.app/Contents/Versions/18/bin:$PATH"
export PGHOST=/private/tmp/duolingo-cp1-pg
export PGPORT=55432
export PGOPTIONS='-c timezone=Asia/Kolkata'
./benchmarks/run_benchmark.sh duolingo_cp1 baseline 3
python3 benchmarks/build_baseline_report.py
```

The benchmark command overwrites the baseline files; rerun deliberately. For another PostgreSQL instance, use that instance's connection settings and first load the schema and seed data. Use this same laptop for Phase 4 comparison.
