wit_bindgen::generate!({
    world: "rm",
});

struct Rm;

impl Guest for Rm {
    fn run(input: CommandInput) -> i32 {
        let mut recursive = false;
        let mut force = false;
        let mut targets: Vec<String> = Vec::new();

        // Parse arguments
        for arg in input.args.iter().skip(1) {
            match arg.as_str() {
                "-r" | "-R" | "--recursive" => recursive = true,
                "-f" | "--force" => force = true,
                "-rf" | "-fr" => {
                    recursive = true;
                    force = true;
                }
                s if s.starts_with('-') => {
                    // Check for combined flags like -rf
                    if s.contains('r') || s.contains('R') {
                        recursive = true;
                    }
                    if s.contains('f') {
                        force = true;
                    }
                }
                _ => {
                    // Resolve path
                    let path = if arg.starts_with('/') {
                        arg.clone()
                    } else {
                        format!("{}/{}", input.cwd.trim_end_matches('/'), arg)
                    };
                    targets.push(path);
                }
            }
        }

        if targets.is_empty() {
            eprintln!("rm: missing operand");
            return 1;
        }

        for target in targets {
            let metadata = match std::fs::metadata(&target) {
                Ok(m) => m,
                Err(e) => {
                    if !force {
                        eprintln!("rm: cannot remove '{}': {}", target, e);
                        return 1;
                    }
                    continue;
                }
            };

            if metadata.is_dir() {
                if !recursive {
                    eprintln!("rm: cannot remove '{}': Is a directory", target);
                    return 1;
                }
                if let Err(e) = std::fs::remove_dir_all(&target) {
                    if !force {
                        eprintln!("rm: cannot remove '{}': {}", target, e);
                        return 1;
                    }
                }
            } else {
                if let Err(e) = std::fs::remove_file(&target) {
                    if !force {
                        eprintln!("rm: cannot remove '{}': {}", target, e);
                        return 1;
                    }
                }
            }
        }

        0
    }
}

export!(Rm);
