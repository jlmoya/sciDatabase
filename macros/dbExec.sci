function n = dbExec(db, sql)
    // Run a non-row-returning statement (INSERT/UPDATE/DELETE/DDL). Returns rows affected.
    scidb_requireParadigm(db, "sql", "dbExec");
    f = scidb_adapter(db.transport);
    n = f("exec", db.conn, sql);
endfunction
