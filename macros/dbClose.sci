function dbClose(db)
    // Close a database connection.
    if typeof(db) <> "sciDbConn" then error("dbClose: argument must be a dbConnect handle"); end
    f = scidb_adapter(db.transport);
    f("close", db.conn);
endfunction
