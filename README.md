# sciDatabase

Generic database connectivity for **Scilab 2027 / macOS arm64**, built to grow across engines
(PostgreSQL now; MySQL/SQLite/… later) and paradigms (SQL now; NoSQL later).

## API
```scilab
db = dbConnect("postgresql", params)   // params: struct(host,port,database,user,password[,backend])
M  = dbQuery(db, "select ...")          // SELECT -> struct keyed by column (numeric/string per column)
M  = dbQuery(db, "select ...", %t)      // %t -> plain numeric matrix
n  = dbExec (db, "insert/update/...")    // DML/DDL -> rows affected
dbClose(db)
dbEngines()   // registry of engines + transports
dbInfo(db)    // this handle's engine/transport/paradigm
```

## Transports
- **libpq** (native, default) — works in **every** binary including the no-JVM `scilab-cli` and
  `scilab-adv-cli`. Links Homebrew `libpq`. This is the verified, universal path.
- **jdbc** (`backend="jdbc"`) — via Scilab's Java bridge + the bundled PostgreSQL JDBC driver.
  Works in the **GUI (STD mode)**; on this Scilab build, **headless Java interop hangs**, so JDBC
  is GUI-only here. Kept for GUI use and future multi-database support (swap the driver jar).

`backend="auto"` (default) selects **libpq** (universal + verified).

## Requirements
- libpq: `brew install libpq` (or comes with `postgresql@NN`).
- JDBC: `thirdparty/jdbc/postgresql-*.jar` is bundled.

## Test
`tests/test_postgres.sce` round-trips connect → query → matrix against a local DB
(edit the params). Headless runs exercise libpq; run it in the GUI to also test JDBC.
