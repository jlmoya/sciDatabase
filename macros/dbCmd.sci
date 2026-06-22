function r = dbCmd(db, varargin)
    // Run any Redis command: dbCmd(db, "LPUSH", "mylist", "a", "b"). Returns the reply.
    scidb_requireParadigm(db, "keyvalue", "dbCmd");
    words = [];
    for i = 1:size(varargin), words = [words, string(varargin(i))]; end
    f = scidb_adapter(db.transport);
    r = f("cmd", db.conn, words);
endfunction
