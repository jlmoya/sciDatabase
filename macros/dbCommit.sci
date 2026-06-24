function dbCommit(db)
    // Commit the current transaction (SQL engines).
    scidb_requireParadigm(db, "sql", "dbCommit");
    dbExec(db, "COMMIT");
endfunction
