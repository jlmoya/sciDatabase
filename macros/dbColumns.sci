function c = dbColumns(db, tbl)
    // Describe a table's columns (SQL engines). Returns a struct with fields .name and .type
    // (string arrays, one entry per column, in declaration order).
    scidb_requireParadigm(db, "sql", "dbColumns");
    select db.engine
    case "sqlite" then
        q = "select name, type from pragma_table_info(?)";
    case "postgresql" then
        q = "select column_name as name, data_type as type from information_schema.columns where table_name = ? order by ordinal_position";
    case "mysql" then
        q = "select column_name as name, data_type as type from information_schema.columns where table_schema = database() and table_name = ? order by ordinal_position";
    else
        error("dbColumns: unsupported SQL engine """ + db.engine + """");
    end
    c = dbQuery(db, q, list(tbl));
endfunction
