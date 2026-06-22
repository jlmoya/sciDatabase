# sciDatabase

Generic database connectivity for **Scilab 2027 / macOS arm64**, built to grow across engines
and paradigms.

**Engines (this iteration):** `postgresql`, `mysql`, `sqlite` — all SQL.
**Planned:** MongoDB + Redis (NoSQL paradigm with document/key-value verbs).

## API
```scilab
db = dbConnect("postgresql"|"mysql"|"sqlite", params)  // host,port,database,user,password[,backend]
                                        // sqlite: database = a file path (or ":memory:")
M  = dbQuery(db, "select ...")          // SELECT -> struct keyed by column (numeric/string per column)
M  = dbQuery(db, "select ...", %t)      // %t -> plain numeric matrix
n  = dbExec (db, "insert/update/...")    // DML/DDL -> rows affected
dbClose(db)
dbEngines()   // registry of engines + transports
dbInfo(db)    // this handle's engine/transport/paradigm
```

## Transports
- **native** (default per engine) — `libpq` (PostgreSQL), `libsqlite3` (SQLite, file-based, no
  server), `libmysqlclient` (MySQL). Work in **every** binary incl. the no-JVM `scilab-cli`. Verified.
- **jdbc** (`backend="jdbc"`) — via Scilab's Java bridge + the bundled PostgreSQL JDBC driver.
  Works in the **GUI (STD mode)**; on this Scilab build, **headless Java interop hangs**, so JDBC
  is GUI-only here. Kept for GUI use and future multi-database support (swap the driver jar).

`backend="auto"` (default) selects **libpq** (universal + verified).

## Requirements
- native: `brew install libpq sqlite mysql` (libsqlite3 also ships with macOS).
- JDBC: postgresql / sqlite-jdbc / mysql-connector-j jars bundled in `thirdparty/jdbc/`.

## Test
`tests/test_postgres.sce` round-trips connect → query → matrix against a local DB
(edit the params). Headless runs exercise libpq; run it in the GUI to also test JDBC.
