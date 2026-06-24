function dbRollback(db)
    // Roll back the current transaction (SQL engines).
    scidb_requireParadigm(db, "sql", "dbRollback");
    dbExec(db, "ROLLBACK");
endfunction
