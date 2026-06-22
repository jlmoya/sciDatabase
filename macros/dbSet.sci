function dbSet(db, key, val)
    // Redis SET key = val.
    scidb_requireParadigm(db, "keyvalue", "dbSet");
    f = scidb_adapter(db.transport);
    f("set", db.conn, string(key), string(val));
endfunction
