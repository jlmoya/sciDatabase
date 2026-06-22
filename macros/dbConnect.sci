function db = dbConnect(engine, params)
    // Open a database connection.
    //   db = dbConnect("postgresql", params)
    // params : struct with fields host, port, database (or dbname), user, password,
    //          and optional backend = "auto"(default) | "libpq" | "jdbc".
    // Returns a connection handle (tlist) used by dbQuery/dbExec/dbClose.
    if argn(2) < 2 then params = struct(); end
    engine = convstr(engine);

    reg = dbEngines();
    if ~or(reg.engines == engine) then
        error(msprintf("dbConnect: unknown engine ""%s"" (known: %s)", engine, strcat(reg.engines, ", ")));
    end

    backend = convstr(scidb_field(params, "backend", "auto"));
    if backend == "auto" then
        backend = reg.default_transport(engine);   // libpq — universal + verified
    end

    select backend
    case "libpq" then conn = scidb_libpq("connect", params);
    case "jdbc"  then conn = scidb_jdbc("connect", params);
    else error(msprintf("dbConnect: unknown backend ""%s"" (use libpq or jdbc)", backend));
    end

    db = tlist(["sciDbConn", "engine", "transport", "paradigm", "conn"], ..
               engine, backend, reg.paradigm(engine), conn);
endfunction
