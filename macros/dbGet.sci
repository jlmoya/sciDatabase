function v = dbGet(db, key)
    // Redis GET. Returns the value (string), or [] if the key is absent.
    scidb_requireParadigm(db, "keyvalue", "dbGet");
    f = scidb_adapter(db.transport);
    v = f("get", db.conn, string(key));
endfunction
