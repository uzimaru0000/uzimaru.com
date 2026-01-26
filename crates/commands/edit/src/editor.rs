use crate::input::{Input, Key};
use crate::screen::{display_width, Screen};
use std::fs;

/// Get byte index from char index in a string
fn char_to_byte_index(s: &str, char_idx: usize) -> usize {
    s.char_indices()
        .nth(char_idx)
        .map(|(i, _)| i)
        .unwrap_or(s.len())
}

/// Get char count of a string
fn char_count(s: &str) -> usize {
    s.chars().count()
}

pub struct Editor {
    /// Lines of text
    lines: Vec<String>,
    /// Cursor row (0-indexed, within the buffer)
    cursor_row: usize,
    /// Cursor column (0-indexed, within the current line)
    cursor_col: usize,
    /// Scroll offset (first visible line)
    scroll_offset: usize,
    /// File path
    filepath: Option<String>,
    /// Whether the buffer has been modified
    modified: bool,
    /// Screen dimensions
    screen: Screen,
    /// Cut buffer (for Ctrl+K/Ctrl+U)
    cut_buffer: Vec<String>,
    /// Input handler
    input: Input,
    /// Whether to quit
    should_quit: bool,
}

impl Editor {
    pub fn new(filepath: Option<String>, rows: usize, cols: usize) -> Self {
        Self {
            lines: vec![String::new()],
            cursor_row: 0,
            cursor_col: 0,
            scroll_offset: 0,
            filepath,
            modified: false,
            screen: Screen::new(rows, cols),
            cut_buffer: Vec::new(),
            input: Input::new(),
            should_quit: false,
        }
    }

    /// Load file content
    pub fn load(&mut self) -> Result<(), String> {
        if let Some(ref path) = self.filepath {
            match fs::read_to_string(path) {
                Ok(content) => {
                    self.lines = if content.is_empty() {
                        vec![String::new()]
                    } else {
                        content.lines().map(|s| s.to_string()).collect()
                    };
                    if self.lines.is_empty() {
                        self.lines.push(String::new());
                    }
                    Ok(())
                }
                Err(e) => {
                    // File doesn't exist - start with empty buffer (new file)
                    if e.kind() == std::io::ErrorKind::NotFound {
                        self.lines = vec![String::new()];
                        Ok(())
                    } else {
                        Err(format!("Cannot open '{}': {}", path, e))
                    }
                }
            }
        } else {
            // No file specified - new buffer
            self.lines = vec![String::new()];
            Ok(())
        }
    }

    /// Save file content
    pub fn save(&mut self) -> Result<(), String> {
        if let Some(ref path) = self.filepath {
            let content = self.lines.join("\n");
            match fs::write(path, content) {
                Ok(_) => {
                    self.modified = false;
                    Ok(())
                }
                Err(e) => Err(format!("Cannot save '{}': {}", path, e)),
            }
        } else {
            Err("No filename".to_string())
        }
    }

    /// Run the editor main loop
    pub fn run(&mut self) -> i32 {
        self.screen.cursor_hide();
        self.refresh_screen();

        while !self.should_quit {
            if let Some(key) = self.input.read_key() {
                self.process_key(key);
                self.refresh_screen();
            } else {
                // No more input - exit
                break;
            }
        }

        self.screen.clear();
        self.screen.cursor_home();
        self.screen.cursor_show();
        self.screen.flush();

        0
    }

    /// Process a key press
    fn process_key(&mut self, key: Key) {
        match key {
            // Ctrl+X: Exit
            Key::Ctrl('x') => {
                self.should_quit = true;
            }
            // Ctrl+O: Save
            Key::Ctrl('o') => {
                if let Err(e) = self.save() {
                    self.show_message(&e);
                } else {
                    self.show_message("Saved");
                }
            }
            // Ctrl+K: Cut line
            Key::Ctrl('k') => {
                self.cut_line();
            }
            // Ctrl+U: Paste (uncut)
            Key::Ctrl('u') => {
                self.paste_lines();
            }
            // Movement
            Key::Up => self.move_cursor_up(),
            Key::Down => self.move_cursor_down(),
            Key::Left => self.move_cursor_left(),
            Key::Right => self.move_cursor_right(),
            Key::Home => self.cursor_col = 0,
            Key::End => {
                self.cursor_col = char_count(self.current_line());
            }
            Key::PageUp => self.page_up(),
            Key::PageDown => self.page_down(),
            // Editing
            Key::Backspace => self.delete_char_before(),
            Key::Delete => self.delete_char_at(),
            Key::Enter => self.insert_newline(),
            Key::Char(c) => self.insert_char(c),
            _ => {}
        }
    }

