function dbPoolClose(pool)
    // Close every connection in a pool and free the pool.
    if typeof(pool) <> "sciDbPool" then error("dbPoolClose: argument must be a pool from dbPool."); end
    global SCIDB_POOLS
    rec = SCIDB_POOLS(pool.id);
    conns = rec(3);
    for i = 1:length(conns), dbClose(conns(i)); end
    SCIDB_POOLS(pool.id) = [];
endfunction
