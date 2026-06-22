function n = dbExec(db, sql)
    // Run a non-row-returning statement (INSERT/UPDATE/DELETE/DDL). Returns rows affected.
    if typeof(db) <> "sciDbConn" then error("dbExec: first argument must be a dbConnect handle"); end
    select db.transport
    case "libpq" then n = scidb_libpq("exec", db.conn, sql);
    case "jdbc"  then n = scidb_jdbc("exec", db.conn, sql);
    else error("dbExec: unknown transport " + db.transport);
    end
endfunction
