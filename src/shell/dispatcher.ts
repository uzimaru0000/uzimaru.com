/**
 * コマンドディスパッチャー
 * シェルパーサー（Rust/WASM）を使用してコマンドを解析・実行
 */

import { getFileSystem } from '../filesystem';
import { executeWasmCommand } from './wasm-executor';
import { parseShellCommand, expandWord } from './shell-parser';
import type { CommandInput, ShellState, ExecResult } from './types';
import type { ParseResult, SimpleCommand, Pipeline } from './shell-types';

/**
 * ビルトインコマンドの定義
 */
const builtinCommands: Record<
  string,
  (state: ShellState, args: string[]) => ExecResult | Promise<ExecResult>
> = {
  cd: (state, args) => {
    const fs = getFileSystem();
    const target = args[1] ?? '/home/uzimaru0000';
    const newPath = resolvePath(state.cwd, target);

    if (!fs.exists(newPath)) {
      return { stdout: '', stderr: `cd: ${target}: No such file or directory`, exitCode: 1 };
    }

    const stat = fs.stat(newPath);
    if (stat.tag === 'ok' && !stat.val.isDir) {
      return { stdout: '', stderr: `cd: ${target}: Not a directory`, exitCode: 1 };
    }

    state.cwd = newPath;
    return { stdout: '', stderr: '', exitCode: 0 };
  },

  export: (state, args) => {
    if (args.length < 2) {
      let output = '';
      for (const [key, value] of state.env) {
        output += `${key}=${value}\n`;
      }
      return { stdout: output, stderr: '', exitCode: 0 };
    }

    // 最初の引数から key=value を取得
    const firstArg = args[1];
    const eqIndex = firstArg.indexOf('=');
    if (eqIndex === -1) {
      return { stdout: '', stderr: 'export: invalid argument', exitCode: 1 };
    }

    const key = firstArg.slice(0, eqIndex);
    // value は最初の引数の = 以降と、残りの引数を結合（空文字列は除外）
    const valueParts = [firstArg.slice(eqIndex + 1), ...args.slice(2)].filter(s => s !== '');
    const value = valueParts.join(' ');
    state.env.set(key, value);
    return { stdout: '', stderr: '', exitCode: 0 };
  },

  pwd: (state) => {
    return { stdout: state.cwd, stderr: '', exitCode: 0 };
  },

  clear: () => {
    return { stdout: '\x1b[clear]', stderr: '', exitCode: 0 };
  },

  exit: () => {
    return { stdout: '\x1b[exit]', stderr: '', exitCode: 0 };
  },

  mkdir: (state, args) => {
    const fs = getFileSystem();

    if (args.length < 2) {
      return { stdout: '', stderr: 'mkdir: missing operand', exitCode: 1 };
    }

    // -p オプションのパース
    let parents = false;
    const targets: string[] = [];

    for (let i = 1; i < args.length; i++) {
      const arg = args[i];
      if (arg === '-p' || arg === '--parents') {
        parents = true;
      } else if (!arg.startsWith('-')) {
        targets.push(arg);
      }
    }

    if (targets.length === 0) {
      return { stdout: '', stderr: 'mkdir: missing operand', exitCode: 1 };
    }

    for (const target of targets) {
      const fullPath = resolvePath(state.cwd, target);

      if (parents) {
        // -p: 親ディレクトリも作成
        const parts = fullPath.split('/').filter(Boolean);
        let currentPath = '';
        for (const part of parts) {
          currentPath += '/' + part;
          if (!fs.exists(currentPath)) {
            const result = fs.mkdir(currentPath);
            if (result.tag === 'err') {
              return { stdout: '', stderr: `mkdir: ${target}: Operation failed`, exitCode: 1 };
            }
          }
        }
      } else {
        const result = fs.mkdir(fullPath);
        if (result.tag === 'err') {
          const errMsg =
            result.val.tag === 'not-found'
              ? 'No such file or directory'
              : result.val.tag === 'permission-denied'
                ? 'File exists'
                : 'Operation failed';
          return { stdout: '', stderr: `mkdir: ${target}: ${errMsg}`, exitCode: 1 };
        }
      }
    }

    return { stdout: '', stderr: '', exitCode: 0 };
  },

  touch: (state, args) => {
    const fs = getFileSystem();

    if (args.length < 2) {
      return { stdout: '', stderr: 'touch: missing operand', exitCode: 1 };
    }

    for (let i = 1; i < args.length; i++) {
      const arg = args[i];
      if (arg.startsWith('-')) continue;

      const fullPath = resolvePath(state.cwd, arg);

      // Only create if doesn't exist
      if (!fs.exists(fullPath)) {
        const result = fs.writeFile(fullPath, new Uint8Array());
        if (result.tag === 'err') {
          return { stdout: '', stderr: `touch: ${arg}: No such file or directory`, exitCode: 1 };
        }
      }
    }

    return { stdout: '', stderr: '', exitCode: 0 };
  },

  rm: (state, args) => {
    const fs = getFileSystem();

    // Parse options
    let recursive = false;
    let force = false;
    const targets: string[] = [];

    for (let i = 1; i < args.length; i++) {
      const arg = args[i];
      if (arg === '-r' || arg === '-R' || arg === '--recursive') {
        recursive = true;
      } else if (arg === '-f' || arg === '--force') {
        force = true;
      } else if (arg === '-rf' || arg === '-fr') {
        recursive = true;
        force = true;
      } else if (arg.startsWith('-')) {
        // Handle combined flags
        if (arg.includes('r') || arg.includes('R')) recursive = true;
        if (arg.includes('f')) force = true;
      } else {
        targets.push(arg);
      }
    }

    if (targets.length === 0) {
      return { stdout: '', stderr: 'rm: missing operand', exitCode: 1 };
    }

    for (const target of targets) {
      const fullPath = resolvePath(state.cwd, target);

      if (!fs.exists(fullPath)) {
        if (!force) {
          return { stdout: '', stderr: `rm: ${target}: No such file or directory`, exitCode: 1 };
        }
        continue;
      }

      const stat = fs.stat(fullPath);
      if (stat.tag === 'ok' && stat.val.isDir && !recursive) {
        return { stdout: '', stderr: `rm: ${target}: is a directory`, exitCode: 1 };
      }

      const result = fs.remove(fullPath);
      if (result.tag === 'err' && !force) {
        return { stdout: '', stderr: `rm: ${target}: Operation failed`, exitCode: 1 };
      }
    }

    return { stdout: '', stderr: '', exitCode: 0 };
  },

  mv: (state, args) => {
    const fs = getFileSystem();

    const targets: string[] = [];
    for (let i = 1; i < args.length; i++) {
      const arg = args[i];
      if (!arg.startsWith('-')) {
        targets.push(arg);
      }
    }

    if (targets.length < 2) {
      return {
        stdout: '',
        stderr: `mv: missing destination file operand after '${targets[0] ?? ''}'`,
        exitCode: 1,
      };
    }

    const dest = targets.pop()!;
    const destPath = resolvePath(state.cwd, dest);
    const destStat = fs.stat(destPath);
    const destIsDir = destStat.tag === 'ok' && destStat.val.isDir;

    // Multiple sources require destination to be a directory
    if (targets.length > 1 && !destIsDir) {
      return { stdout: '', stderr: `mv: target '${dest}' is not a directory`, exitCode: 1 };
    }

    for (const source of targets) {
      const sourcePath = resolvePath(state.cwd, source);

      if (!fs.exists(sourcePath)) {
        return { stdout: '', stderr: `mv: ${source}: No such file or directory`, exitCode: 1 };
      }

      const finalDest = destIsDir
        ? `${destPath}/${source.split('/').pop()}`
        : destPath;

      // Read source content
      const sourceStat = fs.stat(sourcePath);
      if (sourceStat.tag === 'ok' && sourceStat.val.isDir) {
        // Directory move - copy contents recursively then remove source
        const moveResult = moveDirectory(fs, sourcePath, finalDest);
        if (!moveResult.success) {
          return { stdout: '', stderr: `mv: cannot move '${source}' to '${finalDest}': ${moveResult.error}`, exitCode: 1 };
        }
      } else {
        // File move
        const content = fs.readFile(sourcePath);
        if (content.tag === 'err') {
          return { stdout: '', stderr: `mv: cannot read '${source}'`, exitCode: 1 };
        }
        const writeResult = fs.writeFile(finalDest, content.val);
        if (writeResult.tag === 'err') {
          return { stdout: '', stderr: `mv: cannot write to '${finalDest}'`, exitCode: 1 };
        }
        fs.remove(sourcePath);
      }
    }

    return { stdout: '', stderr: '', exitCode: 0 };
  },

  alias: (state, args) => {
    // 引数なし: 全エイリアスを表示
    if (args.length < 2) {
      let output = '';
      for (const [name, value] of state.aliases) {
        output += `alias ${name}='${value}'\n`;
      }
      return { stdout: output, stderr: '', exitCode: 0 };
    }

    // alias定義をパース: alias name='value' or alias name=value
    const definition = args.slice(1).join(' ');
    const eqIndex = definition.indexOf('=');
    if (eqIndex === -1) {
      // 単一エイリアスを表示
      const name = definition.trim();
      const value = state.aliases.get(name);
      if (value) {
        return { stdout: `alias ${name}='${value}'\n`, stderr: '', exitCode: 0 };
      }
      return { stdout: '', stderr: `alias: ${name}: not found`, exitCode: 1 };
    }

    const name = definition.slice(0, eqIndex).trim();
    let value = definition.slice(eqIndex + 1).trim();

    // クォートを除去
    if (
      (value.startsWith("'") && value.endsWith("'")) ||
      (value.startsWith('"') && value.endsWith('"'))
    ) {
      value = value.slice(1, -1);
    }

    state.aliases.set(name, value);
    return { stdout: '', stderr: '', exitCode: 0 };
  },

  unalias: (state, args) => {
    if (args.length < 2) {
      return { stdout: '', stderr: 'unalias: usage: unalias name [name ...]', exitCode: 1 };
    }

    for (let i = 1; i < args.length; i++) {
      const name = args[i];
      if (!state.aliases.has(name)) {
        return { stdout: '', stderr: `unalias: ${name}: not found`, exitCode: 1 };
      }
      state.aliases.delete(name);
    }
    return { stdout: '', stderr: '', exitCode: 0 };
  },

  sh: async (state, args) => {
    if (args.length < 2) {
      return { stdout: '', stderr: 'sh: missing script file operand', exitCode: 1 };
    }

    const scriptPath = args[1];
    const fullPath = resolvePath(state.cwd, scriptPath);
    const fs = getFileSystem();

    if (!fs.exists(fullPath)) {
      return { stdout: '', stderr: `sh: ${scriptPath}: No such file or directory`, exitCode: 127 };
    }

    const readResult = fs.readFile(fullPath);
    if (readResult.tag === 'err') {
      return { stdout: '', stderr: `sh: ${scriptPath}: Cannot read file`, exitCode: 1 };
    }

    const content = new TextDecoder().decode(readResult.val);
    return await executeScript(content, state, scriptPath);
  },
};

