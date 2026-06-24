// sciDatabase Wave 4 — robustness & lifecycle: validation, dbIsOpen, idempotent close
errcatch_on = %t;
here = get_absolute_file_path("test_wave4.sce");
exec(fullfile(here, "..", "loader.sce"), -1);

function status = lifecycle()
    db = dbConnect("sqlite", struct("database", TMPDIR+"/w4.sqlite"));
    open1 = dbIsOpen(db);                              // %t — alive
    ie  = execstr("dbQuery(42, ""select 1"")", "errcatch");   // verb on a non-handle -> error
    val_ok = (ie <> 0);
    nonhandle_ok = (dbIsOpen(42) == %f);              // dbIsOpen on a non-handle -> %f, no crash
    dbClose(db);
    closed = (dbIsOpen(db) == %f);                     // closed -> not alive
    ie2 = execstr("dbClose(db)", "errcatch");         // double close -> safe no-op
    dbl_ok = (ie2 == 0);
    ok = open1 & val_ok & nonhandle_ok & closed & dbl_ok;
    verdict="FAIL"; if ok then verdict="OK"; end
    status = msprintf("LIFECYCLE(sqlite): open=%d validate=%d nonhandle=%d closed=%d dblclose=%d -> %s", ..
        bool2s(open1), bool2s(val_ok), bool2s(nonhandle_ok), bool2s(closed), bool2s(dbl_ok), verdict);
endfunction

function status = pingOne(tag, engine, params)
    db = dbConnect(engine, params);
    alive = dbIsOpen(db);
    dbClose(db);
    dead = (dbIsOpen(db) == %f);
    ok = alive & dead; verdict="FAIL"; if ok then verdict="OK"; end
    status = msprintf("ISOPEN(%s): alive=%d after_close=%d -> %s", tag, bool2s(alive), bool2s(dead), verdict);
endfunction

results = [];
ie = execstr("s = lifecycle();", "errcatch"); if ie<>0 then s="LIFECYCLE: ERROR "+lasterror(); end
results = [results; s];
ie = execstr("s = pingOne(""postgres"", ""postgresql"", struct(""host"",""127.0.0.1"",""port"",""5433"",""database"",""scitest"",""user"",""josemoya"",""password"",""""));", "errcatch"); if ie<>0 then s="ISOPEN(postgres): ERROR "+lasterror(); end
results = [results; s];
ie = execstr("s = pingOne(""mysql"", ""mysql"", struct(""host"",""127.0.0.1"",""port"",""3307"",""database"",""scitest"",""user"",""scitest"",""password"",""scitest""));", "errcatch"); if ie<>0 then s="ISOPEN(mysql): ERROR "+lasterror(); end
results = [results; s];
ie = execstr("s = pingOne(""mongo"", ""mongodb"", struct(""host"",""127.0.0.1"",""port"",""27018"",""database"",""scidbtest""));", "errcatch"); if ie<>0 then s="ISOPEN(mongo): ERROR "+lasterror(); end
results = [results; s];
ie = execstr("s = pingOne(""redis"", ""redis"", struct(""host"",""127.0.0.1"",""port"",""6380""));", "errcatch"); if ie<>0 then s="ISOPEN(redis): ERROR "+lasterror(); end
results = [results; s];

mprintf("\n==== WAVE 4: ROBUSTNESS & LIFECYCLE ====\n");
for i=1:size(results,1); mprintf("%s\n", results(i)); end
mprintf("========================================\n");
quit
