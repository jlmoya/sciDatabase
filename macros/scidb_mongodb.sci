function varargout = scidb_mongodb(op, varargin)
    // MongoDB transport adapter (native mongo-c-driver). Document paradigm; docs as structs.
    select op
    case "connect" then
        p = varargin(1);
        host = scidb_field(p, "host", "localhost");
        port = scidb_field(p, "port", "27017");
        dbn  = scidb_field(p, "database", scidb_field(p, "dbname", ""));
        uri  = "mongodb://" + host + ":" + port;
        varargout(1) = db_mongo_connect(uri, dbn);
    case "find" then
        coll = varargin(2); filt = varargin(3);
        if typeof(filt) <> "st" then fjson = "{}";
        elseif size(fieldnames(filt), "*") == 0 then fjson = "{}";
        else fjson = scidb_jsonwrite(filt); end
        docs = db_mongo_find(varargin(1), coll, fjson);
        res = list();
        for i = 1:size(docs, "*"), res(i) = scidb_jsonparse(docs(i)); end
        varargout(1) = res;
    case "insert" then
        varargout(1) = db_mongo_insert(varargin(1), varargin(2), scidb_jsonwrite(varargin(3)));
    case "update" then
        fjson = scidb_jsonwrite(varargin(3));
        ujson = "{""$set"":" + scidb_jsonwrite(varargin(4)) + "}";
        varargout(1) = db_mongo_update(varargin(1), varargin(2), fjson, ujson);
    case "delete" then
        varargout(1) = db_mongo_delete(varargin(1), varargin(2), scidb_jsonwrite(varargin(3)));
    case "upsert" then
        fjson = scidb_jsonwrite(varargin(3));
        ujson = "{""$set"":" + scidb_jsonwrite(varargin(4)) + "}";
        varargout(1) = db_mongo_upsert(varargin(1), varargin(2), fjson, ujson);
    case "count" then
        filt = varargin(3);
        if typeof(filt) <> "st" then fjson = "{}";
        elseif size(fieldnames(filt), "*") == 0 then fjson = "{}";
        else fjson = scidb_jsonwrite(filt); end
        varargout(1) = db_mongo_count(varargin(1), varargin(2), fjson);
    case "aggregate" then
        docs = db_mongo_aggregate(varargin(1), varargin(2), "{""pipeline"":" + varargin(3) + "}");
        res = list();
        for i = 1:size(docs, "*"), res(i) = scidb_jsonparse(docs(i)); end
        varargout(1) = res;
    case "collections" then
        varargout(1) = db_mongo_collections(varargin(1));
    case "close" then
        db_mongo_close(varargin(1)); varargout(1) = [];
    else error("scidb_mongodb: unknown op """ + string(op) + """");
    end
endfunction
