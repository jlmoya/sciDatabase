// sciDatabase — multi-engine round-trip test (native transports; run headless or in GUI).
// Adjust the params to your servers. SQLite needs no server; Postgres/MySQL do.
exec(fullfile(get_absolute_file_path("test_engines.sce"), "..", "loader.sce"), -1);
mprintf("engines: %s\n", strcat(dbEngines().engines, ", "));

// --- SQLite (self-contained: file-based) ---
f = TMPDIR + "/scidb_engines.sqlite"; mdelete(f);
db = dbConnect("sqlite", struct("database", f));
dbExec(db, "create table t(id integer, v real)");
dbExec(db, "insert into t values(1,10.0),(2,20.0),(3,30.0)");
mprintf("[sqlite] avg v = %.1f (expect 20.0)\n", mean(dbQuery(db,"select v from t",%t)));
dbClose(db);

// --- PostgreSQL (edit host/port/db/user) ---
try
    db = dbConnect("postgresql", struct("host","localhost","port","5433","database","scitest","user","josemoya"));
    mprintf("[postgresql] rows in prices = %d\n", dbQuery(db,"select count(*) c from prices").c);
    dbClose(db);
catch
    mprintf("[postgresql] skipped (%s)\n", lasterror());
end

// --- MySQL (edit host/port/db/user/password) ---
try
    db = dbConnect("mysql", struct("host","127.0.0.1","port","3307","database","scitest","user","scitest","password","scitest"));
    mprintf("[mysql] rows in prices = %d\n", dbQuery(db,"select count(*) c from prices").c);
    dbClose(db);
catch
    mprintf("[mysql] skipped (%s)\n", lasterror());
end
