function r = dbFind(db, coll, filter)
    // MongoDB find. Returns a list of structs (one per matching document).
    //   r = dbFind(db, "prices")                       // all docs
    //   r = dbFind(db, "prices", struct("ticker","AAPL"))
    scidb_requireParadigm(db, "document", "dbFind");
    if argn(2) < 3 then filter = struct(); end
    f = scidb_adapter(db.transport);
    r = f("find", db.conn, string(coll), filter);
endfunction
