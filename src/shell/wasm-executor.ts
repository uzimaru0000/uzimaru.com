/**
 * WASM Command Executor
 *
 * Worker を使って WASM コマンドを実行する。
 * メインスレッドのブロッキングを回避。
 */

import type { CommandInput, CommandOutput } from './types';
import { getFileSystem } from '../filesystem';
import { MainThreadStdinBuffer } from './stdin-buffer';

// Worker インスタンス（遅延初期化）
let worker: Worker | null = null;

// 現在実行中のコマンドの stdin バッファ
let currentStdinBuffer: MainThreadStdinBuffer | null = null;

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
        const fileResult = fs.readFile(childPath);
        if (fileResult.tag === 'ok' && fileResult.val) {
          dir[entry.name] = { source: fileResult.val };
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
 */
export async function executeWasmCommand(
  wasmBinary: Uint8Array,
  commandName: string,
  input: CommandInput,
  interactive: boolean = false
): Promise<CommandOutput> {
  const w = getWorker();

  // ファイルシステムのデータを Worker に渡す
  const fs = getFileSystem();
  const fileSystemData = convertToPreview2Format(fs);

  // インタラクティブモードの場合は SharedArrayBuffer を作成
  let stdinBuffer: SharedArrayBuffer | undefined;
  if (interactive && isSharedArrayBufferAvailable()) {
    currentStdinBuffer = new MainThreadStdinBuffer();
    stdinBuffer = currentStdinBuffer.getBuffer();
  }

  return new Promise((resolve, reject) => {
    const id = crypto.randomUUID();

    const handler = (event: MessageEvent<WorkerResponse>) => {
      if (event.data.id === id) {
        w.removeEventListener('message', handler);

        // stdin バッファをクリア
        currentStdinBuffer = null;

        if (event.data.error) {
          reject(new Error(event.data.error));
        } else if (event.data.result) {
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
