function cs = scidb_connstr(params)
    // Build a libpq connection string from a params struct.
    // Recognized fields: host, port, database (or dbname), user, password, sslmode, options.
    cs = "";
    function cs = add(cs, key, val)
        if val <> "" then
            if cs <> "" then cs = cs + " "; end
            cs = cs + key + "=" + val;
        end
    endfunction
    f = fieldnames(params);
    host = scidb_field(params, "host", "localhost");
    port = scidb_field(params, "port", "5432");
    db   = scidb_field(params, "database", scidb_field(params, "dbname", ""));
    user = scidb_field(params, "user", "");
    pw   = scidb_field(params, "password", "");
    cs = add(cs, "host", host);
    cs = add(cs, "port", port);
    cs = add(cs, "dbname", db);
    cs = add(cs, "user", user);
    cs = add(cs, "password", pw);
    cs = add(cs, "sslmode", scidb_field(params, "sslmode", ""));
    cs = add(cs, "options", scidb_field(params, "options", ""));
endfunction
