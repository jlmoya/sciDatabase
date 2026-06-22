function v = scidb_field(params, name, default)
    // Case-insensitive struct-field lookup with a default. Numbers are coerced to string.
    v = default;
    if ~isstruct(params) then return; end
    f = fieldnames(params);
    for i = 1:size(f, "*")
        if convstr(f(i)) == convstr(name) then
            raw = params(f(i));
            if type(raw) == 1 then v = string(raw); else v = raw; end
            return;
        end
    end
endfunction
