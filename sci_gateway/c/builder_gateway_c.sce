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
          "db_mysql_close",    "sci_db_mysql_close"    ; ..
          "db_redis_connect",  "sci_db_redis_connect"  ; ..
          "db_redis_command",  "sci_db_redis_command"  ; ..
          "db_redis_close",    "sci_db_redis_close"    ; ..
          "db_mongo_connect",  "sci_db_mongo_connect"  ; ..
          "db_mongo_find",     "sci_db_mongo_find"     ; ..
          "db_mongo_insert",   "sci_db_mongo_insert"   ; ..
          "db_mongo_update",   "sci_db_mongo_update"   ; ..
          "db_mongo_delete",   "sci_db_mongo_delete"   ; ..
          "db_mongo_close",    "sci_db_mongo_close"    ];

files = ["sci_db_libpq.c"; "sci_db_sqlite.c"; "sci_db_mysql.c"; "sci_db_redis.c"; "sci_db_mongo.c"];

pq  = "/opt/homebrew/opt/libpq";
sq  = "/opt/homebrew/opt/sqlite";
my  = "/opt/homebrew/opt/mysql";
re  = "/opt/homebrew/opt/hiredis";
mg  = "/opt/homebrew/opt/mongo-c-driver";
// mongo-c-driver headers live in versioned subdirs (mongoc-<ver>/, bson-<ver>/); resolve the
// version so a brew upgrade doesn't break the build.
inc_entries = listfiles(mg + "/include");
mgc_inc = mg + "/include/" + inc_entries(grep(inc_entries, "mongoc-")(1));
mgb_inc = mg + "/include/" + inc_entries(grep(inc_entries, "bson-")(1));

cflags = "-I" + pq + "/include -I" + sq + "/include -I" + my + "/include/mysql" + ..
         " -I" + re + "/include -I" + mgc_inc + " -I" + mgb_inc + ..
         " -I/opt/homebrew/opt/gettext/include -D__USE_DEPRECATED_STACK_FUNCTIONS__";

ldflags = "-L" + pq + "/lib -lpq -Wl,-rpath," + pq + "/lib" + ..
          " -L" + sq + "/lib -lsqlite3 -Wl,-rpath," + sq + "/lib" + ..
          " -L" + my + "/lib -lmysqlclient -Wl,-rpath," + my + "/lib" + ..
          " -L" + re + "/lib -lhiredis -Wl,-rpath," + re + "/lib" + ..
          " -L" + mg + "/lib -lmongoc2 -lbson2 -Wl,-rpath," + mg + "/lib";

libs = [];

tbx_build_gateway("scidatabase_native", table, files, path_builder, libs, ldflags, cflags);

clear table files cflags ldflags libs pq sq my path_builder;
