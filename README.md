# sciDatabase

Generic, engine-agnostic database connectivity for **Scilab 2027 / macOS arm64** — **v1.0**,
production-ready, all native (no JVM), verified headless in `scilab-cli`.

**Engines:** `postgresql`, `mysql`, `sqlite` (SQL) · `mongodb` (document) · `redis` (key-value).
Each handle's `paradigm` gates which verbs apply (calling an SQL verb on a Redis handle errors clearly).

**Highlights:** prepared statements & safe parameter binding (`?` everywhere, `[]` → NULL) ·
transactions + `dbTransaction` scope helper · batch `executemany` · introspection
(`dbTables`/`dbColumns`/`dbExists`) · MongoDB find/aggregate/count/upsert · connection pooling ·
liveness checks. Full per-verb docs in [`docs/REFERENCE.md`](docs/REFERENCE.md);
changes in [`CHANGELOG.md`](CHANGELOG.md).

## API
```scilab
db = dbConnect("postgresql"|"mysql"|"sqlite", params)  // host,port,database,user,password[,backend]
                                        // sqlite: database = a file path (or ":memory:")
M  = dbQuery(db, "select ...")          // SELECT -> struct keyed by column (numeric/string per column)
M  = dbQuery(db, "select ...", %t)      // %t -> plain numeric matrix
n  = dbExec (db, "insert/update/...")    // DML/DDL -> rows affected
dbClose(db)

// Prepared statements + parameter binding (SQL engines) — '?' placeholders, bound safely as
// data (no string interpolation); '?' is auto-translated to $1,$2,... for PostgreSQL.
r = dbQuery(db, "select * from t where x > ? and k = ?", list(200, "AAPL"))   // one-shot binding
n = dbExec (db, "update t set v = ? where k = ?", list(99, "AAPL"))            // bound DML
ps = dbPrepare(db, "insert into t(k,v) values(?,?)");  // prepare once, run many (fast bulk)
dbRun(ps, list("AAPL", 212.34));  dbRun(ps, list("MSFT", 468.20));  dbFinalize(ps);
dbRunBatch(ps, list(list("A",1), list("B",2)))           // executemany in one transaction

// Transactions (SQL) — explicit or scoped
dbBegin(db); dbExec(db, "..."); dbCommit(db);  // or dbRollback(db)
dbTransaction(db, fn)                            // fn(db): COMMIT on success, ROLLBACK on error

// Introspection (all paradigms)
t = dbTables(db)            // table / collection / key names
c = dbColumns(db, "t")      // SQL: struct with .name / .type
b = dbExists(db, "t")       // table / collection / key exists?

// MongoDB (document paradigm)
r = dbFind(db, "coll" [, struct(...)])   // -> list of structs (one per matching document)
d = dbFindOne(db, "coll", filter)        // first match (or empty struct)
n = dbInsert(db, "coll", struct(...))     // insert one document
n = dbUpdate(db, "coll", filter, changes [, %t])  // {$set: changes}; %t = upsert
n = dbDelete(db, "coll", filter)          // -> deleted count
k = dbCount(db, "coll" [, filter])        // count documents
r = dbAggregate(db, "coll", pipelineJson) // aggregation pipeline -> list of structs

// Redis (key-value paradigm)
dbSet(db, key, val);  v = dbGet(db, key);  n = dbDel(db, key);
r = dbCmd(db, "LPUSH", "mylist", "a", "b");   // any Redis command

// Connection pool · lifecycle · info
pool = dbPool(engine, params, n); db = dbAcquire(pool); dbRelease(pool, db); dbPoolClose(pool);
dbIsOpen(db)  // alive?      dbEngines()  // registry      dbInfo(db)  // engine/transport/paradigm
```

See [`demos/demo_prices.sce`](demos/demo_prices.sce) for a runnable, self-contained (SQLite) tour.

## Transports
- **native** (default per engine) — `libpq` (PostgreSQL), `libsqlite3` (SQLite, file-based, no
  server), `libmysqlclient` (MySQL). Work in **every** binary incl. the no-JVM `scilab-cli`. Verified.
- **jdbc** (`backend="jdbc"`) — via Scilab's Java bridge + the bundled PostgreSQL JDBC driver.
  Works in the **GUI (STD mode)**; on this Scilab build, **headless Java interop hangs**, so JDBC
  is GUI-only here. Kept for GUI use and future multi-database support (swap the driver jar).

`backend="auto"` (default) selects **libpq** (universal + verified).

## Requirements
- native: `brew install libpq sqlite mysql hiredis mongo-c-driver`.
- JDBC: postgresql / sqlite-jdbc / mysql-connector-j jars bundled in `thirdparty/jdbc/`.

## Test
`tests/run_all.sh` runs every acceptance suite and prints a combined OK/FAIL summary:

```sh
SCILAB=/path/to/scilab-cli tests/run_all.sh
```

The suites (`test_prepared`, `test_wave1`…`test_wave5`) cover prepared statements & binding,
transactions/NULL/batch, introspection, MongoDB completeness, robustness/lifecycle, and
pooling. They expect local test servers (Postgres :5433, MySQL :3307, MongoDB :27018,
Redis :6380); SQLite needs nothing. Each suite is self-contained and can also be run directly
with `scilab-cli -nb -f tests/<suite>.sce`.
