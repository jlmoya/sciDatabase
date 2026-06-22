function dbClose(db)
    // Close a database connection.
    if typeof(db) <> "sciDbConn" then error("dbClose: argument must be a dbConnect handle"); end
    select db.transport
    case "libpq" then scidb_libpq("close", db.conn);
    case "jdbc"  then scidb_jdbc("close", db.conn);
    end
endfunction
