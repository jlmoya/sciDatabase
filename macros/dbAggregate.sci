function r = dbAggregate(db, coll, pipeline)
    // Run an aggregation pipeline (MongoDB). Returns a list of result-document structs.
    // pipeline is a raw JSON array string (recommended — $-operators are JSON keys Scilab
    // structs can't name), or a list of stage structs for $-free stages:
    //   r = dbAggregate(db, "prices", ...
    //         "[{""$group"":{""_id"":""$ticker"",""avg"":{""$avg"":""$close""}}}]");
    scidb_requireParadigm(db, "document", "dbAggregate");
    if type(pipeline) == 10 then
        arr = pipeline;                                   // raw JSON array string
    elseif type(pipeline) == 15 then
        parts = [];
        for i = 1:length(pipeline), parts = [parts, scidb_jsonwrite(pipeline(i))]; end
        arr = "[" + strcat(parts, ",") + "]";
    else
        error("dbAggregate: pipeline must be a JSON array string or a list of stage structs.");
    end
    f = scidb_adapter(db.transport);
    r = f("aggregate", db.conn, string(coll), arr);
endfunction
