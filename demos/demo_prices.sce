// sciDatabase — self-contained demo (SQLite, no server required).
// Showcases: schema + introspection, prepared-statement batch insert in a transaction,
// parameter binding (incl. NULL), parameterized queries, transactions, and a connection pool.
//
//   exec demos/demo_prices.sce
mode(-1);
here = get_absolute_file_path("demo_prices.sce");
exec(fullfile(here, "..", "loader.sce"), -1);

dbfile = TMPDIR + "/sciDatabase_demo.sqlite";
mdelete(dbfile);                                    // start fresh
db = dbConnect("sqlite", struct("database", dbfile));
mprintf("\n--- connected: %s ---\n", strcat([dbInfo(db).engine, dbInfo(db).paradigm], " / "));

// ---- schema ----
dbExec(db, "create table prices(ticker text, close real, volume integer, sector text)");
mprintf("tables now: %s\n", strcat(dbTables(db)', ", "));
cols = dbColumns(db, "prices");
mprintf("columns of ""prices"": %s\n", strcat(cols.name', ", "));

// ---- bulk insert: prepare once, run many, atomically (one transaction) ----
ps = dbPrepare(db, "insert into prices(ticker, close, volume, sector) values(?, ?, ?, ?)");
n = dbRunBatch(ps, list( ..
    list("AAPL", 212.34, 51200000, "tech"),   ..
    list("MSFT", 468.20, 22100000, "tech"),   ..
    list("GOOG", 175.86, 18700000, "tech"),   ..
    list("XOM",  110.10, 14300000, "energy"), ..
    list("CVX",  158.40, [],       "energy")));    // [] -> SQL NULL volume
dbFinalize(ps);
mprintf("inserted %d rows (one with a NULL volume)\n", n);

// ---- parameterized query ----
r = dbQuery(db, "select ticker, close from prices where sector = ? and close > ? order by close desc", ..
            list("tech", 200));
mprintf("\ntech names over 200:\n");
for i = 1:size(r.ticker, "*")
    mprintf("  %-6s %8.2f\n", r.ticker(i), r.close(i));
end

// ---- NULL-aware query ----
rn = dbQuery(db, "select count(*) as c from prices where volume is null");
mprintf("\nrows with NULL volume: %d\n", rn.c(1));

// ---- transaction: a correction that must be all-or-nothing ----
function reprice(db)
    dbExec(db, "update prices set close = ? where ticker = ?", list(214.00, "AAPL"));
    dbExec(db, "update prices set close = ? where ticker = ?", list(470.00, "MSFT"));
endfunction
dbTransaction(db, reprice);
mprintf("after repricing, AAPL = %.2f\n", dbQuery(db, "select close from prices where ticker=?", list("AAPL")).close(1));

// ---- aggregate via SQL ----
g = dbQuery(db, "select sector, count(*) as n, avg(close) as avg_close from prices group by sector order by sector");
mprintf("\nby sector:\n");
for i = 1:size(g.sector, "*")
    mprintf("  %-7s n=%d  avg=%.2f\n", g.sector(i), g.n(i), g.avg_close(i));
end

dbClose(db);

// ---- a tiny connection pool ----
pool = dbPool("sqlite", struct("database", dbfile), 2);
c = dbAcquire(pool);
mprintf("\npool query — total rows: %d\n", dbQuery(c, "select count(*) as n from prices").n(1));
dbRelease(pool, c);
dbPoolClose(pool);

mprintf("\n--- demo complete ---\n");
