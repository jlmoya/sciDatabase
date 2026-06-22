function n = dbExec(db, sql)
    // Run a non-row-returning statement (INSERT/UPDATE/DELETE/DDL). Returns rows affected.
    if typeof(db) <> "sciDbConn" then error("dbExec: first argument must be a dbConnect handle"); end
    f = scidb_adapter(db.transport);
    n = f("exec", db.conn, sql);
endfunction
