function varargout = scidb_redis(op, varargin)
    // Redis transport adapter (native hiredis). Key-value paradigm.
    select op
    case "connect" then
        p = varargin(1);
        host = scidb_field(p, "host", "localhost");
        port = strtod(scidb_field(p, "port", "6379"));
        varargout(1) = db_redis_connect(host, port);
    case "get" then
        varargout(1) = db_redis_command(varargin(1), ["GET", varargin(2)]);
    case "set" then
        varargout(1) = db_redis_command(varargin(1), ["SET", varargin(2), varargin(3)]);
    case "del" then
        varargout(1) = db_redis_command(varargin(1), ["DEL", varargin(2)]);
    case "cmd" then
        varargout(1) = db_redis_command(varargin(1), varargin(2));   // varargin(2) = string vector
    case "close" then
        db_redis_close(varargin(1)); varargout(1) = [];
    else error("scidb_redis: unknown op """ + string(op) + """");
    end
endfunction
