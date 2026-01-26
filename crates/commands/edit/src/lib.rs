mod editor;
mod input;
mod screen;

use editor::Editor;

wit_bindgen::generate!({
    world: "edit",
});

struct Edit;

// Default terminal size (will be adjusted based on actual terminal)
const DEFAULT_ROWS: usize = 24;
const DEFAULT_COLS: usize = 80;

impl Guest for Edit {
    fn run(input: CommandInput) -> i32 {
        // Parse arguments
        let args: Vec<&str> = input.args.iter().map(|s| s.as_str()).collect();

        // Get terminal size from environment if available
        let rows = get_env_usize(&input.env, "LINES").unwrap_or(DEFAULT_ROWS);
        let cols = get_env_usize(&input.env, "COLUMNS").unwrap_or(DEFAULT_COLS);

        // Get filepath argument
        let filepath = if args.len() > 1 {
            let arg = args[1];
            if arg == "--help" || arg == "-h" {
                print_help();
                return 0;
            }

            // Resolve to absolute path
            let path = if arg.starts_with('/') {
                arg.to_string()
            } else {
                format!("{}/{}", input.cwd.trim_end_matches('/'), arg)
            };
            Some(path)
        } else {
            None
        };

        // Create and run editor
        let mut editor = Editor::new(filepath, rows, cols);

        if let Err(e) = editor.load() {
            eprintln!("edit: {}", e);
            return 1;
        }

        editor.run()
    }
}

fn print_help() {
    println!("edit - A simple text editor");
    println!();
    println!("Usage: edit [FILE]");
    println!();
    println!("Key bindings:");
    println!("  Arrow keys    Move cursor");
    println!("  Home/End      Beginning/end of line");
    println!("  PgUp/PgDn     Page up/down");
    println!("  Backspace     Delete character before cursor");
    println!("  Delete        Delete character at cursor");
    println!("  Enter         Insert new line");
    println!("  Ctrl+X        Exit");
    println!("  Ctrl+O        Save file");
    println!("  Ctrl+K        Cut current line");
    println!("  Ctrl+U        Paste cut line(s)");
}

fn get_env_usize(env: &[(String, String)], key: &str) -> Option<usize> {
    env.iter()
        .find(|(k, _)| k == key)
        .and_then(|(_, v)| v.parse().ok())
}

export!(Edit);
