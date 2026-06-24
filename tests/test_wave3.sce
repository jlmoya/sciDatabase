// sciDatabase Wave 3 — MongoDB completeness: count / findOne / aggregate / upsert
errcatch_on = %t;
here = get_absolute_file_path("test_wave3.sce");
exec(fullfile(here, "..", "loader.sce"), -1);

function status = mongoSuite()
    db = dbConnect("mongodb", struct("host","127.0.0.1","port","27018","database","scidbtest"));
    dbDelete(db, "wave3", struct());                       // clear (empty filter -> match all)
    dbInsert(db, "wave3", struct("ticker","AAPL","close",212.34,"sector","tech"));
    dbInsert(db, "wave3", struct("ticker","MSFT","close",468.20,"sector","tech"));
    dbInsert(db, "wave3", struct("ticker","XOM", "close",110.00,"sector","energy"));
    dbInsert(db, "wave3", struct("ticker","AAPL","close",213.00,"sector","tech"));

    // dbCount (all + filtered)
    count_ok = (dbCount(db,"wave3") == 4) & (dbCount(db,"wave3",struct("sector","tech")) == 3);

    // dbFindOne (hit + miss)
    one = dbFindOne(db, "wave3", struct("ticker","XOM"));
    miss = dbFindOne(db, "wave3", struct("ticker","NOPE"));
    findone_ok = isfield(one,"ticker") & (one("ticker")=="XOM") & isempty(fieldnames(miss));

    // dbAggregate — group by sector, count per group
    agg = dbAggregate(db, "wave3", "[{""$group"":{""_id"":""$sector"",""n"":{""$sum"":1}}}]");
    techn = -1;
    for i = 1:length(agg)
        g = agg(i); if g("_id") == "tech" then techn = g("n"); end
    end
    agg_ok = (length(agg) == 2) & (techn == 3);

    // upsert — GOOG does not exist, so it is inserted
    nup = dbUpdate(db, "wave3", struct("ticker","GOOG"), struct("close",175.0,"sector","tech"), %t);
    goog = dbFindOne(db, "wave3", struct("ticker","GOOG"));
    upsert_ok = (nup >= 1) & (dbCount(db,"wave3") == 5) & isfield(goog,"close") & (goog("close") == 175.0);

    dbDelete(db, "wave3", struct());
    dbClose(db);

    ok = count_ok & findone_ok & agg_ok & upsert_ok;
    verdict = "FAIL"; if ok then verdict = "OK"; end
    status = msprintf("MONGO: count=%d findOne=%d aggregate=%d upsert=%d -> %s", ..
        bool2s(count_ok), bool2s(findone_ok), bool2s(agg_ok), bool2s(upsert_ok), verdict);
endfunction

ie = execstr("s = mongoSuite();", "errcatch");
if ie<>0 then s = "MONGO: ERROR "+lasterror(); end

mprintf("\n==== WAVE 3: MONGODB COMPLETENESS ====\n%s\n======================================\n", s);
quit
