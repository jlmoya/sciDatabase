# sciDatabase — API Reference

Generic, engine-agnostic database connectivity for **Scilab 2027 / macOS arm64**. Five
engines across three paradigms, all native (no JVM):

| Paradigm    | Engines                              | Transport libs                         |
|-------------|--------------------------------------|----------------------------------------|
| `sql`       | `postgresql`, `mysql`, `sqlite`      | libpq, libmysqlclient, libsqlite3      |
| `document`  | `mongodb`                            | mongo-c-driver 2.x                     |
| `keyvalue`  | `redis`                              | hiredis                                |

Every handle carries its **paradigm**; a verb used on the wrong paradigm raises a clear
error (e.g. `dbQuery` on a Redis handle). The generic API stays constant across engines —
adding an engine does not change your code.

---

## Connections

### `db = dbConnect(engine, params)`
Open a connection. `engine` is one of the names above. `params` is a struct:

| Field      | Used by            | Notes                                              |
|------------|--------------------|----------------------------------------------------|
| `host`     | pg, mysql, mongo, redis | default `localhost`                           |
| `port`     | pg, mysql, mongo, redis | engine default if omitted                     |
| `database` | pg, mysql, mongo   | for `sqlite`, a **file path** (or `:memory:`)      |
| `user`     | pg, mysql          |                                                    |
| `password` | pg, mysql          |                                                    |
| `backend`  | all                | `auto` (default, native) or `jdbc` (GUI-only)      |

```scilab
db = dbConnect("postgresql", struct("host","127.0.0.1","port","5432", ..
               "database","market","user","quant","password","secret"));
sl = dbConnect("sqlite", struct("database", "/tmp/prices.sqlite"));
mg = dbConnect("mongodb", struct("host","127.0.0.1","port","27017","database","market"));
rd = dbConnect("redis",   struct("host","127.0.0.1","port","6379"));
```

### `dbClose(db)`
Close a connection. Safe to call more than once (the second call is a no-op).

### `b = dbIsOpen(db)`
`%t` if the connection is alive (round-trips a trivial request), `%f` for a closed
connection or anything that is not a handle. Never throws.

### `r = dbInfo(db)`
Struct describing the handle: `.engine`, `.transport`, `.paradigm`.

### `r = dbEngines()`
Registry of known engines, their paradigms, transports, and default transports.

---

## SQL queries

### `r = dbQuery(db, sql [, params] [, asMatrix])`
Run a row-returning statement. Returns a **struct keyed by column name** — numeric columns
as column vectors, text as string arrays.

- `params` — a `list(...)` of values to bind to `?` placeholders (see *Parameter binding*).
- `asMatrix` — `%t` returns a plain numeric matrix instead of a struct.
- Back-compatible: `dbQuery(db, sql, %t)` still means `asMatrix`.

```scilab
r = dbQuery(db, "select ticker, close from prices where close > ?", list(200));
M = dbQuery(db, "select close, volume from prices", %t);    // numeric matrix
```

### `n = dbExec(db, sql [, params])`
Run a non-row-returning statement (INSERT/UPDATE/DELETE/DDL). Returns rows affected.

```scilab
n = dbExec(db, "update prices set close = ? where ticker = ?", list(212.5, "AAPL"));
```

---

## Prepared statements & parameter binding

Uniform `?` placeholders are used for **every** engine and auto-translated to `$1,$2,…`
for PostgreSQL (string literals are respected). Values bind as **data**, never interpolated
into SQL, so quotes and metacharacters are safe. An empty matrix `[]` in a parameter list
binds as SQL **NULL** (`""` stays an empty string).

### `ps = dbPrepare(db, sql)`
Prepare a statement once for repeated execution (server-side).

### `r = dbRun(ps [, params] [, asMatrix])`
Execute a prepared statement with bound parameters. Returns a struct (row-returning) or the
affected-row count (DML).

### `dbFinalize(ps)`
Release a prepared statement.

```scilab
ps = dbPrepare(db, "insert into prices(ticker, close) values(?, ?)");
dbRun(ps, list("AAPL", 212.34));
dbRun(ps, list("MSFT", 468.20));
dbFinalize(ps);
```

