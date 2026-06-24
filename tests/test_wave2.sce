// sciDatabase Wave 2 — introspection (dbTables / dbColumns / dbExists) across paradigms
errcatch_on = %t;
here = get_absolute_file_path("test_wave2.sce");
exec(fullfile(here, "..", "loader.sce"), -1);

function status = sqlSuite(tag, engine, params, ddl1, ddl2)
    db = dbConnect(engine, params);
    dbExec(db, "drop table if exists prices_ps");
    dbExec(db, "drop table if exists trades_ps");
    dbExec(db, ddl1); dbExec(db, ddl2);
    T = dbTables(db);
    has_p = or(T == "prices_ps"); has_t = or(T == "trades_ps");
    C = dbColumns(db, "prices_ps");
    cols = matrix(C.name, 1, -1);
    col_ok = (size(cols,"*")==3) & or(cols=="ticker") & or(cols=="close") & or(cols=="volume");
    ex_ok = dbExists(db, "prices_ps") & ~dbExists(db, "nope_zzz_table");
    dbExec(db, "drop table if exists prices_ps"); dbExec(db, "drop table if exists trades_ps");
    dbClose(db);
    ok = has_p & has_t & col_ok & ex_ok; verdict="FAIL"; if ok then verdict="OK"; end
    status = tag + msprintf(": tbl_p=%d tbl_t=%d cols=%d exists=%d -> %s", ..
        bool2s(has_p), bool2s(has_t), bool2s(col_ok), bool2s(ex_ok), verdict);
endfunction

results = [];

ie = execstr("s = sqlSuite(""SQLITE"", ""sqlite"", struct(""database"", TMPDIR+""/w2.sqlite""), ""create table prices_ps(ticker text, close real, volume integer)"", ""create table trades_ps(id integer, qty integer)"");", "errcatch");
if ie<>0 then s = "SQLITE: ERROR "+lasterror(); end
results = [results; s];

pgp = struct("host","127.0.0.1","port","5433","database","scitest","user","josemoya","password","");
ie = execstr("s = sqlSuite(""POSTGRES"", ""postgresql"", pgp, ""create table prices_ps(ticker text, close double precision, volume bigint)"", ""create table trades_ps(id bigint, qty bigint)"");", "errcatch");
if ie<>0 then s = "POSTGRES: ERROR "+lasterror(); end
results = [results; s];

myp = struct("host","127.0.0.1","port","3307","database","scitest","user","scitest","password","scitest");
ie = execstr("s = sqlSuite(""MYSQL"", ""mysql"", myp, ""create table prices_ps(ticker varchar(16), close double, volume bigint)"", ""create table trades_ps(id bigint, qty bigint)"");", "errcatch");
if ie<>0 then s = "MYSQL: ERROR "+lasterror(); end
results = [results; s];

// MongoDB — collections
ie = execstr([
"dbm = dbConnect(""mongodb"", struct(""host"",""127.0.0.1"",""port"",""27018"",""database"",""scidbtest""));"
"dbDelete(dbm, ""wave2coll"", struct());"
"dbInsert(dbm, ""wave2coll"", struct(""k"",""v"",""n"",1));"
"Tm = dbTables(dbm);"
"mok = or(Tm == ""wave2coll"") & dbExists(dbm, ""wave2coll"") & ~dbExists(dbm, ""nope_coll"");"
"dbDelete(dbm, ""wave2coll"", struct()); dbClose(dbm);"
"vm = ""FAIL""; if mok then vm = ""OK""; end; s = ""MONGO: collection_listed+exists -> "" + vm;"], "errcatch");
if ie<>0 then s = "MONGO: ERROR "+lasterror(); end
results = [results; s];

// Redis — keys
ie = execstr([
"dbr = dbConnect(""redis"", struct(""host"",""127.0.0.1"",""port"",""6380""));"
"dbSet(dbr, ""scidb:wave2:k1"", ""v1"");"
"Tr = dbTables(dbr);"
"rok = or(Tr == ""scidb:wave2:k1"") & dbExists(dbr, ""scidb:wave2:k1"") & ~dbExists(dbr, ""scidb:wave2:missing"");"
"dbDel(dbr, ""scidb:wave2:k1""); dbClose(dbr);"
"vr = ""FAIL""; if rok then vr = ""OK""; end; s = ""REDIS: key_listed+exists -> "" + vr;"], "errcatch");
if ie<>0 then s = "REDIS: ERROR "+lasterror(); end
results = [results; s];

mprintf("\n==== WAVE 2: INTROSPECTION ====\n");
for i=1:size(results,1); mprintf("%s\n", results(i)); end
mprintf("===============================\n");
quit
