function r = dbQuery(db, sql, asMatrix)
    // Run a row-returning statement (SELECT). Returns a struct keyed by column name
    // (numeric columns as column vectors, text as string arrays). asMatrix=%t -> numeric matrix.
    if argn(2) < 3 then asMatrix = %f; end
    if typeof(db) <> "sciDbConn" then error("dbQuery: first argument must be a dbConnect handle"); end
    select db.transport
    case "libpq" then r = scidb_libpq("query", db.conn, sql, asMatrix);
    case "jdbc"  then r = scidb_jdbc("query", db.conn, sql, asMatrix);
    else error("dbQuery: unknown transport " + db.transport);
    end
endfunction
