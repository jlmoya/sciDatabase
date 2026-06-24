function dbBegin(db)
    // Begin an explicit transaction (SQL engines). Pair with dbCommit / dbRollback, or use the
    // dbTransaction(db, fn) scope helper for automatic commit-on-success / rollback-on-error.
    scidb_requireParadigm(db, "sql", "dbBegin");
    dbExec(db, "BEGIN");
endfunction
