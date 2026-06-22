// sciDatabase — prepared statements + parameter binding acceptance test (SQL engines)
errcatch_on = %t;
here = get_absolute_file_path("test_prepared.sce");
exec(fullfile(here, "..", "loader.sce"), -1);

function status = runSuite(tag, engine, params, ddl_create)
    status = tag + ": ";
    db = dbConnect(engine, params);
    dbExec(db, "drop table if exists prices_ps");
    dbExec(db, ddl_create);

    // --- prepared statement: prepare once, run many (bulk insert), incl. a quoted value ---
    ps = dbPrepare(db, "insert into prices_ps(ticker, close, volume) values(?, ?, ?)");
    dbRun(ps, list("AAPL",   212.34, 51200000));
    dbRun(ps, list("MSFT",   468.20, 22100000));
    dbRun(ps, list("GOOG",   175.86, 18700000));
    dbRun(ps, list(ascii(79)+ascii(39)+"NEIL", 13.5, 100));   // O'NEIL — apostrophe in the value
    dbFinalize(ps);

    // --- parameter binding on dbQuery (filter by a bound numeric) ---
    r = dbQuery(db, "select ticker, close from prices_ps where close > ? order by close", list(200));
    n_sel = size(r.ticker, "*");                              // expect 2 (AAPL, MSFT)

    // --- injection safety: the apostrophe value round-trips as data, not SQL ---
    r2 = dbQuery(db, "select volume from prices_ps where ticker = ?", list(ascii(79)+ascii(39)+"NEIL"));
    oneil_ok = (size(r2.volume,"*") == 1) & (r2.volume(1) == 100);

    // --- parameter binding on dbExec (UPDATE) ---
    nupd = dbExec(db, "update prices_ps set volume = ? where ticker = ?", list(99999999, "AAPL"));
    r3 = dbQuery(db, "select volume from prices_ps where ticker = ?", list("AAPL"));
    upd_ok = (r3.volume(1) == 99999999);

    // --- total row count ---
    rc = dbQuery(db, "select count(*) as n from prices_ps");
    total = rc.n(1);                                          // expect 4

    // --- back-compat: dbQuery(db, sql, %t) still means asMatrix ---
    M = dbQuery(db, "select close, volume from prices_ps order by close", %t);
    mat_ok = (type(M) == 1) & (size(M,1) == 4) & (size(M,2) == 2);

    dbExec(db, "drop table if exists prices_ps");
    dbClose(db);

    ok = (n_sel==2) & oneil_ok & (nupd==1) & upd_ok & (total==4) & mat_ok;
    verdict = "FAIL"; if ok then verdict = "OK"; end
    status = status + msprintf("sel=%d oneil=%d upd=%d updok=%d total=%d matrix=%d -> %s", ..
             n_sel, bool2s(oneil_ok), nupd, bool2s(upd_ok), total, bool2s(mat_ok), verdict);
endfunction

results = [];

// ---- SQLite (file-based) ----
ie = execstr("s = runSuite(""SQLITE"", ""sqlite"", struct(""database"", TMPDIR+""/ps_test.sqlite""), ""create table prices_ps(ticker text, close real, volume integer)"");", "errcatch");
if ie<>0 then s = "SQLITE: ERROR "+lasterror(); end
results = [results; s];

// ---- PostgreSQL :5433 (trust) ----
pgp = struct("host","127.0.0.1","port","5433","database","scitest","user","josemoya","password","");
ie = execstr("s = runSuite(""POSTGRES"", ""postgresql"", pgp, ""create table prices_ps(ticker text, close double precision, volume bigint)"");", "errcatch");
if ie<>0 then s = "POSTGRES: ERROR "+lasterror(); end
results = [results; s];

// ---- MySQL :3307 ----
myp = struct("host","127.0.0.1","port","3307","database","scitest","user","scitest","password","scitest");
ie = execstr("s = runSuite(""MYSQL"", ""mysql"", myp, ""create table prices_ps(ticker varchar(16), close double, volume bigint)"");", "errcatch");
if ie<>0 then s = "MYSQL: ERROR "+lasterror(); end
results = [results; s];

mprintf("\n==== PREPARED STATEMENTS / PARAM BINDING ====\n");
for i=1:size(results,1); mprintf("%s\n", results(i)); end
mprintf("=============================================\n");
quit
