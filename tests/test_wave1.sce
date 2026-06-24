// sciDatabase Wave 1 — transactions, NULL binding, batch (SQL engines)
errcatch_on = %t;
here = get_absolute_file_path("test_wave1.sce");
exec(fullfile(here, "..", "loader.sce"), -1);

function c = cnt(db)
    r = dbQuery(db, "select count(*) as c from prices_ps"); c = r.c(1);
endfunction
function insTwo(db)
    dbExec(db, "insert into prices_ps(ticker,close,volume) values(?,?,?)", list("C1", 1.0, 1));
    dbExec(db, "insert into prices_ps(ticker,close,volume) values(?,?,?)", list("C2", 2.0, 2));
endfunction
function insThenFail(db)
    dbExec(db, "insert into prices_ps(ticker,close,volume) values(?,?,?)", list("BAD", 9.0, 9));
    error("boom");                                  // force the scope helper to roll back
endfunction

function status = runSuite(tag, engine, params, ddl)
    db = dbConnect(engine, params);
    dbExec(db, "drop table if exists prices_ps");
    dbExec(db, ddl);

    // NULL binding: [] in a param list -> SQL NULL (not 0, not "")
    dbExec(db, "insert into prices_ps(ticker,close,volume) values(?,?,?)", list("ZZZ", [], 5));
    rnull = dbQuery(db, "select count(*) as c from prices_ps where close is null");
    null_ok = (rnull.c(1) == 1);

    base = cnt(db);                                  // 1

    // explicit transaction — COMMIT
    dbBegin(db);
    dbExec(db, "insert into prices_ps(ticker,close,volume) values(?,?,?)", list("C1", 1.0, 1));
    dbExec(db, "insert into prices_ps(ticker,close,volume) values(?,?,?)", list("C2", 2.0, 2));
    dbCommit(db);
    commit_ok = (cnt(db) == base + 2); base = cnt(db);

    // explicit transaction — ROLLBACK
    dbBegin(db);
    dbExec(db, "insert into prices_ps(ticker,close,volume) values(?,?,?)", list("R1", 3.0, 3));
    dbRollback(db);
    rollback_ok = (cnt(db) == base);

    // dbTransaction scope helper — success commits
    dbTransaction(db, insTwo);
    txn_ok = (cnt(db) == base + 2); base = cnt(db);

    // dbTransaction scope helper — error auto-rolls-back AND rethrows
    ie = execstr("dbTransaction(db, insThenFail)", "errcatch");
    txnrb_ok = (ie <> 0) & (cnt(db) == base);

    // dbRunBatch — executemany inside one transaction
    ps = dbPrepare(db, "insert into prices_ps(ticker,close,volume) values(?,?,?)");
    nb = dbRunBatch(ps, list(list("B1",10,1), list("B2",20,2), list("B3",30,3)));
    dbFinalize(ps);
    batch_ok = (nb == 3) & (cnt(db) == base + 3);

    dbExec(db, "drop table if exists prices_ps");
    dbClose(db);

    ok = null_ok & commit_ok & rollback_ok & txn_ok & txnrb_ok & batch_ok;
    verdict = "FAIL"; if ok then verdict = "OK"; end
    status = tag + msprintf(": null=%d commit=%d rollback=%d txn=%d txn_rb=%d batch=%d -> %s", ..
        bool2s(null_ok), bool2s(commit_ok), bool2s(rollback_ok), bool2s(txn_ok), bool2s(txnrb_ok), bool2s(batch_ok), verdict);
endfunction

results = [];
ie = execstr("s = runSuite(""SQLITE"", ""sqlite"", struct(""database"", TMPDIR+""/w1.sqlite""), ""create table prices_ps(ticker text, close real, volume integer)"");", "errcatch");
if ie<>0 then s = "SQLITE: ERROR "+lasterror(); end
results = [results; s];

pgp = struct("host","127.0.0.1","port","5433","database","scitest","user","josemoya","password","");
ie = execstr("s = runSuite(""POSTGRES"", ""postgresql"", pgp, ""create table prices_ps(ticker text, close double precision, volume bigint)"");", "errcatch");
if ie<>0 then s = "POSTGRES: ERROR "+lasterror(); end
results = [results; s];

myp = struct("host","127.0.0.1","port","3307","database","scitest","user","scitest","password","scitest");
ie = execstr("s = runSuite(""MYSQL"", ""mysql"", myp, ""create table prices_ps(ticker varchar(16), close double, volume bigint)"");", "errcatch");
if ie<>0 then s = "MYSQL: ERROR "+lasterror(); end
results = [results; s];

mprintf("\n==== WAVE 1: TRANSACTIONS / NULL / BATCH ====\n");
for i=1:size(results,1); mprintf("%s\n", results(i)); end
mprintf("============================================\n");
quit
