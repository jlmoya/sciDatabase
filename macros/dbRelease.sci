function dbRelease(pool, db)
    // Return a connection to its pool so it can be reused (the connection stays open).
    if typeof(pool) <> "sciDbPool" then error("dbRelease: first argument must be a pool from dbPool."); end
    global SCIDB_POOLS
    rec = SCIDB_POOLS(pool.id);
    conns = rec(3); inuse = rec(4);
    for i = 1:length(conns)
        if conns(i).conn == db.conn & conns(i).transport == db.transport then
            inuse(i) = 0; rec(4) = inuse; SCIDB_POOLS(pool.id) = rec; return;
        end
    end
endfunction
