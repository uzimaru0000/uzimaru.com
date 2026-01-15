wit_bindgen::generate!({
    world: "mkdir",
});

struct Mkdir;

impl Guest for Mkdir {
    fn run(input: CommandInput) -> i32 {
        let mut parents = false;
        let mut targets: Vec<String> = Vec::new();

        // Parse arguments
        for arg in input.args.iter().skip(1) {
            if arg == "-p" || arg == "--parents" {
                parents = true;
            } else if arg.starts_with('-') {
                // Skip unknown flags
            } else {
                // Resolve path
                let path = if arg.starts_with('/') {
                    arg.clone()
                } else {
                    format!("{}/{}", input.cwd.trim_end_matches('/'), arg)
                };
                targets.push(path);
            }
        }

        if targets.is_empty() {
            eprintln!("mkdir: missing operand");
            return 1;
        }

        for target in targets {
            let result = if parents {
                std::fs::create_dir_all(&target)
            } else {
                std::fs::create_dir(&target)
            };

            if let Err(e) = result {
                eprintln!("mkdir: cannot create directory '{}': {}", target, e);
                return 1;
            }
        }

        0
    }
}

export!(Mkdir);
