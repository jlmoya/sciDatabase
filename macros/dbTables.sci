function t = dbTables(db)
    // List the containers in this connection — tables (SQL), collections (MongoDB), or keys
    // (Redis) — as a string column vector (empty if none). Paradigm-aware.
    select db.paradigm
    case "sql" then
        select db.engine
        case "sqlite" then
            q = "select name from sqlite_master where type = ? and name not like ? order by name";
            p = list("table", "sqlite_%");
        case "postgresql" then
            q = "select tablename as name from pg_catalog.pg_tables where schemaname not in (?, ?) order by tablename";
            p = list("pg_catalog", "information_schema");
        case "mysql" then
            q = "select table_name as name from information_schema.tables where table_schema = database() order by table_name";
            p = list();
        else
            error("dbTables: unsupported SQL engine """ + db.engine + """");
        end
        r = dbQuery(db, q, p);
        if ~isfield(r, "name") then t = []; else t = r.name; end
    case "document" then
        f = scidb_adapter(db.transport);
        t = f("collections", db.conn);
    case "keyvalue" then
        t = dbCmd(db, "KEYS", "*");
    else
        error("dbTables: unsupported paradigm """ + db.paradigm + """");
    end
    if ~isempty(t) then t = matrix(t, -1, 1); end
endfunction
