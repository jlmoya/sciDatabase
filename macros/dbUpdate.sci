function n = dbUpdate(db, coll, filter, changes, upsert)
    // Update matching documents: applies {$set: changes}. Returns the modified count.
    //   n = dbUpdate(db, "prices", struct("ticker","AAPL"), struct("close",212.5))
    //   n = dbUpdate(db, "prices", filter, changes, %t)  // upsert: insert if none match
    scidb_requireParadigm(db, "document", "dbUpdate");
    if argn(2) < 5 then upsert = %f; end
    f = scidb_adapter(db.transport);
    if upsert then
        n = f("upsert", db.conn, string(coll), filter, changes);
    else
        n = f("update", db.conn, string(coll), filter, changes);
    end
endfunction
