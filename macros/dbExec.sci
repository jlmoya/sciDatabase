function n = dbExec(db, sql, params)
    // Run a non-row-returning statement (INSERT/UPDATE/DELETE/DDL). Returns rows affected.
    //   n = dbExec(db, sql)                      // plain
    //   n = dbExec(db, sql, list(v1,v2,...))     // parameter binding ('?' placeholders)
    scidb_requireParadigm(db, "sql", "dbExec");
    if argn(2) >= 3 then
        ps = dbPrepare(db, sql);
        n = dbRun(ps, params);
        dbFinalize(ps);
    else
        f = scidb_adapter(db.transport);
        n = f("exec", db.conn, sql);
    end
endfunction
