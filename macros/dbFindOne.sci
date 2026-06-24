function r = dbFindOne(db, coll, filter)
    // Return the first matching document as a struct (MongoDB), or an empty struct if none match.
    //   d = dbFindOne(db, "prices", struct("ticker","AAPL"))
    scidb_requireParadigm(db, "document", "dbFindOne");
    if argn(2) < 3 then filter = struct(); end
    docs = dbFind(db, coll, filter);
    if length(docs) >= 1 then r = docs(1); else r = struct(); end
endfunction
