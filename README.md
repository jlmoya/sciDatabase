# sciDatabase

Generic database connectivity for **Scilab 2027 / macOS arm64**, built to grow across engines
and paradigms.

**Engines:** `postgresql`, `mysql`, `sqlite` (SQL) · `mongodb` (document) · `redis` (key-value).
Each handle's `paradigm` gates which verbs apply (calling an SQL verb on a Redis handle errors clearly).

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

// MongoDB (document paradigm)
r = dbFind(db, "coll" [, struct(...)])  // -> list of structs (one per matching document)
n = dbInsert(db, "coll", struct(...))    // insert one document
n = dbUpdate(db, "coll", filter, changes)// applies {$set: changes} -> modified count
n = dbDelete(db, "coll", filter)         // -> deleted count

// Redis (key-value paradigm)
dbSet(db, key, val);  v = dbGet(db, key);  n = dbDel(db, key);
r = dbCmd(db, "LPUSH", "mylist", "a", "b");   // any Redis command
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
- native: `brew install libpq sqlite mysql hiredis mongo-c-driver`.
- JDBC: postgresql / sqlite-jdbc / mysql-connector-j jars bundled in `thirdparty/jdbc/`.

## Test
`tests/test_postgres.sce` round-trips connect → query → matrix against a local DB
(edit the params). Headless runs exercise libpq; run it in the GUI to also test JDBC.
