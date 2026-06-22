// sciDatabase — gateway dispatcher
mode(-1); lines(0);
gw_dir = get_absolute_file_path("builder_gateway.sce");
tbx_builder_gateway_lang("c", gw_dir);
tbx_build_gateway_loader("c", gw_dir);
clear gw_dir;
