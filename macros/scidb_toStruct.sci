function s = scidb_toStruct(data, cols, asMatrix)
    // Convert a raw result (string matrix `data` + column names `cols`) into the
    // sciDatabase result shape. Default: a struct keyed by column name, each field a
    // numeric column vector when every value parses as a number, else a string column.
    // asMatrix = %t  ->  return a plain numeric matrix (all columns must be numeric).
    if argn(2) < 3 then asMatrix = %f; end
    [nr, nc] = size(data);

    if asMatrix then
        s = zeros(nr, nc);
        for j = 1:nc
            for i = 1:nr
                s(i, j) = scidb_num(data(i, j));
            end
        end
        return;
    end

    s = struct();
    for j = 1:nc
        colvals = matrix(data(:, j), nr, 1);   // nr x 1 string column
        isnum = %t;
        for i = 1:nr
            if ~scidb_isnum(colvals(i)) then isnum = %f; break; end
        end
        if isnum & nr > 0 then
            v = zeros(nr, 1);
            for i = 1:nr, v(i) = scidb_num(colvals(i)); end
            s(cols(j)) = v;
        else
            s(cols(j)) = colvals;
        end
    end
endfunction

function b = scidb_isnum(str)
    // empty (SQL NULL) counts as numeric -> becomes %nan in a numeric column
    if str == "" then b = %t; return; end
    [v, rem] = strtod(str);
    b = (rem == "");
endfunction

function v = scidb_num(str)
    if str == "" then v = %nan; return; end
    v = strtod(str);
endfunction
