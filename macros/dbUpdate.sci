function n = dbUpdate(db, coll, filter, changes)
    // Update matching documents: applies {$set: changes}. Returns modified count.
    scidb_requireParadigm(db, "document", "dbUpdate");
    f = scidb_adapter(db.transport);
    n = f("update", db.conn, string(coll), filter, changes);
endfunction