/**
 * エイリアス展開（循環参照検出付き）
 */
function expandAlias(
  name: string,
  aliases: Map<string, string>,
  seen: Set<string> = new Set()
): { expanded: boolean; value?: string; error?: string } {
  if (!aliases.has(name)) {
    return { expanded: false };
  }

  if (seen.has(name)) {
    return { expanded: false, error: `alias: circular reference detected: ${name}` };
  }

  seen.add(name);
  const expansion = aliases.get(name)!;

  // 展開結果の最初の単語もエイリアスかチェック
  const firstWord = expansion.split(/\s+/)[0];
  if (aliases.has(firstWord) && firstWord !== name) {
    const nested = expandAlias(firstWord, aliases, seen);
    if (nested.error) {
      return nested;
    }
    if (nested.expanded) {
      const rest = expansion.slice(firstWord.length);
      return { expanded: true, value: nested.value + rest };
    }
  }

  return { expanded: true, value: expansion };
}

/**
 * スクリプト内容を複数行パースして実行
 */
async function executeScript(
  content: string,
  state: ShellState,
  _sourceName?: string
): Promise<ExecResult> {
  // コメント行を除去（行頭が # で始まる行を空行に）
  const processedContent = content
    .split('\n')
    .map((line) => {
      const trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        return '';
      }
      return line;
    })
    .join('\n');

  // 複数行をまとめてパース
  const parseResult = await parseShellCommand(processedContent);

  if (!parseResult.ok) {
    return {
      stdout: '',
      stderr: `parse error: ${parseResult.error.message}`,
      exitCode: 1,
    };
  }

  return executeParseResult(parseResult.value, state);
}