    /// Move cursor up
    fn move_cursor_up(&mut self) {
        if self.cursor_row > 0 {
            self.cursor_row -= 1;
            self.clamp_cursor_col();
        }
    }

    /// Move cursor down
    fn move_cursor_down(&mut self) {
        if self.cursor_row < self.lines.len() - 1 {
            self.cursor_row += 1;
            self.clamp_cursor_col();
        }
    }

    /// Move cursor left
    fn move_cursor_left(&mut self) {
        if self.cursor_col > 0 {
            self.cursor_col -= 1;
        } else if self.cursor_row > 0 {
            self.cursor_row -= 1;
            self.cursor_col = char_count(self.current_line());
        }
    }

    /// Move cursor right
    fn move_cursor_right(&mut self) {
        let line_len = char_count(self.current_line());
        if self.cursor_col < line_len {
            self.cursor_col += 1;
        } else if self.cursor_row < self.lines.len() - 1 {
            self.cursor_row += 1;
            self.cursor_col = 0;
        }
    }

    /// Page up
    fn page_up(&mut self) {
        let content_rows = self.screen.content_rows();
        if self.cursor_row >= content_rows {
            self.cursor_row -= content_rows;
        } else {
            self.cursor_row = 0;
        }
        self.clamp_cursor_col();
    }

    /// Page down
    fn page_down(&mut self) {
        let content_rows = self.screen.content_rows();
        self.cursor_row = (self.cursor_row + content_rows).min(self.lines.len() - 1);
        self.clamp_cursor_col();
    }

    /// Clamp cursor column to current line length (in chars)
    fn clamp_cursor_col(&mut self) {
        let line_len = char_count(self.current_line());
        if self.cursor_col > line_len {
            self.cursor_col = line_len;
        }
    }

    /// Get current line
    fn current_line(&self) -> &String {
        &self.lines[self.cursor_row]
    }

    /// Insert a character at cursor position
    fn insert_char(&mut self, c: char) {
        let cursor_col = self.cursor_col;
        let line = &mut self.lines[self.cursor_row];
        let byte_idx = char_to_byte_index(line, cursor_col);
        if byte_idx >= line.len() {
            line.push(c);
        } else {
            line.insert(byte_idx, c);
        }
        self.cursor_col += 1;
        self.modified = true;
    }

    /// Insert newline at cursor position
    fn insert_newline(&mut self) {
        let cursor_col = self.cursor_col;
        let cursor_row = self.cursor_row;
        let byte_idx = char_to_byte_index(&self.lines[cursor_row], cursor_col);
        let remainder = self.lines[cursor_row][byte_idx..].to_string();
        self.lines[cursor_row].truncate(byte_idx);

        self.cursor_row += 1;
        self.lines.insert(self.cursor_row, remainder);
        self.cursor_col = 0;
        self.modified = true;
    }

    /// Delete character before cursor (backspace)
    fn delete_char_before(&mut self) {
        if self.cursor_col > 0 {
            let cursor_col = self.cursor_col;
            let cursor_row = self.cursor_row;
            // Get byte range of the character before cursor
            let byte_start = char_to_byte_index(&self.lines[cursor_row], cursor_col - 1);
            let byte_end = char_to_byte_index(&self.lines[cursor_row], cursor_col);
            self.lines[cursor_row].drain(byte_start..byte_end);
            self.cursor_col -= 1;
            self.modified = true;
        } else if self.cursor_row > 0 {
            // Join with previous line
            let current = self.lines.remove(self.cursor_row);
            self.cursor_row -= 1;
            self.cursor_col = char_count(&self.lines[self.cursor_row]);
            self.lines[self.cursor_row].push_str(&current);
            self.modified = true;
        }
    }

