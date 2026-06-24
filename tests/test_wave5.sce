// sciDatabase Wave 5 — connection pooling
errcatch_on = %t;
here = get_absolute_file_path("test_wave5.sce");
exec(fullfile(here, "..", "loader.sce"), -1);

function status = poolSuite()
    pool = dbPool("sqlite", struct("database", TMPDIR+"/w5.sqlite"), 2);
    a = dbAcquire(pool);
    b = dbAcquire(pool);                          // pool now 2/2
    ie = execstr("c = dbAcquire(pool)", "errcatch");
    exhaust_ok = (ie <> 0);                       // third acquire fails

    dbExec(a, "create table if not exists pooltest(x integer)");
    dbExec(a, "delete from pooltest");
    dbExec(a, "insert into pooltest values(7)");
    r = dbQuery(a, "select x from pooltest");
    use_ok = (r.x(1) == 7);

    dbRelease(pool, a);                           // give one back
    c = dbAcquire(pool);                          // reuses the freed slot
    reuse_ok = dbIsOpen(c);

    dbRelease(pool, b); dbRelease(pool, c);
    dbPoolClose(pool);
    closed_ok = (dbIsOpen(b) == %f);              // every pooled connection now closed

    ok = exhaust_ok & use_ok & reuse_ok & closed_ok;
    verdict = "FAIL"; if ok then verdict = "OK"; end
    status = msprintf("POOL(sqlite,n=2): exhaust=%d use=%d reuse=%d closed=%d -> %s", ..
        bool2s(exhaust_ok), bool2s(use_ok), bool2s(reuse_ok), bool2s(closed_ok), verdict);
endfunction

ie = execstr("s = poolSuite();", "errcatch");
if ie<>0 then s = "POOL: ERROR "+lasterror(); end
mprintf("\n==== WAVE 5: CONNECTION POOLING ====\n%s\n====================================\n", s);
quit
