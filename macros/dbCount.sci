function n = dbCount(db, coll, filter)
    // Count documents in a collection matching an optional filter (MongoDB).
    //   n = dbCount(db, "prices")                          // all documents
    //   n = dbCount(db, "prices", struct("ticker","AAPL")) // matching a filter
    scidb_requireParadigm(db, "document", "dbCount");
    if argn(2) < 3 then filter = struct(); end
    f = scidb_adapter(db.transport);
    n = f("count", db.conn, string(coll), filter);
endfunction