### `n = dbRunBatch(ps, rows)`
Executemany: run a prepared statement once per parameter set, **inside a single
transaction** (fast, atomic bulk writes). `rows` is a list of parameter lists. Returns total
affected rows; the whole batch rolls back on any error.

```scilab
ps = dbPrepare(db, "insert into prices(ticker, close, volume) values(?, ?, ?)");
dbRunBatch(ps, list(list("AAPL",212.34,51200000), list("MSFT",468.20,22100000)));
dbFinalize(ps);
```

---

## Transactions  *(SQL)*

### `dbBegin(db)` · `dbCommit(db)` · `dbRollback(db)`
Explicit transaction control.

### `dbTransaction(db, fn)`
Run `fn(db)` inside a transaction: COMMIT on success, ROLLBACK + rethrow if `fn` raises.

```scilab
function load(db)
    dbExec(db, "insert into prices(ticker, close) values(?, ?)", list("AAPL", 212.34));
    dbExec(db, "insert into prices(ticker, close) values(?, ?)", list("MSFT", 468.20));
endfunction
dbTransaction(db, load);            // both inserts commit, or neither does
```

---

## Introspection

### `t = dbTables(db)`
List the containers as a string column vector — **tables** (SQL), **collections**
(MongoDB), or **keys** (Redis). Paradigm-aware.

### `c = dbColumns(db, tbl)`  *(SQL)*
Describe a table's columns: a struct with `.name` and `.type` string arrays (in declaration
order). The table name is bound safely, not interpolated.

### `b = dbExists(db, name)`
`%t`/`%f` — does a table / collection / key exist.

---

## MongoDB  *(document)*

Documents move as Scilab structs (mapped to/from JSON internally).

### `r = dbFind(db, coll [, filter])`
List of matching documents (one struct each). `filter` is a struct; omit or `struct()` for all.

### `r = dbFindOne(db, coll [, filter])`
First matching document as a struct, or an empty struct if none.

### `n = dbInsert(db, coll, doc)`
Insert one document. Returns 1.

### `n = dbUpdate(db, coll, filter, changes [, upsert])`
Apply `{$set: changes}` to matching documents; returns the modified count. `upsert = %t`
inserts a new document when nothing matches.

### `n = dbDelete(db, coll, filter)`
Delete matching documents; returns the deleted count. `struct()` deletes all.

### `n = dbCount(db, coll [, filter])`
Count matching documents.

### `r = dbAggregate(db, coll, pipeline)`
Run an aggregation pipeline; returns a list of result-document structs. `pipeline` is a raw
JSON array string (recommended — `$`-operators are JSON keys Scilab structs can't name), or
a list of `$`-free stage structs.

```scilab
r = dbAggregate(db, "prices", ...
      "[{""$group"":{""_id"":""$sector"",""avg"":{""$avg"":""$close""}}}]");
```

---

## Redis  *(key-value)*

### `dbSet(db, key, val)` · `v = dbGet(db, key)` · `n = dbDel(db, key)`
Basic string get/set/delete.

### `r = dbCmd(db, cmd, ...)`
Run any Redis command; returns the reply (string / number / string column / `[]`).

```scilab
dbCmd(db, "LPUSH", "recent", "AAPL", "MSFT");
n = dbCmd(db, "LLEN", "recent");
```

---

## Connection pooling

Pre-open N connections and lend them out — avoids per-call connect/disconnect cost and caps
concurrency.

### `pool = dbPool(engine, params [, n])`
Create a pool of `n` connections (default 4).

### `db = dbAcquire(pool)`
Borrow an idle connection (errors if the pool is exhausted).

### `dbRelease(pool, db)`
Return a connection (it stays open for reuse).

### `dbPoolClose(pool)`
Close every connection and free the pool.

```scilab
pool = dbPool("postgresql", params, 4);
db = dbAcquire(pool);
r  = dbQuery(db, "select count(*) as n from prices");
dbRelease(pool, db);
dbPoolClose(pool);
```

---

## Notes

- **Native everywhere.** All transports work in every Scilab binary including the no-JVM
  `scilab-cli`. A JDBC backend exists for GUI (STD) mode; on this Scilab build headless Java
  interop hangs, so native is the universal, verified path.
- **Parameter values** bind as text and the engine coerces to the column type; integers are
  exact, other numbers carry 15 significant digits, `[]` → NULL, booleans → `1`/`0`.
