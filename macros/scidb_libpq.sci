function varargout = scidb_libpq(op, varargin)
    // libpq transport adapter (PostgreSQL, native — works in every binary incl. scilab-cli).
    // ops: "connect"(params)->id | "query"(id,sql,asMatrix)->result | "exec"(id,sql)->nAffected | "close"(id)
    select op
    case "connect" then
        cs = scidb_connstr(varargin(1));
        varargout(1) = db_libpq_connect(cs);
    case "query" then
        id = varargin(1); sql = varargin(2);
        asMatrix = %f; if size(varargin) >= 3 then asMatrix = varargin(3); end
        [rc, data, cols] = db_libpq_exec(id, sql);
        if size(cols, "*") == 0 then
            varargout(1) = struct();          // not a row-returning statement
        else
            varargout(1) = scidb_toStruct(data, cols, asMatrix);
        end
    case "exec" then
        [rc, data, cols] = db_libpq_exec(varargin(1), varargin(2));
        varargout(1) = rc;
    case "close" then
        db_libpq_close(varargin(1));
        varargout(1) = [];
    else
        error("scidb_libpq: unknown op """ + string(op) + """");
    end
endfunction
