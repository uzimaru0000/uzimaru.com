import { useState, useRef, useEffect, useCallback, KeyboardEvent } from 'react';
import { createShell } from '../shell/dispatcher';
import type { ExecResult, ShellState } from '../shell/types';
import { AnsiText } from './AnsiText';

interface HistoryEntry {
  command: string;
  result: ExecResult;
  cwd: string;
  prompt: string;
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
        case 'w': { // カレントディレクトリ (~ 展開あり)
          const home = state.env.get('HOME') || '/home/uzimaru0000';
          result += state.cwd.startsWith(home)
            ? '~' + state.cwd.slice(home.length)
            : state.cwd;
          break;
        }
        case 'W': // カレントディレクトリのベース名
          result += state.cwd.split('/').pop() || '/';
          break;
        case 'u': // ユーザー名
          result += state.env.get('USER') || 'user';
          break;
        case 'h': // ホスト名
          result += state.env.get('HOSTNAME') || window.location.host;
          break;
        case '$': // $ or #
          result += state.env.get('USER') === 'root' ? '#' : '$';
          break;
        case '\\':
          result += '\\';
          break;
        case 'n':
          result += '\n';
          break;
        case 'e': // ESC
          result += '\x1b';
          break;
        case '[': // 無視 (readline用)
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
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [input, setInput] = useState('');
  const [commandHistory, setCommandHistory] = useState<string[]>([]);
  const [historyIndex, setHistoryIndex] = useState(-1);
  const [isExecuting, setIsExecuting] = useState(false);
  const [currentPrompt, setCurrentPrompt] = useState('$ ');
  const inputRef = useRef<HTMLInputElement>(null);
  const terminalRef = useRef<HTMLDivElement>(null);
  const shell = useRef(createShell());

  const handleSubmit = useCallback(async () => {
    if (isExecuting) return;

    const trimmed = input.trim();
    const cwd = shell.current.getCwd();
    const prompt = currentPrompt;

    setInput('');
    setHistoryIndex(-1);

    if (trimmed) {
      setIsExecuting(true);

      // コマンド実行中の表示を追加
      setHistory((prev) => [
        ...prev,
        { command: trimmed, result: { stdout: '', stderr: '', exitCode: -1 }, cwd, prompt },
      ]);

      try {
        const result = await shell.current.execute(trimmed);

        // Handle clear command
        if (result.stdout === '\x1b[clear]') {
          setHistory([]);
          setIsExecuting(false);
          setCurrentPrompt(getPrompt(shell.current));
          return;
        }

        // Handle exit command
        if (result.stdout === '\x1b[exit]') {
          onClose();
          return;
        }

        // 結果で更新
        setHistory((prev) => {
          const newHistory = [...prev];
          newHistory[newHistory.length - 1] = { command: trimmed, result, cwd, prompt };
          return newHistory;
        });
        setCommandHistory((prev) => [...prev, trimmed]);
      } catch (error) {
        setHistory((prev) => {
          const newHistory = [...prev];
          newHistory[newHistory.length - 1] = {
            command: trimmed,
            result: {
              stdout: '',
              stderr: `Error: ${error instanceof Error ? error.message : String(error)}`,
              exitCode: 1,
            },
            cwd,
            prompt,
          };
          return newHistory;
        });
      } finally {
        setIsExecuting(false);
        setCurrentPrompt(getPrompt(shell.current));
      }
    } else {
      setHistory((prev) => [
        ...prev,
        { command: '', result: { stdout: '', stderr: '', exitCode: 0 }, cwd, prompt: currentPrompt },
      ]);
    }
  }, [input, isExecuting, currentPrompt]);

  const focusInput = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  const handleKeyDown = useCallback(
    (e: KeyboardEvent<HTMLInputElement>) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        handleSubmit();
      } else if (e.ctrlKey && e.key === 'l') {
        e.preventDefault();
        setHistory([]);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (commandHistory.length > 0) {
          const newIndex =
            historyIndex === -1 ? commandHistory.length - 1 : Math.max(0, historyIndex - 1);
          setHistoryIndex(newIndex);
          setInput(commandHistory[newIndex]);
        }
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (historyIndex !== -1) {
          const newIndex = historyIndex + 1;
          if (newIndex >= commandHistory.length) {
            setHistoryIndex(-1);
            setInput('');
          } else {
            setHistoryIndex(newIndex);
            setInput(commandHistory[newIndex]);
          }
        }
      }
    },
    [handleSubmit, commandHistory, historyIndex, focusInput]
  );

  useEffect(() => {
    inputRef.current?.focus();
    // 初期化時に .shellrc を実行して結果を表示
    shell.current.initialize().then((result) => {
      setCurrentPrompt(getPrompt(shell.current));
      if (result.stdout || result.stderr) {
        setHistory([{
          command: '',
          result,
          cwd: shell.current.getCwd(),
          prompt: getPrompt(shell.current),
        }]);
      }
    });
  }, []);

  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTo({ top: terminalRef.current.scrollHeight });
    }
  }, [history]);

  // コマンド実行完了後にinputにフォーカスを戻す
  useEffect(() => {
    if (!isExecuting) {
      inputRef.current?.focus();
    }
  }, [isExecuting]);

  return (
    <div
      ref={terminalRef}
      onClick={focusInput}
      className="h-full p-4 overflow-y-auto cursor-text bg-term-bg"
    >
      {history.map((entry, i) => (
        <div key={i} className="mb-2">
          {entry.command !== '' && (
            <div className="flex gap-1">
              <AnsiText text={entry.prompt} />
              <span className="text-term-string">{entry.command}</span>
            </div>
          )}
          {entry.result.exitCode === -1 ? (
            <div className="text-term-muted">Executing...</div>
          ) : (
            <>
              {entry.result.stdout && (
                <div><AnsiText text={entry.result.stdout} /></div>
              )}
              {entry.result.stderr && (
                <div><AnsiText text={entry.result.stderr} baseColor="#f44747" /></div>
              )}
            </>
          )}
        </div>
      ))}

      <div className="flex items-center">
        <AnsiText text={currentPrompt} />
        <input
          ref={inputRef}
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          disabled={isExecuting}
          className={`flex-1 bg-transparent border-none outline-none text-term-string font-inherit ${isExecuting ? 'opacity-50' : ''}`}
          autoComplete="off"
          spellCheck={false}
        />
      </div>
    </div>
  );
}
