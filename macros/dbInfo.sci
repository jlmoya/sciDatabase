function r = dbInfo(db)
    // Describe a connection handle: engine / transport / paradigm.
    scidb_requireConn(db, "dbInfo");
    r = struct("engine", db.engine, "transport", db.transport, "paradigm", db.paradigm);
endfunction
