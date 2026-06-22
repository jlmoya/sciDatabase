// sciDatabase — top-level builder (macros + libpq gateway), Scilab 2027 / macOS arm64.
mode(-1); lines(0);

toolbox_dir = get_absolute_file_path("builder.sce");

tbx_builder_macros(toolbox_dir);
tbx_builder_gateway(toolbox_dir);
tbx_build_loader(toolbox_dir);
tbx_build_cleaner(toolbox_dir);

clear toolbox_dir;
