function n = dbInsert(db, coll, doc)
    // Insert one document (a struct). Returns the inserted count (1).
    scidb_requireParadigm(db, "document", "dbInsert");
    f = scidb_adapter(db.transport);
    n = f("insert", db.conn, string(coll), doc);
endfunction
