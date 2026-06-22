function r = dbInfo(db)
    // Describe a connection handle: engine / transport / paradigm.
    if typeof(db) <> "sciDbConn" then error("dbInfo: argument must be a dbConnect handle"); end
    r = struct("engine", db.engine, "transport", db.transport, "paradigm", db.paradigm);
endfunction