/**
 * source コマンドを実行
 */
async function executeSourceCommand(state: ShellState, filePath: string): Promise<ExecResult> {
  const fs = getFileSystem();
  const fullPath = resolvePath(state.cwd, filePath);

  const result = fs.readFile(fullPath);
  if (result.tag === 'err') {
    return { stdout: '', stderr: `source: ${filePath}: No such file or directory`, exitCode: 1 };
  }

  const content = new TextDecoder().decode(result.val);
  return await executeScript(content, state, filePath);
}

/**
 * shebang を検出してインタプリタを返す
 */
function detectShebang(content: string): string | null {
  const firstLine = content.split('\n')[0];
  if (!firstLine.startsWith('#!')) {
    return null;
  }

  const shebangLine = firstLine.slice(2).trim();
  const parts = shebangLine.split(/\s+/);

  // /usr/bin/env sh 形式
  if (parts[0] === '/usr/bin/env' && parts[1]) {
    return parts[1];
  }

  return parts[0];
}

/**
 * 実行可能ファイルを実行（shebang 対応）
 */
async function executeExecutableFile(
  cmdPath: string,
  _args: string[],
  state: ShellState,
  _stdin?: string
): Promise<ExecResult> {
  const fs = getFileSystem();
  const readResult = fs.readFile(cmdPath);

  if (readResult.tag === 'err') {
    return { stdout: '', stderr: `${cmdPath}: No such file or directory`, exitCode: 127 };
  }

  const content = new TextDecoder().decode(readResult.val);

  // shebang を検出
  const interpreter = detectShebang(content);

  // シェルスクリプトとして実行（shebang なし、または sh 系インタプリタ）
  if (!interpreter || interpreter === 'sh' || interpreter === '/bin/sh' || interpreter === '/usr/bin/sh') {
    return await executeScript(content, state, cmdPath);
  }

  // 他のインタプリタは未対応
  return {
    stdout: '',
    stderr: `${cmdPath}: unsupported interpreter: ${interpreter}`,
    exitCode: 126,
  };
}

