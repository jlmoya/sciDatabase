function scidb_requireConn(db, verb)
    // Ensure the first argument is a dbConnect handle; raise a clear error otherwise.
    if typeof(db) <> "sciDbConn" then
        error(verb + ": first argument must be a dbConnect handle.");
    end
endfunction
