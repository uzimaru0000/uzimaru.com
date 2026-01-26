/**
 * WASM Command Executor Worker
 *
 * WASM コマンドの実行を Web Worker で行うことで、
 * メインスレッドのブロッキングを回避する。
 */

import type { CommandInput, CommandOutput } from './types';
import { WASIShim } from '@bytecodealliance/preview2-shim/instantiation';
import { WorkerStdinBuffer } from './stdin-buffer';
import { WorkerStdoutBuffer } from './stdout-buffer';
import { customPoll, customMonotonicClock } from './wasi-pollable';

// ブラウザ専用の内部APIの型定義
interface BrowserFilesystemApi {
  _setFileData: (data: object) => void;
  _getFileData: () => object;
  _setCwd: (cwd: string) => void;
}

interface BrowserCliApi {
  _setStdout: (handler: OutputStreamHandler) => void;
  _setStderr: (handler: OutputStreamHandler) => void;
  _setStdin: (handler: InputStreamHandler) => void;
}

interface OutputStreamHandler {
  write: (buf: Uint8Array) => void;
  blockingFlush: () => void;
}

interface InputStreamHandler {
  blockingRead: (len: bigint) => Uint8Array;
}

// Worker メッセージの型定義
interface WorkerRequest {
  id: string;
  wasmBinary: Uint8Array;
  commandName: string;
  input: CommandInput;
  fileSystemData: object;
  stdinBuffer?: SharedArrayBuffer;  // インタラクティブ stdin 用
  stdoutBuffer?: SharedArrayBuffer; // インタラクティブ stdout 用
}

interface WorkerResponse {
  id: string;
  result?: CommandOutput;
  error?: string;
}

/**
 * stdout/stderr をキャプチャするためのクラス
 */
class OutputCapture {
  private chunks: Uint8Array[] = [];

  handler: OutputStreamHandler = {
    write: (buf: Uint8Array) => {
      this.chunks.push(new Uint8Array(buf));
    },
    blockingFlush: () => {
      // ブラウザ環境では特に何もしない
    },
  };

  getOutput(): string {
    const totalLength = this.chunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const result = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of this.chunks) {
      result.set(chunk, offset);
      offset += chunk.length;
    }
    return new TextDecoder().decode(result);
  }

  clear(): void {
    this.chunks = [];
  }
}

/**
 * WASM コマンドを実行する（Worker 内部実装）
 */
async function executeWasmCommandImpl(
  wasmBinary: Uint8Array,
  commandName: string,
  input: CommandInput,
  fileSystemData: object,
  stdinBuffer?: SharedArrayBuffer,
  stdoutBuffer?: SharedArrayBuffer
): Promise<CommandOutput> {
  const stdoutCapture = new OutputCapture();
  const stderrCapture = new OutputCapture();

  try {
    const jco = await import('@bytecodealliance/jco');

    const { files } = await jco.transpile(wasmBinary, {
      name: commandName,
      instantiation: { tag: 'async' },
    });

    const jsFileName = `${commandName}.js`;
    const jsFile = files.find(([name]: [string, Uint8Array]) => name === jsFileName);
    if (!jsFile) {
      throw new Error(`Generated JS file not found: ${jsFileName}`);
    }

    const wasmModules = new Map<string, WebAssembly.Module>();
    for (const [name, content] of files) {
      if (name.endsWith('.wasm')) {
        const module = await WebAssembly.compile(content);
        wasmModules.set(name, module);
      }
    }

    const getCoreModule = (name: string): WebAssembly.Module => {
      const module = wasmModules.get(name);
      if (!module) {
        throw new Error(`Core module not found: ${name}`);
      }
      return module;
    };

    const jsCode = new TextDecoder().decode(jsFile[1]);
    const jsBlob = new Blob([jsCode], { type: 'text/javascript' });
    const jsUrl = URL.createObjectURL(jsBlob);

    try {
      const module = await import(/* @vite-ignore */ jsUrl);

      if (typeof module.instantiate !== 'function') {
        throw new Error('No instantiate function found in generated module');
      }

      const { wasiImports, getUpdatedFileSystem } = await getWasiImports(
        fileSystemData,
        stdoutCapture,
        stderrCapture,
        input.cwd,
        input.stdin,
        stdinBuffer,
        stdoutBuffer
      );
      const instance = await module.instantiate(getCoreModule, wasiImports);

      let exitCode = 0;
      if (typeof instance.run === 'function') {
        exitCode = instance.run(input);
      } else {
        throw new Error('No run function found in WASM module');
      }

      return {
        stdout: stdoutCapture.getOutput(),
        stderr: stderrCapture.getOutput(),
        exitCode,
        fileSystemData: getUpdatedFileSystem(),
      };
    } finally {
      URL.revokeObjectURL(jsUrl);
    }
  } catch (error) {
    console.error(`Failed to execute WASM command ${commandName}:`, error);
    return {
      stdout: stdoutCapture.getOutput(),
      stderr:
        stderrCapture.getOutput() +
        `\nError executing ${commandName}: ${error instanceof Error ? error.message : String(error)}`,
      exitCode: 1,
    };
  }
}