/**
 * ディレクトリを再帰的に移動（コピー＆削除）
 */
function moveDirectory(
  fs: ReturnType<typeof getFileSystem>,
  sourcePath: string,
  destPath: string
): { success: boolean; error?: string } {
  // 移動先ディレクトリを作成
  const mkdirResult = fs.mkdir(destPath);
  if (mkdirResult.tag === 'err') {
    return { success: false, error: 'Cannot create destination directory' };
  }

  // ソースディレクトリの内容を取得
  const listResult = fs.listDir(sourcePath);
  if (listResult.tag !== 'ok' || !listResult.val) {
    return { success: false, error: 'Cannot read source directory' };
  }

  // 各エントリを移動
  for (const entry of listResult.val) {
    const srcEntryPath = `${sourcePath}/${entry.name}`;
    const destEntryPath = `${destPath}/${entry.name}`;

    if (entry.isDir) {
      // ディレクトリは再帰的に移動
      const result = moveDirectory(fs, srcEntryPath, destEntryPath);
      if (!result.success) {
        return result;
      }
    } else {
      // ファイルはコピー＆削除
      const content = fs.readFile(srcEntryPath);
      if (content.tag === 'err') {
        return { success: false, error: `Cannot read file: ${entry.name}` };
      }
      const writeResult = fs.writeFile(destEntryPath, content.val);
      if (writeResult.tag === 'err') {
        return { success: false, error: `Cannot write file: ${entry.name}` };
      }
    }
  }

  // ソースディレクトリを削除
  fs.remove(sourcePath);

  return { success: true };
}

/**
 * パス解決
 */
function resolvePath(cwd: string, target: string): string {
  if (target.startsWith('/')) {
    return normalizePath(target);
  }
  return normalizePath(`${cwd}/${target}`);
}

/**
 * パス正規化
 */
function normalizePath(path: string): string {
  const parts = path.split('/').filter((p) => p !== '' && p !== '.');
  const result: string[] = [];
  for (const part of parts) {
    if (part === '..') {
      result.pop();
    } else {
      result.push(part);
    }
  }
  return '/' + result.join('/');
}

/**
 * PATH 環境変数から WASM コマンドを探す
 */
function findWasmInPath(cmd: string, state: ShellState): Uint8Array | null {
  const fs = getFileSystem();
  const pathEnv = state.env.get('PATH') ?? '/bin';
  const paths = pathEnv.split(':').filter(Boolean);

  for (const dir of paths) {
    const wasmPath = `${dir}/${cmd}.wasm`;
    const result = fs.readFile(wasmPath);
    if (result.tag === 'ok') {
      return result.val;
    }
  }

  return null;
}

/**
 * PATH 環境変数からシェルスクリプトを探す
 */
function findScriptInPath(cmd: string, state: ShellState): { path: string; content: string } | null {
  const fs = getFileSystem();
  const pathEnv = state.env.get('PATH') ?? '/bin';
  const paths = pathEnv.split(':').filter(Boolean);

  for (const dir of paths) {
    const scriptPath = `${dir}/${cmd}.sh`;
    const result = fs.readFile(scriptPath);
    if (result.tag === 'ok') {
      return {
        path: scriptPath,
        content: new TextDecoder().decode(result.val),
      };
    }
  }

  return null;
}

