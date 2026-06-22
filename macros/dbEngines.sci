function r = dbEngines()
    // Registry of supported engines and transports. Extend here when adding engines.
    // Each row: engine, paradigm, available transports, default transport.
    r = struct();
    r.engines = "postgresql";
    r.paradigm = struct("postgresql", "sql");
    r.transports = struct("postgresql", ["libpq" "jdbc"]);
    // libpq is native + works in every binary (incl. scilab-cli); JDBC needs the GUI
    // on this build (headless Java interop hangs), so libpq is the default transport.
    r.default_transport = struct("postgresql", "libpq");
endfunction
