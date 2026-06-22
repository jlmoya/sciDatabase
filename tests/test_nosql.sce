// sciDatabase — NoSQL round-trip (MongoDB document + Redis key-value). Edit params to your servers.
exec(fullfile(get_absolute_file_path("test_nosql.sce"), "..", "loader.sce"), -1);

// MongoDB (document paradigm)
try
    db = dbConnect("mongodb", struct("host","localhost","port","27018","database","scitest"));
    dbInsert(db, "demo", struct("ticker","AAPL","close",212.34));
    r = dbFind(db, "demo", struct("ticker","AAPL"));
    mprintf("[mongodb] found %d doc(s), close=%.2f\n", length(r), r(1).close);
    dbUpdate(db, "demo", struct("ticker","AAPL"), struct("close",220.0));
    dbDelete(db, "demo", struct("ticker","AAPL"));
    dbClose(db);
catch
    mprintf("[mongodb] skipped (%s)\n", lasterror());
end

// Redis (key-value paradigm)
try
    db = dbConnect("redis", struct("host","localhost","port","6380"));
    dbSet(db, "price:AAPL", "212.34");
    mprintf("[redis] GET price:AAPL = %s\n", dbGet(db, "price:AAPL"));
    dbCmd(db, "RPUSH", "tickers", "AAPL", "MSFT");
    mprintf("[redis] LRANGE tickers = %s\n", strcat(dbCmd(db,"LRANGE","tickers","0","-1"), ","));
    dbDel(db, "price:AAPL"); dbCmd(db, "DEL", "tickers");
    dbClose(db);
catch
    mprintf("[redis] skipped (%s)\n", lasterror());
end
