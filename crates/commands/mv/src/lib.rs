wit_bindgen::generate!({
    world: "mv",
});

struct Mv;

impl Guest for Mv {
    fn run(input: CommandInput) -> i32 {
        let mut targets: Vec<String> = Vec::new();

        // Parse arguments
        for arg in input.args.iter().skip(1) {
            if arg.starts_with('-') {
                // Skip flags (mv typically has -f, -i, -n, etc. but we ignore them)
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

        if targets.len() < 2 {
            eprintln!("mv: missing destination file operand after '{}'",
                targets.first().map(|s| s.as_str()).unwrap_or(""));
            return 1;
        }

        let dest = targets.pop().unwrap();
        let dest_is_dir = std::fs::metadata(&dest)
            .map(|m| m.is_dir())
            .unwrap_or(false);

        // Multiple sources require destination to be a directory
        if targets.len() > 1 && !dest_is_dir {
            eprintln!("mv: target '{}' is not a directory", dest);
            return 1;
        }

        for source in targets {
            let final_dest = if dest_is_dir {
                // Extract filename from source
                let filename = source
                    .rsplit('/')
                    .next()
                    .unwrap_or(&source);
                format!("{}/{}", dest.trim_end_matches('/'), filename)
            } else {
                dest.clone()
            };

            if let Err(e) = std::fs::rename(&source, &final_dest) {
                eprintln!("mv: cannot move '{}' to '{}': {}", source, final_dest, e);
                return 1;
            }
        }

        0
    }
}

export!(Mv);
