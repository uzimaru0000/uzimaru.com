/**
 * WASM Command Executor
 *
 * Worker を使って WASM コマンドを実行する。
 * メインスレッドのブロッキングを回避。
 */

import type { CommandInput, CommandOutput } from './types';
import { getFileSystem } from '../filesystem';
import { MainThreadStdinBuffer } from './stdin-buffer';
import { MainThreadStdoutBuffer } from './stdout-buffer';

// Worker インスタンス（遅延初期化）
let worker: Worker | null = null;

// 現在実行中のコマンドの stdin/stdout バッファ
let currentStdinBuffer: MainThreadStdinBuffer | null = null;
let currentStdoutBuffer: MainThreadStdoutBuffer | null = null;
let stdoutPollInterval: ReturnType<typeof setInterval> | null = null;
let currentStdoutCallback: ((data: string) => void) | null = null;

// Worker レスポンスの型定義
interface WorkerResponse {
  id: string;
  result?: CommandOutput;
  error?: string;
}

/**
 * Worker を初期化（遅延）
 */
function getWorker(): Worker {
  if (!worker) {
    worker = new Worker(
      new URL('./wasm-executor.worker.ts', import.meta.url),
      { type: 'module' }
    );
  }
  return worker;
}

/**
 * preview2-shim 形式のファイルシステムデータを仮想ファイルシステムに適用
 */
function applyFileSystemChanges(
  fs: ReturnType<typeof getFileSystem>,
  data: object,
  basePath: string = ''
): void {
  const node = data as { dir?: Record<string, object>; source?: string };

  if (node.dir) {
    // ディレクトリ
    for (const [name, child] of Object.entries(node.dir)) {
      const childPath = basePath ? `${basePath}/${name}` : `/${name}`;
      const childNode = child as { dir?: Record<string, object>; source?: string };

      if (childNode.dir !== undefined) {
        // サブディレクトリ
        if (!fs.exists(childPath)) {
          fs.mkdir(childPath);
        }
        applyFileSystemChanges(fs, child, childPath);
      } else if (childNode.source !== undefined) {
        // バイナリファイル（.wasm）はスキップ
        if (name.endsWith('.wasm')) {
          continue;
        }

        let sourceStr: string;
        if (typeof childNode.source === 'string') {
          sourceStr = childNode.source;
        } else if (typeof childNode.source === 'object' && childNode.source !== null) {
          // preview2-shim がバイト配列オブジェクト {"0": byte, "1": byte, ...} を返す場合
          const byteObj = childNode.source as Record<string, number>;
          const keys = Object.keys(byteObj).filter(k => /^\d+$/.test(k)).sort((a, b) => Number(a) - Number(b));
          if (keys.length > 0) {
            const bytes = new Uint8Array(keys.map(k => byteObj[k]));
            sourceStr = new TextDecoder().decode(bytes);
          } else {
            console.warn('[applyFileSystemChanges] skipping empty object source:', childPath);
            continue;
          }
        } else {
          console.warn('[applyFileSystemChanges] skipping unknown source type:', childPath, typeof childNode.source);
          continue;
        }

        // ファイル - 内容を更新
        const content = new TextEncoder().encode(sourceStr);
        fs.writeFile(childPath, content);
      }
    }
  }
}

/**
 * VirtualFileSystem を preview2-shim 形式に変換
 */
function convertToPreview2Format(fs: ReturnType<typeof getFileSystem>): object {
  const convertDir = (path: string): object => {
    const result = fs.listDir(path);
    if (result.tag !== 'ok' || !result.val) {
      return { dir: {} };
    }

    const dir: Record<string, object> = {};
    for (const entry of result.val) {
      const childPath = path === '/' ? `/${entry.name}` : `${path}/${entry.name}`;
      if (entry.isDir) {
        dir[entry.name] = convertDir(childPath);
      } else {
        // バイナリファイル（.wasm）はスキップ（テキストファイルのみ同期）
        if (entry.name.endsWith('.wasm')) {
          continue;
        }
        const fileResult = fs.readFile(childPath);
        if (fileResult.tag === 'ok' && fileResult.val) {
          // preview2-shim expects source to be a string
          const content = new TextDecoder().decode(fileResult.val);
          dir[entry.name] = { source: content };
        }
      }
    }
    return { dir };
  };

  return convertDir('/');
}

/**
 * SharedArrayBuffer が利用可能かチェック
 */
function isSharedArrayBufferAvailable(): boolean {
  try {
    return typeof SharedArrayBuffer !== 'undefined';
  } catch {
    return false;
  }
}

