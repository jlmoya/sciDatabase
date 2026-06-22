function n = dbDel(db, key)
    // Redis DEL. Returns the number of keys removed.
    scidb_requireParadigm(db, "keyvalue", "dbDel");
    f = scidb_adapter(db.transport);
    n = f("del", db.conn, string(key));
endfunction
