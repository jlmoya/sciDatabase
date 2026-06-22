function r = dbQuery(db, sql, asMatrix)
    // Run a row-returning statement (SELECT). Returns a struct keyed by column name
    // (numeric columns as column vectors, text as string arrays). asMatrix=%t -> numeric matrix.
    if argn(2) < 3 then asMatrix = %f; end
    if typeof(db) <> "sciDbConn" then error("dbQuery: first argument must be a dbConnect handle"); end
    f = scidb_adapter(db.transport);
    r = f("query", db.conn, sql, asMatrix);
endfunction
