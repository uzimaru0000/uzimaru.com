import { useState, useRef, useEffect, useCallback } from 'react';
import { createShell } from '../shell/dispatcher';
import type { ShellState } from '../shell/types';
import { Tty, type TtyHandle } from './tty';
import { writeStdin, sendStdinEOF, isInteractiveMode } from '../shell/wasm-executor';

/**
 * 文字が全角かどうか判定
 */
function isFullWidth(char: string): boolean {
  if (!char) return false;
  const code = char.codePointAt(0);
  if (code === undefined) return false;

  return (
    (code >= 0x1100 && code <= 0x115F) ||
    (code >= 0x2E80 && code <= 0x9FFF) ||
    (code >= 0xAC00 && code <= 0xD7A3) ||
    (code >= 0xF900 && code <= 0xFAFF) ||
    (code >= 0xFE10 && code <= 0xFE1F) ||
    (code >= 0xFE30 && code <= 0xFE6F) ||
    (code >= 0xFF00 && code <= 0xFF60) ||
    (code >= 0xFFE0 && code <= 0xFFE6) ||
    (code >= 0x20000 && code <= 0x2FFFF)
  );
}

/**
 * 文字列の表示幅を計算（全角=2, 半角=1）
 */
function getDisplayWidth(str: string): number {
  let width = 0;
  for (const char of str) {
    width += isFullWidth(char) ? 2 : 1;
  }
  return width;
}

/**
 * PS1をパースしてプロンプト文字列を生成
 */
function expandPS1(ps1: string, state: ShellState): string {
  let result = '';
  let i = 0;
  while (i < ps1.length) {
    if (ps1[i] === '\\' && i + 1 < ps1.length) {
      const next = ps1[i + 1];
      switch (next) {
        case 'w': {
          const home = state.env.get('HOME') || '/home/uzimaru0000';
          result += state.cwd.startsWith(home)
            ? '~' + state.cwd.slice(home.length)
            : state.cwd;
          break;
        }
        case 'W':
          result += state.cwd.split('/').pop() || '/';
          break;
        case 'u':
          result += state.env.get('USER') || 'user';
          break;
        case 'h':
          result += state.env.get('HOSTNAME') || window.location.host;
          break;
        case '$':
          result += state.env.get('USER') === 'root' ? '#' : '$';
          break;
        case '\\':
          result += '\\';
          break;
        case 'n':
          result += '\n';
          break;
        case 'e':
          result += '\x1b';
          break;
        case '[':
        case ']':
          break;
        default:
          result += '\\' + next;
      }
      i += 2;
    } else {
      result += ps1[i];
      i++;
    }
  }
  return result;
}

function getPrompt(shell: ReturnType<typeof createShell>): string {
  const state = shell.getState();
  const ps1 = state.env.get('PS1') || '\\w \\$ ';
  return expandPS1(ps1, state);
}

type Props = {
  onClose: () => void;
}

