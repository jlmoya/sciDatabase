function scidb_requireParadigm(db, want, verb)
    // Ensure a verb is used on a handle of the right paradigm (sql / document / keyvalue).
    if typeof(db) <> "sciDbConn" then error(verb + ": first argument must be a dbConnect handle"); end
    if db.paradigm <> want then
        error(msprintf("%s: requires a ""%s"" connection, but this handle is ""%s"" (engine %s)", ..
              verb, want, db.paradigm, db.engine));
    end
endfunction
