import {
  forwardRef,
  useImperativeHandle,
  useRef,
  useEffect,
  useState,
  useCallback,
  useLayoutEffect,
  type KeyboardEvent,
  type CompositionEvent,
} from 'react';
import { ScreenBuffer, type Cell, type CustomRender } from './ScreenBuffer';
import { rendererRegistry, type ParsedCustomPayload } from '../renderers';

export interface TtyHandle {
  write: (text: string) => void;
  clear: () => void;
  getSize: () => { rows: number; cols: number };
}

interface TtyProps {
  onInput: (data: string) => void;
  onResize?: (rows: number, cols: number) => void;
}

// 文字サイズの定数（モノスペースフォント）
const CHAR_WIDTH = 9.6;  // px
const CHAR_HEIGHT = 20;  // px (line-height 込み)

export const Tty = forwardRef<TtyHandle, TtyProps>(function Tty({ onInput, onResize }, ref) {
  const containerRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const bufferRef = useRef<ScreenBuffer | null>(null);
  const [, forceUpdate] = useState({});
  const isComposingRef = useRef(false);

  // 画面バッファの初期化
  useEffect(() => {
    if (!containerRef.current) return;

    const { width, height } = containerRef.current.getBoundingClientRect();
    const cols = Math.max(1, Math.floor(width / CHAR_WIDTH));
    const rows = Math.max(1, Math.floor(height / CHAR_HEIGHT));

    bufferRef.current = new ScreenBuffer(rows, cols);
    onResize?.(rows, cols);
    forceUpdate({});
  }, []);

  // ResizeObserver でサイズ変更を監視
  useEffect(() => {
    if (!containerRef.current) return;

    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const { width, height } = entry.contentRect;
        const cols = Math.max(1, Math.floor(width / CHAR_WIDTH));
        const rows = Math.max(1, Math.floor(height / CHAR_HEIGHT));

        if (bufferRef.current) {
          bufferRef.current.resize(rows, cols);
          onResize?.(rows, cols);
          forceUpdate({});
        }
      }
    });

    observer.observe(containerRef.current);
    return () => observer.disconnect();
  }, [onResize]);

  // カーソル要素を追尾して hidden input の位置を更新
  useLayoutEffect(() => {
    if (!containerRef.current || !inputRef.current) return;

    const cursorEl = containerRef.current.querySelector('[data-cursor="true"]');
    if (cursorEl) {
      const containerRect = containerRef.current.getBoundingClientRect();
      const cursorRect = cursorEl.getBoundingClientRect();
      const top = cursorRect.top - containerRect.top + containerRef.current.scrollTop;
      const left = cursorRect.left - containerRect.left + containerRef.current.scrollLeft;
      inputRef.current.style.top = `${top}px`;
      inputRef.current.style.left = `${left}px`;
    }
  });

  // カーソル位置が見えるようにスクロール
  const scrollToCursor = useCallback(() => {
    if (containerRef.current && bufferRef.current) {
      const cursorRow = bufferRef.current.cursor.row;
      const rowElement = containerRef.current.querySelector(`[data-row="${cursorRow}"]`);
      if (rowElement) {
        rowElement.scrollIntoView({ block: 'nearest', behavior: 'auto' });
      }
    }
  }, []);

  // ref で write/clear を公開
  useImperativeHandle(ref, () => ({
    write: (text: string) => {
      if (bufferRef.current) {
        bufferRef.current.write(text);
        forceUpdate({});
        // 改行やカスタムレンダラーを含む場合のみスクロール
        if (text.includes('\n') || text.includes('\x1b]custom;')) {
          requestAnimationFrame(scrollToCursor);
        }
      }
    },
    clear: () => {
      if (bufferRef.current) {
        bufferRef.current.clearScreen();
        forceUpdate({});
      }
    },
    getSize: () => {
      if (bufferRef.current) {
        return { rows: bufferRef.current.rows, cols: bufferRef.current.cols };
      }
      return { rows: 24, cols: 80 };
    },
  }));

  // IME composition イベント
  const handleCompositionStart = useCallback(() => {
    isComposingRef.current = true;
  }, []);

  const handleCompositionEnd = useCallback((e: CompositionEvent<HTMLInputElement>) => {
    isComposingRef.current = false;
    // 確定した文字列を一度に送信
    if (e.data) {
      onInput(e.data);
    }
    // input をクリア
    if (inputRef.current) {
      inputRef.current.value = '';
    }
  }, [onInput]);

  // キー入力（隠し input 用）
  const handleKeyDown = useCallback((e: KeyboardEvent<HTMLInputElement>) => {
    // IME 入力中は無視
    if (isComposingRef.current) {
      return;
    }

    // 特殊キーの処理
    if (e.key === 'Enter') {
      e.preventDefault();
      onInput('\n');
    } else if (e.key === 'Backspace') {
      e.preventDefault();
      onInput('\x7f');  // DEL
    } else if (e.key === 'Tab') {
      e.preventDefault();
      onInput('\t');
    } else if (e.key === 'Escape') {
      e.preventDefault();
      onInput('\x1b');
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      onInput('\x1b[A');
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      onInput('\x1b[B');
    } else if (e.key === 'ArrowRight') {
      e.preventDefault();
      onInput('\x1b[C');
    } else if (e.key === 'ArrowLeft') {
      e.preventDefault();
      onInput('\x1b[D');
    } else if (e.ctrlKey) {
      // Ctrl キーの組み合わせ
      e.preventDefault();
      if (e.key === 'c') {
        onInput('\x03');  // ETX (Ctrl+C)
      } else if (e.key === 'd') {
        onInput('\x04');  // EOT (Ctrl+D)
      } else if (e.key === 'l') {
        onInput('\x0c');  // FF (Ctrl+L)
      } else if (e.key === 'u') {
        onInput('\x15');  // NAK (Ctrl+U)
      }
    }
    // 通常の文字は handleInput で処理するため、ここでは処理しない
  }, [onInput]);

  // コンテナクリックで隠し input にフォーカス
  const handleClick = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  // input の入力処理
  const handleInputChange = useCallback((e: React.FormEvent<HTMLInputElement>) => {
    if (isComposingRef.current) return;

    const target = e.target as HTMLInputElement;
    const value = target.value;
    if (value) {
      for (const char of value) {
        onInput(char);
      }
      target.value = '';
    }
  }, [onInput]);

  const buffer = bufferRef.current;
  if (!buffer) {
    return (
      <div
        ref={containerRef}
        className="h-full w-full bg-term-bg font-mono text-term-fg p-2 overflow-hidden"
        tabIndex={0}
      />
    );
  }

  // 行に関連するカスタムレンダリングを取得
  const getCustomRendersForRow = (rowIndex: number): CustomRender[] => {
    const scrollbackLength = buffer.getScrollbackLength();
    const absoluteRow = scrollbackLength + rowIndex;
    return buffer.customRenders.filter(cr => cr.row === absoluteRow);
  };

  return (
    <div
      ref={containerRef}
      className="h-full w-full bg-term-bg font-mono text-term-fg p-2 overflow-auto outline-none cursor-text relative"
      onClick={handleClick}
    >
      {/* 隠し input（IME 入力用） - カーソル位置に配置 */}
      <input
        ref={inputRef}
        type="text"
        className="absolute w-px h-5 opacity-0 outline-none border-none bg-transparent"
        style={{ caretColor: 'transparent', top: 0, left: 0 }}
        onKeyDown={handleKeyDown}
        onInput={handleInputChange}
        onCompositionStart={handleCompositionStart}
        onCompositionEnd={handleCompositionEnd}
        autoFocus
      />
      {buffer.cells.map((row, rowIndex) => {
        const customRenders = getCustomRendersForRow(rowIndex);

        // カスタムレンダラーがある行はセルを描画しない
        if (customRenders.length > 0) {
          return (
            <div key={rowIndex}>
              {customRenders.map((cr, idx) => {
                const payload = cr.payload as ParsedCustomPayload;
                return (
                  <div key={`custom-${rowIndex}-${idx}`} className="my-2">
                    {rendererRegistry.render(payload, `custom-${rowIndex}-${idx}`)}
                  </div>
                );
              })}
            </div>
          );
        }

        return (
          <div key={rowIndex} data-row={rowIndex} className="whitespace-pre" style={{ height: CHAR_HEIGHT }}>
            {row.map((cell, colIndex) => {
              // skip フラグがあるセルはレンダリングしない
              if (cell.skip) {
                return null;
              }
              const isCursor = rowIndex === buffer.cursor.row && colIndex === buffer.cursor.col;
              return (
                <CellSpan
                  key={colIndex}
                  cell={cell}
                  isCursor={isCursor}
                />
              );
            })}
          </div>
        );
      })}
    </div>
  );
});

/**
 * セル表示コンポーネント
 */
interface CellSpanProps {
  cell: Cell;
  isCursor: boolean;
}

// デフォルトの色
const DEFAULT_FG = '#d4d4d4';
const DEFAULT_BG = '#1e1e1e';

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

function CellSpan({ cell, isCursor }: CellSpanProps) {
  const char = cell.char || ' ';
  const style: React.CSSProperties = { ...cell.style };
  const fullWidth = isFullWidth(char);

  // すべてのセルを inline-block にして幅を固定
  style.display = 'inline-block';
  style.width = fullWidth ? CHAR_WIDTH * 2 : CHAR_WIDTH;

  // デフォルト色を設定
  if (!style.color) {
    style.color = DEFAULT_FG;
  }

  if (isCursor) {
    // カーソル表示：背景と前景を反転
    const bg = style.backgroundColor || DEFAULT_BG;
    const fg = style.color;
    style.backgroundColor = fg;
    style.color = bg;
  }

  return (
    <span style={style} data-cursor={isCursor || undefined}>
      {char}
    </span>
  );
}
