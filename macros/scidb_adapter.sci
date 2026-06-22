function f = scidb_adapter(transport)
    // Map a transport name to its adapter. Adding an engine = add a case + register in dbEngines.
    select transport
    case "libpq"   then f = scidb_libpq;
    case "sqlite3" then f = scidb_sqlite;
    case "mysql"   then f = scidb_mysql;
    case "jdbc"    then f = scidb_jdbc;
    else error("scidb_adapter: unknown transport """ + string(transport) + """");
    end
endfunction
