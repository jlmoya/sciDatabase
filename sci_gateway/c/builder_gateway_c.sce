// sciDatabase — native gateway builder: PostgreSQL (libpq) + SQLite (libsqlite3) + MySQL
// (libmysqlclient), macOS arm64. One gateway lib exposes all three engines' primitives.
mode(-1); lines(0);
path_builder = get_absolute_file_path("builder_gateway_c.sce");

// (scilab name, C function) pairs
table = [ "db_libpq_connect",  "sci_db_libpq_connect"  ; ..
          "db_libpq_exec",     "sci_db_libpq_exec"     ; ..
          "db_libpq_close",    "sci_db_libpq_close"    ; ..
          "db_sqlite_connect", "sci_db_sqlite_connect" ; ..
          "db_sqlite_exec",    "sci_db_sqlite_exec"    ; ..
          "db_sqlite_close",   "sci_db_sqlite_close"   ; ..
          "db_mysql_connect",  "sci_db_mysql_connect"  ; ..
          "db_mysql_exec",     "sci_db_mysql_exec"     ; ..
          "db_mysql_close",    "sci_db_mysql_close"    ];

files = ["sci_db_libpq.c"; "sci_db_sqlite.c"; "sci_db_mysql.c"];

pq  = "/opt/homebrew/opt/libpq";
sq  = "/opt/homebrew/opt/sqlite";
my  = "/opt/homebrew/opt/mysql";

cflags = "-I" + pq + "/include -I" + sq + "/include -I" + my + "/include/mysql" + ..
         " -I/opt/homebrew/opt/gettext/include -D__USE_DEPRECATED_STACK_FUNCTIONS__";

ldflags = "-L" + pq + "/lib -lpq -Wl,-rpath," + pq + "/lib" + ..
          " -L" + sq + "/lib -lsqlite3 -Wl,-rpath," + sq + "/lib" + ..
          " -L" + my + "/lib -lmysqlclient -Wl,-rpath," + my + "/lib";

libs = [];

tbx_build_gateway("scidatabase_native", table, files, path_builder, libs, ldflags, cflags);

clear table files cflags ldflags libs pq sq my path_builder;
