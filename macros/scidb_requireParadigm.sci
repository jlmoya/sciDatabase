function scidb_requireParadigm(db, want, verb)
    // Ensure a verb is used on a handle of the right paradigm (sql / document / keyvalue).
    scidb_requireConn(db, verb);
    if db.paradigm <> want then
        error(msprintf("%s: requires a ""%s"" connection, but this handle is ""%s"" (engine %s)", ..
              verb, want, db.paradigm, db.engine));
    end
endfunction
