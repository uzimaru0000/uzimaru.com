import type { CSSProperties } from 'react';
import { parseAnsiStream, type AnsiAction } from './ansi-processor';

export interface Cell {
  char: string;
  style: CSSProperties;
  /** 全角文字の後半セル（レンダリングをスキップ） */
  skip?: boolean;
}

export interface Cursor {
  row: number;
  col: number;
}

function createEmptyCell(): Cell {
  return { char: '', style: {}, skip: false };
}

/**
 * 文字が全角かどうか判定
 */
function isFullWidth(char: string): boolean {
  if (!char) return false;
  const code = char.codePointAt(0);
  if (code === undefined) return false;

  // CJK文字、全角記号などの範囲
  return (
    (code >= 0x1100 && code <= 0x115F) ||  // Hangul Jamo
    (code >= 0x2E80 && code <= 0x9FFF) ||  // CJK
    (code >= 0xAC00 && code <= 0xD7A3) ||  // Hangul Syllables
    (code >= 0xF900 && code <= 0xFAFF) ||  // CJK Compatibility Ideographs
    (code >= 0xFE10 && code <= 0xFE1F) ||  // Vertical Forms
    (code >= 0xFE30 && code <= 0xFE6F) ||  // CJK Compatibility Forms
    (code >= 0xFF00 && code <= 0xFF60) ||  // Fullwidth Forms
    (code >= 0xFFE0 && code <= 0xFFE6) ||  // Fullwidth Forms
    (code >= 0x20000 && code <= 0x2FFFF)   // CJK Extension
  );
}

function createEmptyRow(cols: number): Cell[] {
  return Array.from({ length: cols }, () => createEmptyCell());
}

export interface CustomRender {
  row: number;
  payload: unknown;
}

export class ScreenBuffer {
  cells: Cell[][];
  rows: number;
  cols: number;
  cursor: Cursor;
  currentStyle: CSSProperties;
  customRenders: CustomRender[] = [];
  private scrollbackBuffer: Cell[][] = [];
  private maxScrollback = 1000;

  constructor(rows: number, cols: number) {
    this.rows = rows;
    this.cols = cols;
    this.cursor = { row: 0, col: 0 };
    this.currentStyle = {};
    this.cells = Array.from({ length: rows }, () => createEmptyRow(cols));
  }

  /**
   * 単一の文字をカーソル位置に書き込む
   */
  writeChar(char: string): void {
    const fullWidth = isFullWidth(char);

    // 全角文字で残り1セルしかない場合は改行
    if (fullWidth && this.cursor.col >= this.cols - 1) {
      this.newLine();
    } else if (this.cursor.col >= this.cols) {
      this.newLine();
    }

    this.cells[this.cursor.row][this.cursor.col] = {
      char,
      style: { ...this.currentStyle },
      skip: false,
    };
    this.cursor.col++;

    // 全角文字の場合、次のセルを skip マーク
    if (fullWidth && this.cursor.col < this.cols) {
      this.cells[this.cursor.row][this.cursor.col] = {
        char: '',
        style: {},
        skip: true,
      };
      this.cursor.col++;
    }
  }

  /**
   * 文字列を書き込む（ANSI シーケンス解釈付き）
   */
  write(text: string): void {
    const actions = parseAnsiStream(text);
    for (const action of actions) {
      this.processAction(action);
    }
  }

