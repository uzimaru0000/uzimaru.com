wit_bindgen::generate!({
    world: "touch",
});

struct Touch;

impl Guest for Touch {
    fn run(input: CommandInput) -> i32 {
        let mut targets: Vec<String> = Vec::new();

        // Parse arguments
        for arg in input.args.iter().skip(1) {
            if arg.starts_with('-') {
                // Skip flags (touch typically has -a, -m, -c, etc. but we ignore them)
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
            eprintln!("touch: missing file operand");
            return 1;
        }

        for target in targets {
            // Check if file exists
            if std::fs::metadata(&target).is_ok() {
                // File exists, we could update timestamps but WASI support is limited
                // For now, just skip existing files
                continue;
            }

            // Create empty file
            if let Err(e) = std::fs::write(&target, b"") {
                eprintln!("touch: cannot touch '{}': {}", target, e);
                return 1;
            }
        }

        0
    }
}

export!(Touch);
