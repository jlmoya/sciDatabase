function out = scidb_bindsql(transport, sql)
    // Translate uniform '?' placeholders to the engine's native form so toolbox code stays
    // engine-agnostic: PostgreSQL/libpq wants $1,$2,...; SQLite and MySQL use '?' as-is.
    // '?' characters inside string literals are left untouched.
    if transport <> "libpq" then out = sql; return; end
    q = ascii(39);                        // single quote (avoids a quote-in-string macro-parser quirk)
    cc = strsplit(sql, "");
    out = ""; k = 0; inq = %f;
    for i = 1:size(cc, "*")
        ch = cc(i);
        if ch == q then
            inq = ~inq; out = out + ch;
        elseif ch == "?" & ~inq then
            k = k + 1; out = out + "$" + string(k);
        else
            out = out + ch;
        end
    end
endfunction
