# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is uzimaru0000's personal portfolio website built as a **terminal emulator** in the browser. Users interact with the site by typing shell-like commands (help, ls, cd, cat, echo, etc.).

## Development Commands

```bash
npm run dev          # Start Vite dev server (with hot reload)
npm run build        # Production build (tsc + vite build, output to dist/)
npm run build:wasm   # Build Rust WASM commands (cargo component build --release)
npm run copy:wasm    # Copy built WASM to src/content/bin/
npm run test         # Run Vitest in watch mode
npm run test:run     # Run Vitest once
```

## Architecture

### Tech Stack
- **React** + **TypeScript** - UI and application logic
- **Rust** + **WASM** - Shell parser and external commands
- **Vite** - Bundling and dev server
- **Vitest** - Unit testing framework
- **Tailwind CSS** - Styling
- **@bytecodealliance/jco** - WASM component transpilation
- **Prism.js** - Syntax highlighting for code blocks

### Directory Structure
```
src/
├── App.tsx                 # Root React component
├── main.tsx                # Entry point
├── vite-env.d.ts           # Vite type definitions
├── components/
│   ├── Terminal.tsx        # Terminal controller (shell integration, input handling)
│   ├── tty/                # TTY emulation system
│   │   ├── index.ts        # Exports
│   │   ├── Tty.tsx         # TTY display component (screen buffer rendering, IME support)
│   │   ├── ScreenBuffer.ts # Screen buffer (2D cell array, cursor, ANSI processing)
│   │   └── ansi-processor.ts # ANSI escape sequence parser
│   └── renderers/          # Custom rendering system
│       ├── index.ts        # Exports and built-in renderer registration
│       ├── registry.tsx    # Renderer registry (singleton)
│       ├── types.ts        # Type definitions (including MarkdownEvent types)
│       ├── ImageRenderer.tsx     # Image renderer
│       ├── MarkdownRenderer.tsx  # Markdown renderer with syntax highlighting
│       └── MarkdownRenderer.test.tsx  # Tests for Markdown renderer
├── test/
│   └── setup.ts            # Vitest setup (jest-dom)
├── shell/
│   ├── dispatcher.ts       # Command dispatcher (builtin commands, PATH lookup, execution)
│   ├── shell-parser.ts     # WASM shell parser loader
│   ├── shell-types.ts      # Shell parser type definitions
│   ├── wasm-executor.ts    # WASM command executor
│   └── types.ts            # Shell state types (ShellState, ExecResult)
├── filesystem/
│   ├── index.ts            # Virtual filesystem implementation
│   ├── types.ts            # Filesystem type definitions
│   ├── wasi-adapter.ts     # WASI preview2 adapter
│   ├── init.ts             # WASM binary initialization
│   └── content-loader.ts   # Loads initial FS content from src/content/ via import.meta.glob
├── content/                # Initial filesystem content (loaded at build time)
│   ├── bin/                # WASM commands (*.wasm files, git-ignored)
│   │   ├── echo.wasm
│   │   ├── ls.wasm
│   │   ├── cat.wasm
│   │   ├── markdown.wasm
│   │   └── shell.wasm
│   └── home/
│       └── uzimaru0000/
│           ├── profile
│           ├── README.md
│           ├── whoami.md
│           ├── work.md
│           ├── link.md
│           └── .shellrc
crates/
├── shell/                  # Rust shell parser (WASM component)
└── commands/               # Rust external commands
    ├── echo/
    ├── ls/
    ├── cat/
    └── markdown/
wit/
├── command.wit             # Command interface definition
└── filesystem.wit          # Filesystem interface definition
```

### Key Concepts

**Shell State** (`src/shell/types.ts`):
```typescript
interface ShellState {
  cwd: string;                      // Current working directory
  env: Map<string, string>;         // Environment variables
  aliases: Map<string, string>;     // Command aliases
}
```

**Command Types**:
- **Builtin commands**: Implemented in `dispatcher.ts` (cd, pwd, export, alias, unalias, source, mkdir, touch, rm, mv, clear, sh)
- **External commands**: WASM binaries or shell scripts found via PATH environment variable (echo, ls, cat, markdown)

**Command Lookup**:
- External commands are searched via PATH environment variable (default: `/bin`)
- PATH can contain multiple directories separated by `:` (e.g., `/bin:/usr/bin`)
- Search order: `.wasm` files first, then `.sh` files (e.g., `/bin/echo.wasm`, `/bin/hello.sh`)

**Virtual FileSystem** (`src/filesystem/index.ts`):
- Tree structure with in-memory storage
- Initial content loaded from `src/content/` at build time via Vite's `import.meta.glob`
- No localStorage persistence - content resets on page reload

**Initial Content** (`src/content/`):
- Directory structure mirrors the virtual filesystem
- Text files are bundled at build time using `import.meta.glob` with `?raw` query
- WASM files (in `bin/`) are loaded via `?url` query and fetched at runtime
- WASM files are git-ignored and generated by `npm run build:wasm && npm run copy:wasm`
- To update initial content, edit files in `src/content/` and rebuild

