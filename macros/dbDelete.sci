function n = dbDelete(db, coll, filter)
    // Delete matching documents. Returns deleted count.
    scidb_requireParadigm(db, "document", "dbDelete");
    f = scidb_adapter(db.transport);
    n = f("delete", db.conn, string(coll), filter);
endfunction
