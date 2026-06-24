function b = dbExists(db, name)
    // Test whether a table (SQL), collection (MongoDB), or key (Redis) exists. Returns %t/%f.
    scidb_requireConn(db, "dbExists");
    select db.paradigm
    case "sql" then
        select db.engine
        case "sqlite" then
            q = "select count(*) as c from sqlite_master where type = ? and name = ?";
            p = list("table", name);
        case "postgresql" then
            q = "select count(*) as c from pg_catalog.pg_tables where tablename = ?";
            p = list(name);
        case "mysql" then
            q = "select count(*) as c from information_schema.tables where table_schema = database() and table_name = ?";
            p = list(name);
        else
            error("dbExists: unsupported SQL engine """ + db.engine + """");
        end
        r = dbQuery(db, q, p);
        b = (r.c(1) >= 1);
    case "document" then
        b = or(dbTables(db) == name);
    case "keyvalue" then
        b = (dbCmd(db, "EXISTS", name) >= 1);
    else
        error("dbExists: unsupported paradigm """ + db.paradigm + """");
    end
endfunction
