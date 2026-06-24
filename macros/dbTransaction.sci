function dbTransaction(db, fn)
    // Run fn(db) inside a transaction: COMMIT on success, ROLLBACK if fn raises (then rethrow).
    //   function load(db); dbExec(db,"insert ..."); ... endfunction
    //   dbTransaction(db, load);
    scidb_requireParadigm(db, "sql", "dbTransaction");
    dbBegin(db);
    try
        fn(db);
    catch
        msg = lasterror();
        dbRollback(db);
        error("dbTransaction: rolled back — " + msg);
    end
    dbCommit(db);
endfunction
