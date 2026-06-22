// A simple JSON parser

function out = scidb_jsonparse(JSON)
    true = "%T"
    false = "%F"
    oldnull = null, null = "%Nan" // Backup the null() function and set variable
    
    JSON_text_cat = strcat(JSON);
    
    // The following section is required to convert multidimensional 
    // arrays into a rectangular matrix:
    JSON_text_with_matrix = JSON_text_cat
    Occurances = length(regexp(JSON_text_cat, "/\],\s*\[/"))
    for i=1:Occurances
        JSON_text_with_matrix = strsubst(JSON_text_with_matrix, "/\],\s*\[/", "]; [", 'r')
    end
    
    // The following line replaces all occurances of \" with \quot
    // since a backslash-quote is the only JSON escape character we 
    // need to worry about:
    JSON_text_sanitized = strsubst(JSON_text_with_matrix, "\""", "\quot")
    
    // The following section replaces JSON delimiters in the sanitized 
    // JSON string with Scilab delimiters:
    out_text = strsubst(strsubst(strsubst(JSON_text_sanitized, '{', "struct("), '}', ")"), ':', ',')
    
    // The following line reverts the replacement of \" with \quot:
    out_text_unQuot = strsubst(out_text, "\quot", "\""""")
    
    // The following line evaluates the 
    // resulting Scilab string to form a Scilab structure. 
    out = evstr(out_text_unQuot)
    
    // The following line restores the null function:
    null = oldnull

endfunction
