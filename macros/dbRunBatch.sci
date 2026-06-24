function n = dbRunBatch(ps, rows)
    // Execute a prepared statement once per parameter set, inside a single transaction — fast,
    // atomic bulk writes (executemany). rows is a list of parameter lists:
    //   ps = dbPrepare(db, "insert into prices(ticker,close) values(?,?)");
    //   dbRunBatch(ps, list(list("AAPL",212.34), list("MSFT",468.20), list("GOOG",175.86)));
    // Returns the total number of affected rows. Any error rolls the whole batch back.
    if type(ps) <> 16 | ps(1)(1) <> "sciDbStmt" then
        error("dbRunBatch: first argument must be a prepared statement from dbPrepare.");
    end
    if type(rows) <> 15 then
        error("dbRunBatch: second argument must be a list of parameter lists (list(list(...),...)).");
    end
    f = scidb_adapter(ps.transport);
    n = 0;
    f("exec", ps.conn, "BEGIN");
    try
        for i = 1:length(rows)
            [pv, mask] = scidb_paramvec(rows(i));
            rc = f("run", ps.stmt, pv, mask, %f);
            if type(rc) == 1 then n = n + rc; end       // DML -> affected-row count
        end
    catch
        msg = lasterror();
        f("exec", ps.conn, "ROLLBACK");
        error("dbRunBatch: rolled back — " + msg);
    end
    f("exec", ps.conn, "COMMIT");
endfunction
