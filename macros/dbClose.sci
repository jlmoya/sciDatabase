function dbClose(db)
    // Close a database connection. Safe to call more than once (the second call is a no-op).
    scidb_requireConn(db, "dbClose");
    f = scidb_adapter(db.transport);
    f("close", db.conn);
endfunction
