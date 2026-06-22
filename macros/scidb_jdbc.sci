function varargout = scidb_jdbc(op, varargin)
    // JDBC transport adapter (via Scilab's Java bridge + the bundled PostgreSQL driver).
    // NOTE: requires Java interop, which works in the Scilab GUI (STD mode). On this build,
    // headless Java interop hangs, so use the libpq transport for scilab-cli / scilab-adv-cli.
    // ops: "connect"(params)->conn | "query"(conn,sql,asMatrix)->result | "exec"(conn,sql)->n | "close"(conn)
    select op
    case "connect" then
        p = varargin(1);
        host = scidb_field(p, "host", "localhost");
        port = scidb_field(p, "port", "5432");
        db   = scidb_field(p, "database", scidb_field(p, "dbname", ""));
        user = scidb_field(p, "user", "");
        pw   = scidb_field(p, "password", "");
        jimport java.sql.DriverManager;
        url = "jdbc:postgresql://" + host + ":" + port + "/" + db;
        varargout(1) = DriverManager.getConnection(url, user, pw);
    case "query" then
        conn = varargin(1); sql = varargin(2);
        asMatrix = %f; if size(varargin) >= 3 then asMatrix = varargin(3); end
        stmt = conn.createStatement();
        rs   = stmt.executeQuery(sql);
        meta = rs.getMetaData();
        nc   = jautoUnwrap(meta.getColumnCount());
        cols = [];
        for j = 1:nc, cols = [cols, jautoUnwrap(meta.getColumnLabel(j))]; end
        data = [];
        while jautoUnwrap(rs.next())
            row = [];
            for j = 1:nc
                s = jautoUnwrap(rs.getString(j));
                if jautoUnwrap(rs.wasNull()) then s = ""; end
                row = [row, s];
            end
            data = [data; row];
        end
        rs.close(); stmt.close();
        if nc == 0 then
            varargout(1) = struct();
        elseif size(data, 1) == 0 then
            varargout(1) = scidb_toStruct(matrix("", 0, nc), matrix(cols, 1, nc), asMatrix);
        else
            varargout(1) = scidb_toStruct(data, matrix(cols, 1, nc), asMatrix);
        end
    case "exec" then
        conn = varargin(1); sql = varargin(2);
        stmt = conn.createStatement();
        n = jautoUnwrap(stmt.executeUpdate(sql));
        stmt.close();
        varargout(1) = n;
    case "close" then
        varargin(1).close();
        varargout(1) = [];
    else
        error("scidb_jdbc: unknown op """ + string(op) + """");
    end
endfunction