export function Terminal({ onClose }: Props) {
  const ttyRef = useRef<TtyHandle>(null);
  const shell = useRef(createShell());
  const [isExecuting, setIsExecuting] = useState(false);
  const [inputBuffer, setInputBuffer] = useState('');
  const [cursorPos, setCursorPos] = useState(0);  // 入力バッファ内のカーソル位置
  const [commandHistory, setCommandHistory] = useState<string[]>([]);
  const [historyIndex, setHistoryIndex] = useState(-1);
  const inputBufferRef = useRef('');
  const cursorPosRef = useRef(0);

  // inputBuffer と cursorPos を ref で追跡
  useEffect(() => {
    inputBufferRef.current = inputBuffer;
  }, [inputBuffer]);

  useEffect(() => {
    cursorPosRef.current = cursorPos;
  }, [cursorPos]);

  // プロンプトを表示
  const showPrompt = useCallback(() => {
    const prompt = getPrompt(shell.current);
    ttyRef.current?.write(prompt);
  }, []);

  // コマンド実行
  const executeCommand = useCallback(async (cmd: string) => {
    if (!cmd.trim()) {
      ttyRef.current?.write('\n');
      showPrompt();
      return;
    }

    setIsExecuting(true);
    setCommandHistory(prev => [...prev, cmd]);
    setHistoryIndex(-1);

    try {
      const result = await shell.current.execute(cmd);

      // clear コマンドの処理
      if (result.stdout === '\x1b[clear]') {
        ttyRef.current?.clear();
        setIsExecuting(false);
        showPrompt();
        return;
      }

      // exit コマンドの処理
      if (result.stdout === '\x1b[exit]') {
        onClose();
        return;
      }

      // stdout を表示
      if (result.stdout) {
        ttyRef.current?.write(result.stdout);
        // 最後が改行でなければ追加
        if (!result.stdout.endsWith('\n')) {
          ttyRef.current?.write('\n');
        }
      }

      // stderr を赤色で表示
      if (result.stderr) {
        ttyRef.current?.write('\x1b[31m' + result.stderr + '\x1b[0m');
        if (!result.stderr.endsWith('\n')) {
          ttyRef.current?.write('\n');
        }
      }
    } catch (error) {
      ttyRef.current?.write(
        '\x1b[31mError: ' +
        (error instanceof Error ? error.message : String(error)) +
        '\x1b[0m\n'
      );
    } finally {
      setIsExecuting(false);
      showPrompt();
    }
  }, [onClose, showPrompt]);

  // 入力ハンドラ
  const handleInput = useCallback((data: string) => {
    // コマンド実行中（インタラクティブモード）
    if (isExecuting && isInteractiveMode()) {
      if (data === '\x04') {
        // Ctrl+D: EOF
        sendStdinEOF();
      } else if (data === '\x03') {
        // Ctrl+C: 中断（現状は EOF と同じ）
        sendStdinEOF();
      } else {
        // stdin にデータを送信
        writeStdin(data);
        // エコー（改行のみ表示）
        if (data === '\n') {
          ttyRef.current?.write('\n');
        }
      }
      return;
    }

    // コマンド実行中（非インタラクティブ）は入力を無視
    if (isExecuting) {
      return;
    }

    // 通常モード：コマンド入力
    if (data === '\n') {
      // Enter: コマンド実行
      ttyRef.current?.write('\n');
      const cmd = inputBufferRef.current;
      setInputBuffer('');
      setCursorPos(0);
      executeCommand(cmd);
    } else if (data === '\x7f') {
      // Backspace
      const pos = cursorPosRef.current;
      if (pos > 0) {
        const buf = inputBufferRef.current;
        const chars = [...buf];
        const deletedChar = chars[pos - 1];
        const deletedWidth = isFullWidth(deletedChar) ? 2 : 1;
        const newBuf = buf.slice(0, pos - 1) + buf.slice(pos);
        setInputBuffer(newBuf);
        setCursorPos(pos - 1);
        // カーソルを戻して、残りの文字を再描画
        const remaining = buf.slice(pos);
        const remainingWidth = getDisplayWidth(remaining);
        ttyRef.current?.write('\b'.repeat(deletedWidth) + remaining + ' '.repeat(deletedWidth) + '\b'.repeat(remainingWidth + deletedWidth));
      }
    } else if (data === '\x1b[A') {
      // 上矢印: 履歴を遡る
      if (commandHistory.length > 0) {
        const newIndex = historyIndex === -1
          ? commandHistory.length - 1
          : Math.max(0, historyIndex - 1);
        setHistoryIndex(newIndex);
        // 現在の入力をクリアして履歴を表示
        const buf = inputBufferRef.current;
        const pos = cursorPosRef.current;
        const bufWidth = getDisplayWidth(buf);
        const afterCursorWidth = getDisplayWidth(buf.slice(pos));
        // カーソルを末尾に移動してからクリア
        ttyRef.current?.write('\x1b[C'.repeat(afterCursorWidth));
        ttyRef.current?.write('\b \b'.repeat(bufWidth));
        const historyCmd = commandHistory[newIndex];
        setInputBuffer(historyCmd);
        setCursorPos(historyCmd.length);
        ttyRef.current?.write(historyCmd);
      }
    } else if (data === '\x1b[B') {
      // 下矢印: 履歴を進める
      if (historyIndex !== -1) {
        const buf = inputBufferRef.current;
        const pos = cursorPosRef.current;
        const bufWidth = getDisplayWidth(buf);
        const afterCursorWidth = getDisplayWidth(buf.slice(pos));
        // カーソルを末尾に移動してからクリア
        ttyRef.current?.write('\x1b[C'.repeat(afterCursorWidth));
        ttyRef.current?.write('\b \b'.repeat(bufWidth));

        const newIndex = historyIndex + 1;
        if (newIndex >= commandHistory.length) {
          setHistoryIndex(-1);
          setInputBuffer('');
          setCursorPos(0);
        } else {
          setHistoryIndex(newIndex);
          const historyCmd = commandHistory[newIndex];
          setInputBuffer(historyCmd);
          setCursorPos(historyCmd.length);
          ttyRef.current?.write(historyCmd);
        }
      }
    } else if (data === '\x1b[C') {
      // 右矢印: カーソルを右に移動
      const pos = cursorPosRef.current;
      const buf = inputBufferRef.current;
      if (pos < buf.length) {
        const charAtPos = [...buf][pos];
        const width = isFullWidth(charAtPos) ? 2 : 1;
        setCursorPos(pos + 1);
        ttyRef.current?.write('\x1b[C'.repeat(width));
      }
    } else if (data === '\x1b[D') {
      // 左矢印: カーソルを左に移動
      const pos = cursorPosRef.current;
      const buf = inputBufferRef.current;
      if (pos > 0) {
        const charBeforePos = [...buf][pos - 1];
        const width = isFullWidth(charBeforePos) ? 2 : 1;
        setCursorPos(pos - 1);
        ttyRef.current?.write('\x1b[D'.repeat(width));
      }
    } else if (data === '\x0c') {
      // Ctrl+L: 画面クリア
      ttyRef.current?.clear();
      showPrompt();
      ttyRef.current?.write(inputBufferRef.current);
      // カーソル位置を復元
      const afterCursorWidth = getDisplayWidth(inputBufferRef.current.slice(cursorPosRef.current));
      if (afterCursorWidth > 0) {
        ttyRef.current?.write('\x1b[D'.repeat(afterCursorWidth));
      }
    } else if (data === '\x15') {
      // Ctrl+U: 行クリア
      const buf = inputBufferRef.current;
      const pos = cursorPosRef.current;
      const bufWidth = getDisplayWidth(buf);
      const afterCursorWidth = getDisplayWidth(buf.slice(pos));
      // カーソルを末尾に移動してからクリア
      ttyRef.current?.write('\x1b[C'.repeat(afterCursorWidth));
      ttyRef.current?.write('\b \b'.repeat(bufWidth));
      setInputBuffer('');
      setCursorPos(0);
    } else if (data.length >= 1 && data[0] >= ' ') {
      // 通常の文字（複数文字対応）
      const buf = inputBufferRef.current;
      const pos = cursorPosRef.current;
      const newBuf = buf.slice(0, pos) + data + buf.slice(pos);
      setInputBuffer(newBuf);
      setCursorPos(pos + data.length);
      // 文字を挿入して残りを再描画
      const remaining = buf.slice(pos);
      const remainingWidth = getDisplayWidth(remaining);
      ttyRef.current?.write(data + remaining);
      // 残りの文字数分だけカーソルを戻す
      if (remainingWidth > 0) {
        ttyRef.current?.write('\x1b[D'.repeat(remainingWidth));
      }
    }
  }, [isExecuting, executeCommand, commandHistory, historyIndex, showPrompt]);

  // 初期化
  useEffect(() => {
    const init = async () => {
      // .shellrc を実行
      const result = await shell.current.initialize();

      // 初期化結果を表示
      if (result.stdout) {
        ttyRef.current?.write(result.stdout);
        if (!result.stdout.endsWith('\n')) {
          ttyRef.current?.write('\n');
        }
      }
      if (result.stderr) {
        ttyRef.current?.write('\x1b[31m' + result.stderr + '\x1b[0m');
        if (!result.stderr.endsWith('\n')) {
          ttyRef.current?.write('\n');
        }
      }

      // プロンプト表示
      showPrompt();
    };

    // TTY が初期化されてから実行
    const timer = setTimeout(init, 100);
    return () => clearTimeout(timer);
  }, [showPrompt]);

  return (
    <Tty ref={ttyRef} onInput={handleInput} />
  );
}
