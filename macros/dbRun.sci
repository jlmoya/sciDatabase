function r = dbRun(ps, params, asMatrix)
    // Execute a prepared statement (from dbPrepare) with bound parameters. Returns a struct
    // keyed by column name for row-returning statements, or the number of affected rows for
    // INSERT/UPDATE/DELETE. params is a list(v1,v2,...) (or a numeric/string vector).
    if type(ps) <> 16 | ps(1)(1) <> "sciDbStmt" then
        error("dbRun: first argument must be a prepared statement from dbPrepare.");
    end
    if argn(2) < 2 then params = []; end
    if argn(2) < 3 then asMatrix = %f; end
    [pv, mask] = scidb_paramvec(params);
    f = scidb_adapter(ps.transport);
    r = f("run", ps.stmt, pv, mask, asMatrix);
endfunction
