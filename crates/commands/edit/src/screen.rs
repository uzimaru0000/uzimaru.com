use std::io::{self, Write};

/// Screen rendering utilities using ANSI escape sequences
pub struct Screen {
    pub rows: usize,
    pub cols: usize,
}

impl Screen {
    pub fn new(rows: usize, cols: usize) -> Self {
        Self { rows, cols }
    }

    /// Clear the entire screen
    pub fn clear(&self) {
        print!("\x1b[2J");
        self.flush();
    }

    /// Move cursor to home position (top-left)
    pub fn cursor_home(&self) {
        print!("\x1b[H");
        self.flush();
    }

    /// Move cursor to specified position (1-indexed)
    pub fn cursor_move(&self, row: usize, col: usize) {
        print!("\x1b[{};{}H", row, col);
        self.flush();
    }

    /// Clear from cursor to end of line
    pub fn clear_to_eol(&self) {
        print!("\x1b[K");
        self.flush();
    }

    /// Hide cursor
    pub fn cursor_hide(&self) {
        print!("\x1b[?25l");
        self.flush();
    }

    /// Show cursor
    pub fn cursor_show(&self) {
        print!("\x1b[?25h");
        self.flush();
    }

    /// Start reverse video (for status bar)
    pub fn reverse_on(&self) {
        print!("\x1b[7m");
    }

    /// End reverse video
    pub fn reverse_off(&self) {
        print!("\x1b[0m");
    }

    /// Flush stdout
    pub fn flush(&self) {
        let _ = io::stdout().flush();
    }

    /// Render a single line (truncated to screen width)
    pub fn render_line(&self, line: &str, row: usize) {
        self.cursor_move(row, 1);
        self.clear_to_eol();

        // Handle display width for CJK characters
        let mut display_col = 0;
        let mut output = String::new();

        for c in line.chars() {
            let char_width = if c >= '\u{1100}' {
                // CJK and other wide characters
                if is_wide_char(c) { 2 } else { 1 }
            } else {
                1
            };

            if display_col + char_width > self.cols {
                break;
            }

            output.push(c);
            display_col += char_width;
        }

        print!("{}", output);
        self.flush();
    }

    /// Render status bar (bottom - 1)
    pub fn render_status_bar(&self, filename: &str, modified: bool, line: usize, total_lines: usize) {
        let status_row = self.rows - 1;
        self.cursor_move(status_row, 1);

        let modified_indicator = if modified { " [Modified]" } else { "" };
        let status = format!(
            " edit: {}{} | Ln {}/{}",
            filename,
            modified_indicator,
            line + 1,
            total_lines
        );

        self.reverse_on();

        // Pad status to fill the line
        let padding = if status.len() < self.cols {
            " ".repeat(self.cols - status.len())
        } else {
            String::new()
        };

        print!("{}{}", status, padding);
        self.reverse_off();
        self.flush();
    }

    /// Render help bar (bottom)
    pub fn render_help_bar(&self) {
        let help_row = self.rows;
        self.cursor_move(help_row, 1);
        self.clear_to_eol();

        let help = "^X Exit  ^O Save  ^K Cut  ^U Paste";

        // Truncate if needed
        if help.len() <= self.cols {
            print!("{}", help);
        } else {
            print!("{}", &help[..self.cols]);
        }
        self.flush();
    }

    /// Get content area height (screen minus status and help bars)
    pub fn content_rows(&self) -> usize {
        if self.rows >= 2 {
            self.rows - 2
        } else {
            1
        }
    }
}

/// Check if a character is a wide (full-width) character
fn is_wide_char(c: char) -> bool {
    let cp = c as u32;

    // CJK ranges (simplified)
    (0x1100..=0x115F).contains(&cp)    // Hangul Jamo
        || (0x2E80..=0x9FFF).contains(&cp)    // CJK characters
        || (0xAC00..=0xD7A3).contains(&cp)    // Hangul Syllables
        || (0xF900..=0xFAFF).contains(&cp)    // CJK Compatibility Ideographs
        || (0xFE10..=0xFE1F).contains(&cp)    // Vertical Forms
        || (0xFE30..=0xFE6F).contains(&cp)    // CJK Compatibility Forms
        || (0xFF00..=0xFF60).contains(&cp)    // Fullwidth Forms
        || (0xFFE0..=0xFFE6).contains(&cp)    // Fullwidth Forms
        || (0x20000..=0x2FFFF).contains(&cp)  // CJK Extension B+
        || (0x30000..=0x3FFFF).contains(&cp)  // CJK Extension G+
}

/// Calculate display width of a string
pub fn display_width(s: &str) -> usize {
    s.chars().map(|c| if is_wide_char(c) { 2 } else { 1 }).sum()
}
