function js = scidb_jsonwrite(v)
    // Minimal struct/value -> JSON encoder for sciDatabase (MongoDB documents & filters).
    // Handles structs (recursively), strings, numbers, booleans, and 1-D arrays of those.
    select typeof(v)
    case "st" then
        f = fieldnames(v);
        if size(f, "*") == 0 then
            js = "{}";                        // empty struct -> match-all filter / empty document
        else
            parts = [];
            for i = 1:size(f, "*")
                parts = [parts, scidb_jstr(f(i)) + ":" + scidb_jsonwrite(v(f(i)))];
            end
            js = "{" + strcat(parts, ",") + "}";
        end
    case "string" then
        if size(v, "*") <= 1 then
            js = scidb_jstr(v);
        else
            parts = []; for i = 1:size(v, "*"), parts = [parts, scidb_jstr(v(i))]; end
            js = "[" + strcat(parts, ",") + "]";
        end
    case "constant" then
        if size(v, "*") == 0 then
            js = "null";
        elseif size(v, "*") == 1 then
            js = scidb_jnum(v);
        else
            parts = []; for i = 1:size(v, "*"), parts = [parts, scidb_jnum(v(i))]; end
            js = "[" + strcat(parts, ",") + "]";
        end
    case "boolean" then
        if v then js = "true"; else js = "false"; end
    else
        js = scidb_jstr(string(v));
    end
endfunction

function s = scidb_jstr(x)
    x = strsubst(x, "\", "\\");
    x = strsubst(x, """", "\""");
    x = strsubst(x, ascii(10), "\n");
    x = strsubst(x, ascii(9),  "\t");
    s = """" + x + """";
endfunction

function s = scidb_jnum(x)
    if isnan(x) then s = "null";
    elseif x == round(x) & abs(x) < 1e15 then s = msprintf("%d", x);
    else s = msprintf("%.17g", x);
    end
endfunction
