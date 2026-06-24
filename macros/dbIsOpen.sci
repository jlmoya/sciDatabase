function b = dbIsOpen(db)
    // Test whether a connection is alive by round-tripping a trivial request. Returns %t/%f
    // (also %f for anything that is not a dbConnect handle, or a closed connection).
    if typeof(db) <> "sciDbConn" then b = %f; return; end
    b = %t;
    try
        select db.paradigm
        case "sql"      then dbQuery(db, "select 1 as ok");
        case "document" then dbTables(db);
        case "keyvalue" then dbCmd(db, "PING");
        else b = %f;
        end
    catch
        b = %f;
    end
endfunction
