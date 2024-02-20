// Vulk
// Build
// February 2024

build :: () {
    workspace := compiler_create_workspace("Main Workspace");
    if !workspace {
        print("Workspace creation failed.\n");
        return;
    }

    options := get_build_options(workspace);
    options.output_executable_name = "vulk";

    // NOTE: this refers to a relative path from this (build.jai) file.
    options.output_path = "bin";
    options.intermediate_path = "bin/.build";
    options.output_type = .EXECUTABLE;
    options.text_output_flags = 2;

    set_build_options(options, workspace);
    set_build_options_dc(.{do_output=false});

	compiler_begin_intercept(workspace);

    add_build_file(tprint("%/src/main.jai", #filepath), workspace);

	// Set up ctags options
	ctags: CTags;
	ctags.output_filename = "src/tags";
	ctags.base_path = tprint("%/src", #filepath);
	defer reset(*ctags);

	while true {
		message := compiler_wait_for_message();
		if !message continue;

		if message.workspace == workspace {
			process_message(*ctags, message);
		}

		if message.kind == .COMPLETE break;
	}
}

#run build();

#import "Basic";
#import "Compiler";
#import "File";

#import "ctags";