/**
 * WASI imports を取得
 */
async function getWasiImports(
  fileSystemData: object,
  stdoutCapture: OutputCapture,
  stderrCapture: OutputCapture,
  cwd: string,
  stdinData?: string,
  stdinBuffer?: SharedArrayBuffer,
  stdoutBuffer?: SharedArrayBuffer
): Promise<{ wasiImports: Record<string, unknown>; getUpdatedFileSystem: () => object }> {
  const filesystemModule = (await import(
    '@bytecodealliance/preview2-shim/filesystem'
  )) as BrowserFilesystemApi;

  const cliModule = (await import(
    '@bytecodealliance/preview2-shim/cli'
  )) as unknown as BrowserCliApi;

  filesystemModule._setFileData(fileSystemData);
  filesystemModule._setCwd(cwd);

  // stdout の設定
  if (stdoutBuffer) {
    // インタラクティブモード: SharedArrayBuffer を使ってリアルタイムストリーミング
    const workerStdout = new WorkerStdoutBuffer(stdoutBuffer);
    cliModule._setStdout({
      write: (buf: Uint8Array) => {
        // リアルタイムでメインスレッドに送信
        workerStdout.write(buf);
        // キャプチャも行う（最終結果用）
        stdoutCapture.handler.write(buf);
      },
      blockingFlush: () => {
        stdoutCapture.handler.blockingFlush();
      },
    });
  } else {
    cliModule._setStdout(stdoutCapture.handler);
  }

  cliModule._setStderr(stderrCapture.handler);

  if (stdinBuffer) {
    // インタラクティブモード: SharedArrayBuffer を使ったブロッキング読み取り
    const workerStdin = new WorkerStdinBuffer(stdinBuffer);
    cliModule._setStdin({
      blockingRead: (len: bigint): Uint8Array => {
        return workerStdin.blockingRead(Number(len));
      },
    });
  } else {
    // パイプモード: 事前データからの読み取り
    const stdinBytes = stdinData ? new TextEncoder().encode(stdinData) : new Uint8Array(0);
    let stdinOffset = 0;

    cliModule._setStdin({
      blockingRead: (len: bigint): Uint8Array => {
        const remaining = stdinBytes.length - stdinOffset;
        if (remaining <= 0) {
          return new Uint8Array(0);
        }
        const toRead = Math.min(Number(len), remaining);
        const result = stdinBytes.slice(stdinOffset, stdinOffset + toRead);
        stdinOffset += toRead;
        return result;
      },
    });
  }

  const shim = new WASIShim();
  const imports = shim.getImportObject() as Record<string, unknown>;

  // カスタム poll と monotonicClock でオーバーライド
  // これにより thread::sleep が Atomics.wait() を使ってブロッキング待機できる
  imports['wasi:io/poll'] = customPoll;
  imports['wasi:clocks/monotonic-clock'] = customMonotonicClock;

  return {
    wasiImports: imports,
    getUpdatedFileSystem: () => filesystemModule._getFileData(),
  };
}

// Worker メッセージハンドラ
self.onmessage = async (event: MessageEvent<WorkerRequest>) => {
  const { id, wasmBinary, commandName, input, fileSystemData, stdinBuffer, stdoutBuffer } = event.data;

  // stdout バッファの完了通知用
  let workerStdout: WorkerStdoutBuffer | null = null;
  if (stdoutBuffer) {
    workerStdout = new WorkerStdoutBuffer(stdoutBuffer);
  }

  try {
    const result = await executeWasmCommandImpl(
      wasmBinary,
      commandName,
      input,
      fileSystemData,
      stdinBuffer,
      stdoutBuffer
    );

    // stdout バッファの完了を通知
    if (workerStdout) {
      workerStdout.complete();
    }

    const response: WorkerResponse = { id, result };
    self.postMessage(response);
  } catch (error) {
    // stdout バッファの完了を通知（エラー時も）
    if (workerStdout) {
      workerStdout.complete();
    }

    const response: WorkerResponse = {
      id,
      error: error instanceof Error ? error.message : String(error),
    };
    self.postMessage(response);
  }
};
