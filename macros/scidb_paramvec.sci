function [v, mask] = scidb_paramvec(params)
    // Marshal bind parameters to a 1xN string row vector v plus a 1xN null-mask (1 = SQL NULL).
    // Everything is bound as text and the engine coerces to the column type. Accepts
    // list(v1,v2,...) (mixed types, the canonical form) or a plain numeric/string vector.
    // An empty matrix [] element binds as SQL NULL; "" binds as an empty string.
    v = []; mask = [];
    if isempty(params) then return; end
    if type(params) == 15 then            // list
        for i = 1:length(params)
            e = params(i);
            v = [v, scidb_one(e)]; mask = [mask, bool2s(isempty(e))];
        end
    else                                  // numeric or string vector (no NULLs possible)
        p = matrix(params, 1, -1);
        for i = 1:size(p, "*")
            v = [v, scidb_one(p(i))]; mask = [mask, 0];
        end
    end
endfunction

function s = scidb_one(e)
    if type(e) == 10 then                 // string
        s = e(1);
    elseif isempty(e) then
        s = "";                           // placeholder; ignored when the null-mask is set
    elseif type(e) == 4 then              // boolean -> 1/0 (accepted by all engines)
        if e(1) then s = "1"; else s = "0"; end
    else                                  // number -> text (integers exact, else 15 sig digits)
        x = e(1);
        if x == round(x) & abs(x) < 2^53 then
            s = msprintf("%.0f", x);
        else
            s = msprintf("%.15g", x);
        end
    end
endfunction