  /**
   * ANSI アクションを処理する
   */
  private processAction(action: AnsiAction): void {
    switch (action.type) {
      case 'text':
        for (const char of action.text) {
          this.writeChar(char);
        }
        break;

      case 'sgr':
        this.applySgr(action.codes);
        break;

      case 'cuu': // Cursor Up
        this.moveCursorRelative(-action.n, 0);
        break;

      case 'cud': // Cursor Down
        this.moveCursorRelative(action.n, 0);
        break;

      case 'cuf': // Cursor Forward
        this.moveCursorRelative(0, action.n);
        break;

      case 'cub': // Cursor Back
        this.moveCursorRelative(0, -action.n);
        break;

      case 'cup': // Cursor Position
        this.moveCursor(action.row, action.col);
        break;

      case 'ed': // Erase Display
        this.eraseDisplay(action.n);
        break;

      case 'el': // Erase Line
        this.eraseLine(action.n);
        break;

      case 'cr': // Carriage Return
        this.cursor.col = 0;
        break;

      case 'lf': // Line Feed
        this.newLine();
        break;

      case 'bs': // Backspace
        if (this.cursor.col > 0) {
          this.cursor.col--;
        }
        break;

      case 'custom':
        // カスタムレンダリングを保存（現在の行位置に紐付け）
        this.customRenders.push({
          row: this.cursor.row + this.scrollbackBuffer.length,
          payload: action.payload,
        });
        break;
    }
  }

  /**
   * SGR (Select Graphic Rendition) を適用
   */
  private applySgr(codes: number[]): void {
    for (let i = 0; i < codes.length; i++) {
      const code = codes[i];

      if (code === 0) {
        // Reset
        this.currentStyle = {};
      } else if (code === 1) {
        this.currentStyle.fontWeight = 'bold';
      } else if (code === 2) {
        this.currentStyle.opacity = 0.7;
      } else if (code === 3) {
        this.currentStyle.fontStyle = 'italic';
      } else if (code === 4) {
        this.currentStyle.textDecoration = 'underline';
      } else if (code >= 30 && code <= 37) {
        this.currentStyle.color = this.ansiColorToHex(code - 30);
      } else if (code >= 40 && code <= 47) {
        this.currentStyle.backgroundColor = this.ansiColorToHex(code - 40);
      } else if (code >= 90 && code <= 97) {
        this.currentStyle.color = this.ansiColorToHex(code - 90 + 8);
      } else if (code >= 100 && code <= 107) {
        this.currentStyle.backgroundColor = this.ansiColorToHex(code - 100 + 8);
      } else if (code === 38 && codes[i + 1] === 5) {
        // 256-color foreground
        this.currentStyle.color = this.ansi256ToHex(codes[i + 2]);
        i += 2;
      } else if (code === 48 && codes[i + 1] === 5) {
        // 256-color background
        this.currentStyle.backgroundColor = this.ansi256ToHex(codes[i + 2]);
        i += 2;
      }
    }
  }

  /**
   * 基本 ANSI カラー (0-15) を Hex に変換
   */
  private ansiColorToHex(n: number): string {
    // VSCode 風のカラーパレット
    const colors = [
      '#000000', '#f44747', '#6a9955', '#dcdcaa',
      '#569cd6', '#c586c0', '#4ec9b0', '#d4d4d4',
      '#808080', '#f44747', '#6a9955', '#dcdcaa',
      '#569cd6', '#c586c0', '#4ec9b0', '#ffffff',
    ];
    return colors[n] || '#ffffff';
  }

  /**
   * 256-color を Hex に変換
   */
  private ansi256ToHex(n: number): string {
    if (n < 16) {
      return this.ansiColorToHex(n);
    } else if (n < 232) {
      const i = n - 16;
      const r = Math.floor(i / 36);
      const g = Math.floor((i % 36) / 6);
      const b = i % 6;
      const toHex = (v: number) => (v === 0 ? 0 : 55 + v * 40).toString(16).padStart(2, '0');
      return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
    } else {
      const gray = 8 + (n - 232) * 10;
      const hex = gray.toString(16).padStart(2, '0');
      return `#${hex}${hex}${hex}`;
    }
  }

  /**
   * カーソルを絶対位置に移動
   */
  moveCursor(row: number, col: number): void {
    this.cursor.row = Math.max(0, Math.min(this.rows - 1, row));
    this.cursor.col = Math.max(0, Math.min(this.cols - 1, col));
  }

  /**
   * カーソルを相対位置に移動
   */
  moveCursorRelative(dRow: number, dCol: number): void {
    this.moveCursor(this.cursor.row + dRow, this.cursor.col + dCol);
  }

