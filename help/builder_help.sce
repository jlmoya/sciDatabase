// Build the sciDatabase help into a jar (run from the Scilab GUI / STD mode — the doc
// compiler is Java-based and hangs in the no-JVM headless cli on this build).
//   exec help/builder_help.sce;
help_dir = get_absolute_file_path("builder_help.sce");
tbx_builder_help_lang("en_US", help_dir);