/**
 * 外部コマンドを PATH から探して実行
 */
async function dispatchExternalCommand(
  cmd: string,
  args: string[],
  state: ShellState,
  stdin?: string
): Promise<ExecResult> {
  // PATH から WASM コマンドを探す
  const binary = findWasmInPath(cmd, state);
  if (binary) {
    // CommandInput を構築
    const input: CommandInput = {
      args,
      env: Array.from(state.env.entries()),
      cwd: state.cwd,
      stdin,
    };

    // WASM を実行
    // stdin がない場合はインタラクティブモード（ユーザー入力を待機）
    const interactive = stdin === undefined;
    const output = await executeWasmCommand(binary, cmd, input, interactive);

    return {
      stdout: output.stdout,
      stderr: output.stderr,
      exitCode: output.exitCode,
    };
  }

  // PATH からシェルスクリプトを探す
  const script = findScriptInPath(cmd, state);
  if (script) {
    return await executeScript(script.content, state, script.path);
  }

  return { stdout: '', stderr: `${cmd}: command not found`, exitCode: 127 };
}

/**
 * 単純コマンドを実行
 */
async function executeSimpleCommand(
  cmd: SimpleCommand,
  state: ShellState,
  substitutions: Map<number, string>,
  stdin?: string
): Promise<ExecResult> {
  // 引数を展開
  const expandedArgs = cmd.args.map((word) => expandWord(word, state.env, substitutions));

  if (expandedArgs.length === 0) {
    return { stdout: '', stderr: '', exitCode: 0 };
  }

  let cmdName = expandedArgs[0];

  // source / . コマンドの特殊処理（非同期のため）
  if (cmdName === 'source' || cmdName === '.') {
    if (expandedArgs.length < 2) {
      return { stdout: '', stderr: `${cmdName}: filename argument required`, exitCode: 1 };
    }
    return await executeSourceCommand(state, expandedArgs[1]);
  }

  // エイリアス展開
  const aliasResult = expandAlias(cmdName, state.aliases);
  if (aliasResult.error) {
    return { stdout: '', stderr: aliasResult.error, exitCode: 1 };
  }
  if (aliasResult.expanded) {
    const aliasArgs = aliasResult.value!.split(/\s+/);
    cmdName = aliasArgs[0];
    expandedArgs.splice(0, 1, ...aliasArgs);
  }

  // リダイレクト処理
  // stdin が undefined の場合はインタラクティブモードになるので、そのまま保持
  let finalStdin: string | undefined = stdin;
  let stdoutFile: string | null = null;
  let stdoutAppend = false;

  for (const redirect of cmd.redirects) {
    const target = expandWord(redirect.target, state.env, substitutions);
    switch (redirect.kind) {
      case 'stdin': {
        const fs = getFileSystem();
        const path = resolvePath(state.cwd, target);
        const readResult = fs.readFile(path);
        if (readResult.tag === 'ok') {
          finalStdin = new TextDecoder().decode(readResult.val);
        } else {
          return { stdout: '', stderr: `${cmdName}: ${target}: No such file or directory`, exitCode: 1 };
        }
        break;
      }
      case 'stdout':
        stdoutFile = target;
        stdoutAppend = false;
        break;
      case 'stdout-append':
        stdoutFile = target;
        stdoutAppend = true;
        break;
    }
  }

  // コマンド実行
  let result: ExecResult;

  if (cmdName in builtinCommands) {
    result = await Promise.resolve(builtinCommands[cmdName](state, expandedArgs));
  } else if (cmdName.startsWith('./') || cmdName.startsWith('/')) {
    // パス形式のコマンド（./xxx または /xxx）を検出し、実行可能ファイルとして実行
    const cmdPath = resolvePath(state.cwd, cmdName);
    result = await executeExecutableFile(cmdPath, expandedArgs, state, finalStdin);
  } else {
    result = await dispatchExternalCommand(cmdName, expandedArgs, state, finalStdin);
  }

  // stdout リダイレクト処理
  if (stdoutFile) {
    const fs = getFileSystem();
    const path = resolvePath(state.cwd, stdoutFile);
    const content = new TextEncoder().encode(result.stdout);

    if (stdoutAppend) {
      const existing = fs.readFile(path);
      if (existing.tag === 'ok') {
        const combined = new Uint8Array(existing.val.length + content.length);
        combined.set(existing.val);
        combined.set(content, existing.val.length);
        fs.writeFile(path, combined);
      } else {
        fs.writeFile(path, content);
      }
    } else {
      fs.writeFile(path, content);
    }

    result = { ...result, stdout: '' };
  }

  return result;
}

