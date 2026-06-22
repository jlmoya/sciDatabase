// sciDatabase — libpq gateway builder (PostgreSQL native transport), macOS arm64.
mode(-1); lines(0);
path_builder = get_absolute_file_path("builder_gateway_c.sce");

// (scilab name, C function) pairs
table = [ "db_libpq_connect", "sci_db_libpq_connect" ; ..
          "db_libpq_exec",    "sci_db_libpq_exec"    ; ..
          "db_libpq_close",   "sci_db_libpq_close"   ];

files = ["sci_db_libpq.c"];

// Homebrew libpq + gettext (localization.h -> <libintl.h>)
pq = "/opt/homebrew/opt/libpq";
cflags  = "-I" + pq + "/include -I/opt/homebrew/opt/gettext/include -D__USE_DEPRECATED_STACK_FUNCTIONS__";
ldflags = "-L" + pq + "/lib -lpq -Wl,-rpath," + pq + "/lib";
libs    = [];

tbx_build_gateway("scidatabase_libpq", table, files, path_builder, libs, ldflags, cflags);

clear table files cflags ldflags libs pq path_builder;
