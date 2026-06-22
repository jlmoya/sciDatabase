function varargout = scidb_sqlite(op, varargin)
    // SQLite transport adapter (native libsqlite3; file-based, no server, works everywhere).
    select op
    case "connect" then
        p = varargin(1);
        file = scidb_field(p, "database", scidb_field(p, "dbname", scidb_field(p, "file", ":memory:")));
        varargout(1) = db_sqlite_connect(file);
    case "query" then
        asMatrix = %f; if size(varargin) >= 3 then asMatrix = varargin(3); end
        [rc, data, cols] = db_sqlite_exec(varargin(1), varargin(2));
        if size(cols, "*") == 0 then varargout(1) = struct();
        else varargout(1) = scidb_toStruct(data, cols, asMatrix); end
    case "exec" then
        [rc, data, cols] = db_sqlite_exec(varargin(1), varargin(2));
        varargout(1) = rc;
    case "close" then
        db_sqlite_close(varargin(1)); varargout(1) = [];
    else error("scidb_sqlite: unknown op """ + string(op) + """");
    end
endfunction