  /**
   * 画面クリア
   */
  eraseDisplay(mode: number): void {
    switch (mode) {
      case 0: // カーソルから末尾まで
        this.clearToEndOfLine();
        for (let r = this.cursor.row + 1; r < this.rows; r++) {
          this.cells[r] = createEmptyRow(this.cols);
        }
        break;
      case 1: // 先頭からカーソルまで
        for (let r = 0; r < this.cursor.row; r++) {
          this.cells[r] = createEmptyRow(this.cols);
        }
        for (let c = 0; c <= this.cursor.col; c++) {
          this.cells[this.cursor.row][c] = createEmptyCell();
        }
        break;
      case 2: // 画面全体
      case 3:
        this.clearScreen();
        break;
    }
  }

  /**
   * 行クリア
   */
  eraseLine(mode: number): void {
    switch (mode) {
      case 0: // カーソルから行末まで
        this.clearToEndOfLine();
        break;
      case 1: // 行頭からカーソルまで
        for (let c = 0; c <= this.cursor.col; c++) {
          this.cells[this.cursor.row][c] = createEmptyCell();
        }
        break;
      case 2: // 行全体
        this.cells[this.cursor.row] = createEmptyRow(this.cols);
        break;
    }
  }

  /**
   * 画面全体をクリア
   */
  clearScreen(): void {
    this.cells = Array.from({ length: this.rows }, () => createEmptyRow(this.cols));
    this.cursor = { row: 0, col: 0 };
    this.customRenders = [];
    this.scrollbackBuffer = [];
  }

  /**
   * カーソル位置から行末までクリア
   */
  clearToEndOfLine(): void {
    for (let c = this.cursor.col; c < this.cols; c++) {
      this.cells[this.cursor.row][c] = createEmptyCell();
    }
  }

  /**
   * 改行（必要ならスクロール）
   */
  newLine(): void {
    this.cursor.col = 0;
    this.cursor.row++;

    if (this.cursor.row >= this.rows) {
      this.scroll();
      this.cursor.row = this.rows - 1;
    }
  }

  /**
   * 1行スクロール
   */
  private scroll(): void {
    // 最上行をスクロールバックバッファに保存
    const topRow = this.cells.shift();
    if (topRow) {
      this.scrollbackBuffer.push(topRow);
      if (this.scrollbackBuffer.length > this.maxScrollback) {
        this.scrollbackBuffer.shift();
      }
    }
    // 新しい空行を追加
    this.cells.push(createEmptyRow(this.cols));
  }

  /**
   * サイズ変更
   */
  resize(rows: number, cols: number): void {
    const newCells: Cell[][] = Array.from({ length: rows }, (_, r) => {
      if (r < this.rows && this.cells[r]) {
        // 既存の行を拡張または縮小
        const row = this.cells[r];
        if (cols > this.cols) {
          return [...row, ...Array.from({ length: cols - this.cols }, () => createEmptyCell())];
        } else {
          return row.slice(0, cols);
        }
      } else {
        return createEmptyRow(cols);
      }
    });

    this.cells = newCells;
    this.rows = rows;
    this.cols = cols;

    // カーソルが範囲外にならないように調整
    this.cursor.row = Math.min(this.cursor.row, rows - 1);
    this.cursor.col = Math.min(this.cursor.col, cols - 1);
  }

  /**
   * スクロールバックバッファを含む全セルを取得
   */
  getAllCells(): Cell[][] {
    return [...this.scrollbackBuffer, ...this.cells];
  }

  /**
   * スクロールバックの行数を取得
   */
  getScrollbackLength(): number {
    return this.scrollbackBuffer.length;
  }

  /**
   * バックスペース処理
   */
  backspace(): void {
    if (this.cursor.col > 0) {
      this.cursor.col--;
      this.cells[this.cursor.row][this.cursor.col] = createEmptyCell();
    }
  }

  /**
   * デバッグ用：現在の状態を文字列で取得
   */
  toString(): string {
    return this.cells
      .map(row => row.map(cell => cell.char || ' ').join(''))
      .join('\n');
  }
}
