use std::io::{self, Read};

#[derive(Debug, Clone, PartialEq)]
pub enum Key {
    Char(char),
    Ctrl(char),
    Up,
    Down,
    Left,
    Right,
    Home,
    End,
    PageUp,
    PageDown,
    Backspace,
    Delete,
    Enter,
    Escape,
    Unknown,
}

pub struct Input;

impl Input {
    pub fn new() -> Self {
        Self
    }

    /// Read a single key from stdin
    pub fn read_key(&mut self) -> Option<Key> {
        let stdin = io::stdin();
        let mut handle = stdin.lock();
        let mut buf = [0u8; 1];

        match handle.read(&mut buf) {
            Ok(0) => None,
            Ok(_) => Some(self.parse_key(buf[0], &mut handle)),
            Err(_) => None,
        }
    }

    fn parse_key(&mut self, first_byte: u8, reader: &mut impl Read) -> Key {
        match first_byte {
            // Enter (Ctrl+M = 0x0D, Ctrl+J = 0x0A)
            0x0D | 0x0A => Key::Enter,
            // Ctrl keys (0x01-0x1A = Ctrl+A to Ctrl+Z, except Enter)
            0x01..=0x1A => {
                let c = (first_byte + b'a' - 1) as char;
                Key::Ctrl(c)
            }
            // Escape or escape sequence
            0x1B => self.parse_escape_sequence(reader),
            // Backspace
            0x7F => Key::Backspace,
            // Regular printable characters
            0x20..=0x7E => Key::Char(first_byte as char),
            // UTF-8 multi-byte characters
            0x80..=0xFF => self.parse_utf8(first_byte, reader),
            _ => Key::Unknown,
        }
    }

    fn parse_escape_sequence(&mut self, reader: &mut impl Read) -> Key {
        let mut buf = [0u8; 1];

        // Try to read next byte
        match reader.read(&mut buf) {
            Ok(0) => Key::Escape,
            Ok(_) => {
                if buf[0] == b'[' {
                    // CSI sequence
                    self.parse_csi_sequence(reader)
                } else if buf[0] == b'O' {
                    // SS3 sequence (some terminals use this for function keys)
                    self.parse_ss3_sequence(reader)
                } else {
                    Key::Escape
                }
            }
            Err(_) => Key::Escape,
        }
    }

    fn parse_csi_sequence(&mut self, reader: &mut impl Read) -> Key {
        let mut buf = [0u8; 1];
        let mut params = Vec::new();

        loop {
            match reader.read(&mut buf) {
                Ok(0) => return Key::Unknown,
                Ok(_) => {
                    let b = buf[0];
                    if b.is_ascii_digit() || b == b';' {
                        params.push(b);
                    } else {
                        // Final byte
                        return self.interpret_csi(b, &params);
                    }
                }
                Err(_) => return Key::Unknown,
            }
        }
    }

    fn interpret_csi(&self, final_byte: u8, params: &[u8]) -> Key {
        match final_byte {
            b'A' => Key::Up,
            b'B' => Key::Down,
            b'C' => Key::Right,
            b'D' => Key::Left,
            b'H' => Key::Home,
            b'F' => Key::End,
            b'~' => {
                // Extended keys with numeric parameters
                let param_str: String = params.iter().map(|&b| b as char).collect();
                match param_str.as_str() {
                    "1" | "7" => Key::Home,
                    "4" | "8" => Key::End,
                    "3" => Key::Delete,
                    "5" => Key::PageUp,
                    "6" => Key::PageDown,
                    _ => Key::Unknown,
                }
            }
            _ => Key::Unknown,
        }
    }

    fn parse_ss3_sequence(&mut self, reader: &mut impl Read) -> Key {
        let mut buf = [0u8; 1];
        match reader.read(&mut buf) {
            Ok(0) => Key::Unknown,
            Ok(_) => match buf[0] {
                b'A' => Key::Up,
                b'B' => Key::Down,
                b'C' => Key::Right,
                b'D' => Key::Left,
                b'H' => Key::Home,
                b'F' => Key::End,
                _ => Key::Unknown,
            },
            Err(_) => Key::Unknown,
        }
    }

    fn parse_utf8(&mut self, first_byte: u8, reader: &mut impl Read) -> Key {
        // Determine the number of bytes in this UTF-8 character
        let num_bytes = if first_byte & 0xE0 == 0xC0 {
            2
        } else if first_byte & 0xF0 == 0xE0 {
            3
        } else if first_byte & 0xF8 == 0xF0 {
            4
        } else {
            return Key::Unknown;
        };

        let mut bytes = vec![first_byte];
        for _ in 1..num_bytes {
            let mut buf = [0u8; 1];
            match reader.read(&mut buf) {
                Ok(1) => bytes.push(buf[0]),
                _ => return Key::Unknown,
            }
        }

        match String::from_utf8(bytes) {
            Ok(s) => {
                if let Some(c) = s.chars().next() {
                    Key::Char(c)
                } else {
                    Key::Unknown
                }
            }
            Err(_) => Key::Unknown,
        }
    }
}