**Shell Configuration** (`~/.shellrc`):
- Loaded automatically on shell startup
- Supports any shell commands (executed line by line)
- Reload with `source ~/.shellrc` or `. ~/.shellrc`
- Default aliases: `help`, `whoami`, `work`, `link` (display markdown files)

### Adding a New Builtin Command

Add command function to `builtinCommands` object in `src/shell/dispatcher.ts`:
```typescript
mycommand: (state, args) => {
  // Implementation
  return { stdout: 'output', stderr: '', exitCode: 0 };
},
```

### Adding a New WASM Command

1. Create new crate in `crates/commands/mycommand/`
2. Implement `Guest` trait with `run(input: CommandInput) -> i32`
3. Add to workspace in `Cargo.toml`
4. Add command name to `copy:wasm` script in `package.json`
5. Build with `npm run build:wasm && npm run copy:wasm`
6. WASM files in `src/content/bin/` are automatically loaded via `content-loader.ts`

### WASI Shim

The `src/shell/wasm-executor.ts` uses `@bytecodealliance/preview2-shim` to provide WASI support in the browser:
- **stdout/stderr capture**: Custom handlers to capture command output
- **stdin**: Supports piped input from previous commands
- **Filesystem**: Virtual filesystem is synced to WASI via `wasi-adapter.ts`

### Adding Initial Filesystem Content

1. Create files in `src/content/` directory
2. Directory structure maps to virtual filesystem paths:
   - `src/content/home/uzimaru0000/file.txt` → `/home/uzimaru0000/file.txt`
3. Dotfiles are supported (e.g., `.shellrc`)
4. Rebuild to include new content

### Shell Features

- **Pipelines**: `ls | cat`
- **Redirections**: `echo hello > file.txt`, `cat < input.txt`
- **Environment variables**: `$HOME`, `${USER}`, `$PATH`
- **Tilde expansion**: `~` expands to `$HOME`, `~/path` expands to `$HOME/path`
- **Command substitution**: `echo $(pwd)`
- **Logical operators**: `cmd1 && cmd2`, `cmd1 || cmd2`
- **Aliases**: Defined in `.shellrc` or via `alias` command
- **Shell scripts**: Execute with `sh script.sh`, `./script.sh`, or place in PATH as `.sh` file
- **Multiline scripts**: Scripts with multiple lines, empty lines, and comments are fully supported

### TTY Emulation System

The terminal uses a custom TTY emulation layer (`src/components/tty/`) that provides:

**ScreenBuffer** (`ScreenBuffer.ts`):
- 2D cell array representing the terminal screen
- Each cell contains: `{ char: string, style: CSSProperties, skip?: boolean }`
- Cursor position tracking
- ANSI escape sequence processing (colors, cursor movement, erase)
- Scrollback buffer support
- Full-width character support (CJK characters occupy 2 cells)

**ANSI Processor** (`ansi-processor.ts`):
- Parses ANSI escape sequences into typed actions
- Supports: SGR (colors/styles), cursor movement (CUU/CUD/CUF/CUB/CUP), erase (ED/EL)
- Custom OSC sequences for rich rendering (`\x1b]custom;{json}\x07`)

**Tty Component** (`Tty.tsx`):
- Renders ScreenBuffer as React components
- Hidden input for IME (Japanese/Chinese input) support
- Cursor position tracking via `data-cursor` attribute
- ResizeObserver for dynamic terminal sizing
- Exposes `TtyHandle` interface: `write(text)`, `clear()`, `getSize()`

**Terminal Controller** (`Terminal.tsx`):
- Integrates Tty with shell execution
- Manages input buffer and cursor position
- Handles command history (up/down arrows)
- PS1 prompt expansion and display

### Terminal Customization

**PS1 Prompt** (`Terminal.tsx`):
The terminal supports customizable prompts via the `PS1` environment variable. The prompt is expanded using bash-like escape sequences.

Supported escape sequences:
| Escape | Description |
|--------|-------------|
| `\w` | Current working directory (with `~` for home) |
| `\W` | Basename of current directory |
| `\u` | Username from `$USER` |
| `\h` | Hostname |
| `\$` | `$` for normal user, `#` for root |
| `\e` | ESC character (for ANSI colors) |
| `\n` | Newline |
| `\\` | Literal backslash |

**Example PS1**:
```bash
# Simple prompt with cyan directory
export PS1='\e[36m\w\e[0m ❯ '

# Powerline style with Nerd Font
export PS1='\e[38;5;235;48;5;35m \w \e[0;38;5;35m\e[0m '
```

**Note**: Unlike bash, `\[` and `\]` (readline markers) are not needed and will be ignored.

**ANSI Color Support**:
The terminal supports full ANSI color escape sequences including 256-color mode.

