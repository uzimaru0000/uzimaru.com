use std::io::Write;

wit_bindgen::generate!({
    world: "ls",
});

struct Ls;

#[derive(Default)]
struct Options {
    show_all: bool,      // -a: 隠しファイルも表示
    long_format: bool,   // -l: 詳細表示
    one_per_line: bool,  // -1: 1行1ファイル
    human_readable: bool, // -h: 人間が読みやすいサイズ
    reverse: bool,       // -r: 逆順ソート
    recursive: bool,     // -R: 再帰表示
}

const TERMINAL_WIDTH: usize = 80;

struct FileEntry {
    name: String,
    is_dir: bool,
    is_executable: bool,
    size: u64,
}

// ANSI color codes
const COLOR_RESET: &str = "\x1b[0m";
const COLOR_DIR: &str = "\x1b[1;34m";   // Bold blue
const COLOR_EXEC: &str = "\x1b[1;32m";  // Bold green

fn format_size(size: u64, human_readable: bool) -> String {
    if !human_readable {
        return format!("{:>8}", size);
    }

    const UNITS: &[&str] = &["B", "K", "M", "G", "T"];
    let mut size = size as f64;
    let mut unit_idx = 0;

    while size >= 1024.0 && unit_idx < UNITS.len() - 1 {
        size /= 1024.0;
        unit_idx += 1;
    }

    if unit_idx == 0 {
        format!("{:>7}{}", size as u64, UNITS[unit_idx])
    } else {
        format!("{:>6.1}{}", size, UNITS[unit_idx])
    }
}

fn list_dir(path: &str, opts: &Options, prefix: &str) -> i32 {
    match std::fs::read_dir(path) {
        Ok(entries) => {
            let mut files: Vec<FileEntry> = entries
                .filter_map(|e| e.ok())
                .filter(|e| {
                    if opts.show_all {
                        true
                    } else {
                        !e.file_name().to_string_lossy().starts_with('.')
                    }
                })
                .map(|e| {
                    let name = e.file_name().to_string_lossy().to_string();
                    let is_dir = e.file_type().map(|t| t.is_dir()).unwrap_or(false);
                    let is_executable = name.ends_with(".wasm") || name.ends_with(".sh");
                    let size = e.metadata().map(|m| m.len()).unwrap_or(0);
                    FileEntry { name, is_dir, is_executable, size }
                })
                .collect();

            files.sort_by(|a, b| a.name.cmp(&b.name));
            if opts.reverse {
                files.reverse();
            }

            if !prefix.is_empty() {
                println!("{}:", prefix);
            }

            // 表示名の長さを計算（色コードを除く）
            let display_entries: Vec<(String, usize)> = files
                .iter()
                .map(|file| {
                    let (color, suffix) = if file.is_dir {
                        (COLOR_DIR, "/")
                    } else if file.is_executable {
                        (COLOR_EXEC, "")
                    } else {
                        (COLOR_RESET, "")
                    };
                    let display_len = file.name.len() + suffix.len();
                    let colored = format!("{}{}{}{}", color, file.name, suffix, COLOR_RESET);
                    (colored, display_len)
                })
                .collect();

            if opts.long_format {
                for (i, file) in files.iter().enumerate() {
                    let size_str = format_size(file.size, opts.human_readable);
                    println!("{} {}", size_str, display_entries[i].0);
                }
            } else if opts.one_per_line {
                for (colored, _) in &display_entries {
                    println!("{}", colored);
                }
            } else {
                // 横並び表示
                let max_len = display_entries.iter().map(|(_, len)| *len).max().unwrap_or(0);
                let col_width = max_len + 2; // 2スペース間隔
                let cols = (TERMINAL_WIDTH / col_width).max(1);

                for (i, (colored, len)) in display_entries.iter().enumerate() {
                    let padding = col_width - len;
                    if (i + 1) % cols == 0 || i == display_entries.len() - 1 {
                        println!("{}", colored);
                    } else {
                        print!("{}{}", colored, " ".repeat(padding));
                        let _ = std::io::stdout().flush();
                    }
                }
            }

            // 再帰表示
            if opts.recursive {
                for file in &files {
                    if file.is_dir {
                        let sub_path = format!("{}/{}", path.trim_end_matches('/'), file.name);
                        let sub_prefix = if prefix.is_empty() {
                            file.name.clone()
                        } else {
                            format!("{}/{}", prefix, file.name)
                        };
                        println!();
                        list_dir(&sub_path, opts, &sub_prefix);
                    }
                }
            }

            0
        }
        Err(e) => {
            eprintln!("ls: {}: {}", path, e);
            1
        }
    }
}

impl Guest for Ls {
    fn run(input: CommandInput) -> i32 {
        let mut opts = Options::default();
        let mut target_arg: Option<String> = None;

        for arg in input.args.iter().skip(1) {
            if arg.starts_with('-') && arg.len() > 1 && !arg.starts_with("--") {
                for c in arg.chars().skip(1) {
                    match c {
                        'a' => opts.show_all = true,
                        'l' => opts.long_format = true,
                        '1' => opts.one_per_line = true,
                        'h' => opts.human_readable = true,
                        'r' => opts.reverse = true,
                        'R' => opts.recursive = true,
                        _ => {
                            eprintln!("ls: invalid option -- '{}'", c);
                            eprintln!("Usage: ls [-1alhRr] [path]");
                            return 1;
                        }
                    }
                }
            } else if arg == "--help" {
                println!("Usage: ls [OPTION]... [PATH]");
                println!();
                println!("Options:");
                println!("  -a        show hidden files (starting with .)");
                println!("  -l        use long listing format");
                println!("  -1        list one file per line");
                println!("  -h        human-readable sizes (with -l)");
                println!("  -r        reverse order while sorting");
                println!("  -R        list subdirectories recursively");
                println!("  --help    display this help");
                return 0;
            } else if target_arg.is_none() {
                target_arg = Some(arg.clone());
            }
        }

        // Resolve to absolute path
        let target = match target_arg {
            Some(arg) => {
                if arg.starts_with('/') {
                    arg
                } else {
                    format!("{}/{}", input.cwd.trim_end_matches('/'), arg)
                }
            }
            None => input.cwd.clone(),
        };

        list_dir(&target, &opts, "")
    }
}

export!(Ls);
