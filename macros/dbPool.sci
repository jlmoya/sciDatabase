function pool = dbPool(engine, params, n)
    // Create a pool of n open connections to reuse across many short operations (avoids the
    // connect/disconnect cost per call and caps concurrent connections).
    //   pool = dbPool("postgresql", params, 4);
    //   db = dbAcquire(pool); r = dbQuery(db, "..."); dbRelease(pool, db);
    //   dbPoolClose(pool);
    global SCIDB_POOLS
    if type(SCIDB_POOLS) <> 15 then SCIDB_POOLS = list(); end
    if argn(2) < 3 then n = 4; end
    if n < 1 then error("dbPool: size must be >= 1."); end
    conns = list();
    for i = 1:n, conns(i) = dbConnect(engine, params); end
    rec = list(engine, params, conns, zeros(1, n));     // engine, params, handles, in-use mask
    k = 0;
    for i = 1:length(SCIDB_POOLS)
        if type(SCIDB_POOLS(i)) <> 15 then k = i; break; end   // reuse a freed slot
    end
    if k == 0 then k = length(SCIDB_POOLS) + 1; end
    SCIDB_POOLS(k) = rec;
    pool = tlist(["sciDbPool", "id", "engine", "size"], k, engine, n);
endfunction
