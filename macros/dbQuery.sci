function r = dbQuery(db, sql, params, asMatrix)
    // Run a row-returning statement (SELECT). Returns a struct keyed by column name
    // (numeric columns as column vectors, text as string arrays).
    //   r = dbQuery(db, sql)                       // plain query
    //   r = dbQuery(db, sql, list(v1,v2,...))      // parameter binding ('?' placeholders)
    //   r = dbQuery(db, sql, params, asMatrix)     // asMatrix=%t -> numeric matrix
    // Back-compat: dbQuery(db, sql, asMatrix) still works when the 3rd arg is %t/%f.
    scidb_requireParadigm(db, "sql", "dbQuery");
    havep = %f; am = %f;
    if argn(2) == 3 then
        if type(params) == 4 then
            am = params;                  // dbQuery(db, sql, asMatrix) — legacy form
        else
            havep = %t;
        end
    elseif argn(2) >= 4 then
        havep = %t; am = asMatrix;
    end
    if havep then
        ps = dbPrepare(db, sql);
        r = dbRun(ps, params, am);
        dbFinalize(ps);
    else
        f = scidb_adapter(db.transport);
        r = f("query", db.conn, sql, am);
    end
endfunction
