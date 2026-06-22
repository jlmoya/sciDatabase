function db = dbConnect(engine, params)
    // Open a database connection.
    //   db = dbConnect("postgresql"|"mysql"|"sqlite", params)
    // params : struct with fields host, port, database (or dbname; for sqlite a file path),
    //          user, password, and optional backend = "auto"(default)|<native>|"jdbc".
    // Native default transports: postgresql->libpq, mysql->mysql, sqlite->sqlite3 (all work
    // headless). backend="jdbc" routes through the Java driver (GUI/STD mode only on this build).
    if argn(2) < 2 then params = struct(); end
    engine = convstr(engine);

    reg = dbEngines();
    if ~or(reg.engines == engine) then
        error(msprintf("dbConnect: unknown engine ""%s"" (known: %s)", engine, strcat(reg.engines, ", ")));
    end

    backend = convstr(scidb_field(params, "backend", "auto"));
    if backend == "auto" then
        backend = reg.default_transport(engine);
    end

    params.engine = engine;                 // used by the JDBC adapter to build the URL
    f = scidb_adapter(backend);
    conn = f("connect", params);

    db = tlist(["sciDbConn", "engine", "transport", "paradigm", "conn"], ..
               engine, backend, reg.paradigm(engine), conn);
endfunction
