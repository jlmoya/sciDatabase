// genlib the sciDatabase macros
mode(-1);
macros_path = get_absolute_file_path("buildmacros.sce");
genlib("sciDatabaselib", macros_path, %f, %t);
clear macros_path;
