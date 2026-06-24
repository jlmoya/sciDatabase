function ps = dbPrepare(db, sql)
    // Prepare a parameterized SQL statement for repeated execution (prepare once, run many).
    // Use '?' placeholders in the SQL; bind values with dbRun(ps, list(v1,v2,...)) and release
    // the statement with dbFinalize(ps).
    //   ps = dbPrepare(db, "insert into prices(ticker,close) values(?,?)");
    //   dbRun(ps, list("AAPL", 212.34));
    //   dbRun(ps, list("MSFT", 468.20));
    //   dbFinalize(ps);
    scidb_requireParadigm(db, "sql", "dbPrepare");
    sql2 = scidb_bindsql(db.transport, sql);
    f = scidb_adapter(db.transport);
    stmt = f("prepare", db.conn, sql2);
    ps = tlist(["sciDbStmt", "engine", "transport", "stmt", "conn"], db.engine, db.transport, stmt, db.conn);
endfunction