/**
 * パイプラインを実行
 */
async function executePipeline(
  pipeline: Pipeline,
  state: ShellState,
  substitutions: Map<number, string>
): Promise<ExecResult> {
  const { commands } = pipeline;

  if (commands.length === 0) {
    return { stdout: '', stderr: '', exitCode: 0 };
  }

  if (commands.length === 1) {
    return executeSimpleCommand(commands[0], state, substitutions);
  }

  // パイプライン実行
  let stdin = '';
  let lastResult: ExecResult = { stdout: '', stderr: '', exitCode: 0 };
  let accumulatedStderr = '';

  for (let i = 0; i < commands.length; i++) {
    const isLast = i === commands.length - 1;
    lastResult = await executeSimpleCommand(commands[i], state, substitutions, stdin);
    accumulatedStderr += lastResult.stderr;
    stdin = lastResult.stdout;

    if (lastResult.exitCode !== 0 && !isLast) {
      break;
    }
  }

  return {
    stdout: lastResult.stdout,
    stderr: accumulatedStderr,
    exitCode: lastResult.exitCode,
  };
}

/**
 * パース結果を実行
 */
async function executeParseResult(
  parseResult: ParseResult,
  state: ShellState
): Promise<ExecResult> {
  // コマンド置換を解決
  const substitutions = new Map<number, string>();

  for (const subst of parseResult.substitutions) {
    // 再帰的にコマンドを実行
    const substResult = await executeInput(subst.input, state);
    substitutions.set(subst.id, substResult.stdout.trimEnd());
  }

  // 条件分岐を評価しながら実行
  let lastExitCode = 0;
  let accumulatedStdout = '';
  let accumulatedStderr = '';

  for (const element of parseResult.elements) {
    // 接続子に基づいてスキップ判定
    if (element.connector === 'and' && lastExitCode !== 0) {
      continue;
    }
    if (element.connector === 'or' && lastExitCode === 0) {
      continue;
    }

    const result = await executePipeline(element.pipeline, state, substitutions);
    lastExitCode = result.exitCode;
    accumulatedStdout += result.stdout;
    accumulatedStderr += result.stderr;
  }

  return {
    stdout: accumulatedStdout,
    stderr: accumulatedStderr,
    exitCode: lastExitCode,
  };
}

/**
 * 入力文字列を実行（内部用）
 */
async function executeInput(input: string, state: ShellState): Promise<ExecResult> {
  const trimmed = input.trim();
  if (!trimmed) {
    return { stdout: '', stderr: '', exitCode: 0 };
  }

  // シェルパーサーでパース
  const parseResult = await parseShellCommand(trimmed);

  if (!parseResult.ok) {
    return {
      stdout: '',
      stderr: `parse error: ${parseResult.error.message}`,
      exitCode: 1,
    };
  }

  return executeParseResult(parseResult.value, state);
}

/**
 * シェルを作成
 */
export function createShell(): {
  execute: (input: string) => Promise<ExecResult>;
  getCwd: () => string;
  getState: () => ShellState;
  initialize: () => Promise<ExecResult>;
} {
  const state: ShellState = {
    cwd: '/home/uzimaru0000',
    env: new Map([
      ['USER', 'uzimaru0000'],
      ['HOME', '/home/uzimaru0000'],
      ['PATH', '/bin'],
    ]),
    aliases: new Map(),
  };

  let initialized = false;

  async function initialize(): Promise<ExecResult> {
    if (initialized) {
      return { stdout: '', stderr: '', exitCode: 0 };
    }
    initialized = true;

    // .shellrc が存在すれば読み込み
    const shellrcPath = '/home/uzimaru0000/.shellrc';
    const fs = getFileSystem();
    if (fs.exists(shellrcPath)) {
      return await executeSourceCommand(state, shellrcPath);
    }
    return { stdout: '', stderr: '', exitCode: 0 };
  }

  async function execute(input: string): Promise<ExecResult> {
    // 初回実行時に自動初期化
    if (!initialized) {
      await initialize();
    }
    return executeInput(input, state);
  }

  return {
    execute,
    getCwd: () => state.cwd,
    getState: () => state,
    initialize,
  };
}
