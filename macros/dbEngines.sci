function r = dbEngines()
    // Registry of supported engines, paradigms, transports. Extend here when adding an engine.
    r = struct();
    r.engines = ["postgresql" "mysql" "sqlite" "mongodb" "redis"];
    r.paradigm = struct("postgresql","sql", "mysql","sql", "sqlite","sql", ..
                        "mongodb","document", "redis","keyvalue");
    r.transports = struct("postgresql",["libpq" "jdbc"], "mysql",["mysql" "jdbc"], ..
                          "sqlite",["sqlite3" "jdbc"], "mongodb",["mongoc"], "redis",["redis"]);
    // native transports are universal + verified (work in scilab-cli); jdbc is GUI-only here.
    r.default_transport = struct("postgresql","libpq", "mysql","mysql", "sqlite","sqlite3", ..
                                 "mongodb","mongoc", "redis","redis");
endfunction