    /// Delete character at cursor (delete key)
    fn delete_char_at(&mut self) {
        let line_len = char_count(self.current_line());
        if self.cursor_col < line_len {
            let cursor_col = self.cursor_col;
            let cursor_row = self.cursor_row;
            // Get byte range of the character at cursor
            let byte_start = char_to_byte_index(&self.lines[cursor_row], cursor_col);
            let byte_end = char_to_byte_index(&self.lines[cursor_row], cursor_col + 1);
            self.lines[cursor_row].drain(byte_start..byte_end);
            self.modified = true;
        } else if self.cursor_row < self.lines.len() - 1 {
            // Join with next line
            let next = self.lines.remove(self.cursor_row + 1);
            let cursor_row = self.cursor_row;
            self.lines[cursor_row].push_str(&next);
            self.modified = true;
        }
    }

    /// Cut the current line
    fn cut_line(&mut self) {
        let line = self.lines.remove(self.cursor_row);
        self.cut_buffer.push(line);

        if self.lines.is_empty() {
            self.lines.push(String::new());
        }
        if self.cursor_row >= self.lines.len() {
            self.cursor_row = self.lines.len() - 1;
        }
        self.clamp_cursor_col();
        self.modified = true;
    }

    /// Paste lines from cut buffer
    fn paste_lines(&mut self) {
        if !self.cut_buffer.is_empty() {
            for (i, line) in self.cut_buffer.clone().iter().enumerate() {
                self.lines.insert(self.cursor_row + i + 1, line.clone());
            }
            self.cursor_row += self.cut_buffer.len();
            self.clamp_cursor_col();
            self.modified = true;
        }
    }

    /// Show a temporary message
    fn show_message(&self, msg: &str) {
        let status_row = self.screen.rows - 1;
        self.screen.cursor_move(status_row, 1);
        self.screen.reverse_on();
        print!(" {} ", msg);
        let padding = self.screen.cols.saturating_sub(msg.len() + 2);
        print!("{}", " ".repeat(padding));
        self.screen.reverse_off();
        self.screen.flush();
    }

    /// Refresh the entire screen
    fn refresh_screen(&mut self) {
        self.update_scroll();
        self.screen.cursor_hide();

        // Render content area
        let content_rows = self.screen.content_rows();
        for i in 0..content_rows {
            let line_idx = self.scroll_offset + i;
            let row = i + 1;

            if line_idx < self.lines.len() {
                self.screen.render_line(&self.lines[line_idx], row);
            } else {
                self.screen.cursor_move(row, 1);
                self.screen.clear_to_eol();
                print!("~");
                self.screen.flush();
            }
        }

        // Render status bar
        let filename = self.filepath.as_deref().unwrap_or("[New Buffer]");
        self.screen.render_status_bar(filename, self.modified, self.cursor_row, self.lines.len());

        // Render help bar
        self.screen.render_help_bar();

        // Position cursor
        let screen_row = self.cursor_row - self.scroll_offset + 1;
        let screen_col = self.cursor_screen_col() + 1;
        self.screen.cursor_move(screen_row, screen_col);
        self.screen.cursor_show();
        self.screen.flush();
    }

    /// Update scroll offset to keep cursor visible
    fn update_scroll(&mut self) {
        let content_rows = self.screen.content_rows();

        if self.cursor_row < self.scroll_offset {
            self.scroll_offset = self.cursor_row;
        }
        if self.cursor_row >= self.scroll_offset + content_rows {
            self.scroll_offset = self.cursor_row - content_rows + 1;
        }
    }

    /// Calculate cursor's screen column (accounting for wide characters)
    fn cursor_screen_col(&self) -> usize {
        let line = self.current_line();
        let byte_idx = char_to_byte_index(line, self.cursor_col);
        let prefix = &line[..byte_idx];
        display_width(prefix)
    }
}