| Format | Description | Example |
|--------|-------------|---------|
| `\e[30-37m` | Standard foreground (8 colors) | `\e[36m` = cyan |
| `\e[40-47m` | Standard background (8 colors) | `\e[44m` = blue bg |
| `\e[90-97m` | Bright foreground (8 colors) | `\e[96m` = bright cyan |
| `\e[38;5;Nm` | 256-color foreground | `\e[38;5;35m` = green |
| `\e[48;5;Nm` | 256-color background | `\e[48;5;235m` = dark gray |
| `\e[0m` | Reset all styles | |
| `\e[1m` | Bold | |
| `\e[3m` | Italic | |
| `\e[4m` | Underline | |

256-color palette:
- 0-15: Standard + bright colors
- 16-231: 6×6×6 color cube (RGB)
- 232-255: Grayscale (24 shades)

**Powerline / Nerd Font Support**:
The terminal renders Powerline symbols correctly when using Nerd Font. Common symbols:
- `` (U+E0B0) - Right-pointing triangle
- `` (U+E0B2) - Left-pointing triangle
- `` (U+E0B1) - Right-pointing thin triangle
- `` (U+E0B3) - Left-pointing thin triangle

To use Powerline symbols in `.shellrc`, ensure the file is saved with UTF-8 encoding containing the actual Unicode characters.

### Custom Rendering System

The terminal supports custom rendering via OSC (Operating System Command) escape sequences. This allows commands to output rich content like images instead of plain text.

**Protocol Format**:
```
\x1b]custom;<JSON_PAYLOAD>\x07
```
- `\x1b]` - OSC start
- `custom;` - Custom protocol identifier
- `<JSON_PAYLOAD>` - JSON object with `type` and `props`
- `\x07` - OSC end (BEL)

**JSON Payload Schema**:
```typescript
interface CustomRenderPayload {
  type: string;                    // Renderer type (e.g., "image")
  id?: string;                     // Optional unique identifier
  props: Record<string, unknown>;  // Renderer-specific properties
}
```

**Built-in Renderers**:

| Type | Props | Description |
|------|-------|-------------|
| `image` | `src` (required), `alt`, `width`, `height` | Display an image |
| `markdown` | `events` (required) | Render Markdown AST with syntax highlighting |

**Example Usage**:
```
\x1b]custom;{"type":"image","props":{"src":"https://example.com/photo.png","alt":"Photo"}}\x07
```

### Adding a Custom Renderer

1. Create a new renderer component in `src/components/renderers/`:
```typescript
// src/components/renderers/MyRenderer.tsx
import type { RendererProps } from './types';

interface MyProps {
  message: string;
}

export function MyRenderer({ props }: RendererProps<MyProps>) {
  return <div>{props.message}</div>;
}
```

2. Register the renderer in `src/components/renderers/index.ts`:
```typescript
import { MyRenderer } from './MyRenderer';
import { registerRenderer } from './registry';

registerRenderer('my-type', MyRenderer);
```

3. Output from commands:
```typescript
// In a builtin command or WASM command
const payload = { type: 'my-type', props: { message: 'Hello' } };
const output = `\x1b]custom;${JSON.stringify(payload)}\x07`;
```

### Adding a Shell Script Command

1. Create a `.sh` file in `src/content/bin/` (e.g., `hello.sh`)
2. Add shebang `#!/bin/sh` at the first line (optional)
3. Script will be available as command via PATH (e.g., `hello`)

Example:
```bash
#!/bin/sh
echo "Hello from shell script!"
```

### Markdown Renderer

The `markdown` command renders Markdown files with rich formatting and syntax highlighting.

**How it works**:
1. Rust WASM command (`crates/commands/markdown/`) parses Markdown using `pulldown-cmark`
2. AST events are serialized to JSON and output via OSC sequence
3. React `MarkdownRenderer` component renders the AST with Prism.js syntax highlighting

**Supported Markdown features**:
- Headings (H1-H6)
- Bold, italic, strikethrough
- Inline code and fenced code blocks (with syntax highlighting)
- Ordered and unordered lists
- Task lists (checkboxes)
- Links and images
- Blockquotes
- Tables
- Horizontal rules

**Important**: When outputting OSC sequences from Rust WASM, always flush stdout:
```rust
use std::io::Write;

print!("\x1b]custom;{}\x1b\\", json_payload);
let _ = std::io::stdout().flush();  // Required!
```

### Testing

The project uses **Vitest** with **@testing-library/react** for testing.

**Test files**:
- `src/components/renderers/MarkdownRenderer.test.tsx` - Tests for Markdown rendering

**Running tests**:
```bash
npm run test      # Watch mode
npm run test:run  # Run once
```

**Writing tests**:
```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';

describe('MyComponent', () => {
  it('renders correctly', () => {
    render(<MyComponent />);
    expect(screen.getByText('Hello')).toBeInTheDocument();
  });
});
```