/**
 * WASM バイナリを実行する
 *
 * Worker に処理を委譲してメインスレッドのブロッキングを回避。
 *
 * @param wasmBinary WASM バイナリ
 * @param commandName コマンド名
 * @param input コマンド入力
 * @param interactive インタラクティブモード（stdin を待機）
 * @param onStdout stdout データを受け取るコールバック（インタラクティブモード用、省略時は currentStdoutCallback を使用）
 */
export async function executeWasmCommand(
  wasmBinary: Uint8Array,
  commandName: string,
  input: CommandInput,
  interactive: boolean = false,
  onStdout?: (data: string) => void
): Promise<CommandOutput> {
  const w = getWorker();

  // ファイルシステムのデータを Worker に渡す
  const fs = getFileSystem();
  const fileSystemData = convertToPreview2Format(fs);

  // stdout コールバック（引数で渡されたものか、事前に設定されたもの）
  const stdoutCallback = onStdout || currentStdoutCallback;

  // インタラクティブモードの場合は SharedArrayBuffer を作成
  let stdinBuffer: SharedArrayBuffer | undefined;
  let stdoutBuffer: SharedArrayBuffer | undefined;

  if (interactive && isSharedArrayBufferAvailable()) {
    currentStdinBuffer = new MainThreadStdinBuffer();
    stdinBuffer = currentStdinBuffer.getBuffer();

    // stdout ストリーミング用バッファ（コールバックがある場合）
    if (stdoutCallback) {
      currentStdoutBuffer = new MainThreadStdoutBuffer();
      stdoutBuffer = currentStdoutBuffer.getBuffer();
      currentStdoutCallback = stdoutCallback;

      // stdout をポーリングして読み取る
      stdoutPollInterval = setInterval(() => {
        if (currentStdoutBuffer && currentStdoutCallback) {
          const data = currentStdoutBuffer.readString();
          if (data) {
            currentStdoutCallback(data);
          }
        }
      }, 16); // 約60fps
    }
  }

  return new Promise((resolve, reject) => {
    const id = crypto.randomUUID();

    const cleanup = () => {
      // ポーリングを停止
      if (stdoutPollInterval) {
        clearInterval(stdoutPollInterval);
        stdoutPollInterval = null;
      }

      // 残りの stdout データを読み取る
      if (currentStdoutBuffer && currentStdoutCallback) {
        const data = currentStdoutBuffer.readString();
        if (data) {
          currentStdoutCallback(data);
        }
      }

      // バッファをクリア
      currentStdinBuffer = null;
      currentStdoutBuffer = null;
      currentStdoutCallback = null;
    };

    const handler = (event: MessageEvent<WorkerResponse>) => {
      if (event.data.id === id) {
        w.removeEventListener('message', handler);
        cleanup();

        if (event.data.error) {
          reject(new Error(event.data.error));
        } else if (event.data.result) {
          // ファイルシステムの変更を適用
          if (event.data.result.fileSystemData) {
            // _getFileData() が JSON 文字列を返す場合があるのでパース
            let fsData = event.data.result.fileSystemData;
            if (typeof fsData === 'string') {
              try {
                fsData = JSON.parse(fsData);
              } catch (e) {
                console.error('[wasm-executor] Failed to parse fileSystemData:', e);
              }
            }
            applyFileSystemChanges(fs, fsData);
          }
          resolve(event.data.result);
        } else {
          reject(new Error('Invalid worker response'));
        }
      }
    };

    w.addEventListener('message', handler);

    w.postMessage({
      id,
      wasmBinary,
      commandName,
      input,
      fileSystemData,
      stdinBuffer,
      stdoutBuffer,
    });
  });
}

/**
 * stdin にデータを送る
 *
 * インタラクティブモードで実行中のコマンドに stdin データを送信。
 */
export function writeStdin(data: string): void {
  if (currentStdinBuffer) {
    currentStdinBuffer.writeString(data);
  }
}

/**
 * stdin に EOF を送る
 *
 * インタラクティブモードで実行中のコマンドに EOF を送信。
 */
export function sendStdinEOF(): void {
  if (currentStdinBuffer) {
    currentStdinBuffer.sendEOF();
    currentStdinBuffer = null;
  }
}

/**
 * インタラクティブモードで実行中かどうか
 */
export function isInteractiveMode(): boolean {
  return currentStdinBuffer !== null;
}

/**
 * stdout コールバックを設定
 *
 * インタラクティブモードで実行する前に呼び出すことで、
 * stdout データをリアルタイムで受け取れる。
 */
export function setStdoutCallback(callback: ((data: string) => void) | null): void {
  currentStdoutCallback = callback;
}

/**
 * インタラクティブ stdout ストリーミングが有効かどうか
 */
export function hasStdoutStreaming(): boolean {
  return currentStdoutBuffer !== null;
}
