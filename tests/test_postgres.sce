// sciDatabase — PostgreSQL round-trip test.
// Adjust params to your DB. Run headless (scilab-cli/adv-cli) for libpq; run in the GUI to also
// exercise the JDBC backend (headless Java interop hangs on this Scilab build).
exec(fullfile(get_absolute_file_path("test_postgres.sce"), "..", "loader.sce"), -1);
p = struct("host","localhost","port","5433","database","scitest","user","josemoya","password","");

function runBackend(p, backend)
    p.backend = backend;
    db = dbConnect("postgresql", p);
    mprintf("[%s] connected: %s\n", backend, dbInfo(db).transport);
    r = dbQuery(db, "select ticker, close from prices order by id limit 2");
    mprintf("[%s] query: %s=%.2f, %s=%.2f\n", backend, r.ticker(1), r.close(1), r.ticker(2), r.close(2));
    M = dbQuery(db, "select close from prices", %t);
    mprintf("[%s] matrix avg close = %.2f\n", backend, mean(M));
    dbClose(db);
endfunction

runBackend(p, "libpq");                         // works in every binary
if getscilabmode() == "STD" then
    runBackend(p, "jdbc");                       // GUI only
else
    mprintf("[jdbc] skipped (headless Java interop unsupported; run in the GUI to test)\n");
end
