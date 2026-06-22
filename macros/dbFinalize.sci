function dbFinalize(ps)
    // Release a prepared statement created by dbPrepare (frees the server-side statement).
    if type(ps) <> 16 | ps(1)(1) <> "sciDbStmt" then
        error("dbFinalize: argument must be a prepared statement from dbPrepare.");
    end
    f = scidb_adapter(ps.transport);
    f("finalize", ps.stmt);
endfunction
