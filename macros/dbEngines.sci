function r = dbEngines()
    // Registry of supported engines, paradigms, transports. Extend here when adding an engine.
    r = struct();
    r.engines = ["postgresql" "mysql" "sqlite"];
    r.paradigm = struct("postgresql","sql", "mysql","sql", "sqlite","sql");
    r.transports = struct("postgresql",["libpq" "jdbc"], "mysql",["mysql" "jdbc"], "sqlite",["sqlite3" "jdbc"]);
    // native transports are universal + verified (work in scilab-cli); jdbc is GUI-only here.
    r.default_transport = struct("postgresql","libpq", "mysql","mysql", "sqlite","sqlite3");
endfunction
