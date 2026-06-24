# Changelog

## 1.0.0 — 2026-06-24

First production release. Generic, engine-agnostic database connectivity for Scilab 2027
on macOS arm64, spanning five engines across three paradigms, all native (no JVM) and
verified headless in `scilab-cli`.

### Engines & paradigms
- **SQL** — PostgreSQL (libpq), MySQL (libmysqlclient), SQLite (libsqlite3)
- **Document** — MongoDB (mongo-c-driver 2.x)
- **Key-value** — Redis (hiredis)

Each handle's paradigm gates which verbs apply; calling an SQL verb on a Redis handle
(and vice versa) raises a clear error.

### Core
- `dbConnect` / `dbClose` / `dbInfo` / `dbEngines`
- `dbQuery` (SELECT → struct or numeric matrix), `dbExec` (DML/DDL → rows affected)

### Prepared statements & parameter binding
- Uniform `?` placeholders, auto-translated to `$1,$2,…` for PostgreSQL
- `dbPrepare` / `dbRun` / `dbFinalize` (prepare once, run many)
- Parameter binding on `dbQuery` / `dbExec` (`list(...)` of values; bound as data, no
  string interpolation)
- `[]` in a parameter list binds as SQL `NULL`
- `dbRunBatch` — executemany inside a single transaction

### Transactions
- `dbBegin` / `dbCommit` / `dbRollback`
- `dbTransaction(db, fn)` — runs `fn(db)` with COMMIT on success, ROLLBACK + rethrow on error

### Introspection
- `dbTables` (tables / collections / keys), `dbColumns`, `dbExists`

### MongoDB
- `dbFind` / `dbFindOne` / `dbInsert` / `dbUpdate` (with upsert) / `dbDelete`
- `dbCount`, `dbAggregate` (pipeline)

### Redis
- `dbGet` / `dbSet` / `dbDel`, and `dbCmd` for any command

### Robustness & lifecycle
- `dbIsOpen` (liveness ping), handle-type validation on every verb, idempotent `dbClose`

### Connection pooling
- `dbPool` / `dbAcquire` / `dbRelease` / `dbPoolClose`

### Notes
- A JDBC transport exists for GUI (STD) mode; on this Scilab build, headless Java interop
  hangs, so the native transports are the universal, verified path.
