function varargout = scidb_mysql(op, varargin)
    // MySQL transport adapter (native libmysqlclient).
    select op
    case "connect" then
        p = varargin(1);
        host = scidb_field(p, "host", "localhost");
        port = strtod(scidb_field(p, "port", "3306"));
        db   = scidb_field(p, "database", scidb_field(p, "dbname", ""));
        user = scidb_field(p, "user", "");
        pw   = scidb_field(p, "password", "");
        varargout(1) = db_mysql_connect(host, port, db, user, pw);
    case "query" then
        asMatrix = %f; if size(varargin) >= 3 then asMatrix = varargin(3); end
        [rc, data, cols] = db_mysql_exec(varargin(1), varargin(2));
        if size(cols, "*") == 0 then varargout(1) = struct();
        else varargout(1) = scidb_toStruct(data, cols, asMatrix); end
    case "exec" then
        [rc, data, cols] = db_mysql_exec(varargin(1), varargin(2));
        varargout(1) = rc;
    case "prepare" then
        varargout(1) = db_mysql_prepare(varargin(1), varargin(2));
    case "run" then
        asMatrix = %f; if size(varargin) >= 3 then asMatrix = varargin(3); end
        [rc, data, cols] = db_mysql_run(varargin(1), varargin(2));
        if size(cols, "*") == 0 then varargout(1) = rc;
        else varargout(1) = scidb_toStruct(data, cols, asMatrix); end
    case "finalize" then
        db_mysql_finalize(varargin(1)); varargout(1) = [];
    case "close" then
        db_mysql_close(varargin(1)); varargout(1) = [];
    else error("scidb_mysql: unknown op """ + string(op) + """");
    end
endfunction
