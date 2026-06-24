function db = dbAcquire(pool)
    // Borrow an idle connection from a pool. Errors if every connection is in use.
    if typeof(pool) <> "sciDbPool" then error("dbAcquire: argument must be a pool from dbPool."); end
    global SCIDB_POOLS
    rec = SCIDB_POOLS(pool.id);
    conns = rec(3); inuse = rec(4);
    freeidx = find(inuse == 0);
    if isempty(freeidx) then
        error(msprintf("dbAcquire: pool exhausted (all %d connections in use).", pool.size));
    end
    idx = freeidx(1);
    inuse(idx) = 1; rec(4) = inuse; SCIDB_POOLS(pool.id) = rec;
    db = conns(idx);
endfunction
