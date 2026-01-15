/**
 * WASM Component を動的にロードして実行する
 *
 * stdout/stderr は WASI CLI ストリームを通じてキャプチャされる。
 * コマンドは println!/eprintln! マクロを使用して出力し、
 * 戻り値として exit code のみを返す。
 */

import type { CommandInput, CommandOutput } from './types';
import { getFileSystem } from '../filesystem';
import { WASIShim } from '@bytecodealliance/preview2-shim/instantiation';

// ブラウザ専用の内部APIの型定義
// preview2-shim の型定義は `export type *` なので値としてのエクスポートがない
// そのため動的インポートで取得する必要がある
interface BrowserFilesystemApi {
  _setFileData: (data: object) => void;
  _setCwd: (cwd: string) => void;
}

// CLI モジュールの内部API型定義
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


/**
 * stdout/stderr をキャプチャするためのクラス
 */
class OutputCapture {
  private chunks: Uint8Array[] = [];

  handler: OutputStreamHandler = {
    write: (buf: Uint8Array) => {
      // 入力バッファをコピーして保存
      this.chunks.push(new Uint8Array(buf));
    },
    blockingFlush: () => {
      // ブラウザ環境では特に何もしない
    },
  };

  /**
   * キャプチャした内容を文字列として取得
   */
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

  /**
   * キャプチャをリセット
   */
  clear(): void {
    this.chunks = [];
  }
}

/**
 * WASM バイナリを実行する
 *
 * 1. jco.transpile() でランタイム JS 変換
 * 2. 生成された core WASM ファイルをコンパイル
 * 3. 生成された JS を Blob URL で動的ロード
 * 4. instantiate() でインスタンス化（stdout/stderr キャプチャ付き）
 * 5. run() を呼び出し
 * 6. キャプチャした stdout/stderr と exit code を返す
 */
export async function executeWasmCommand(
  wasmBinary: Uint8Array,
  commandName: string,
  input: CommandInput
): Promise<CommandOutput> {
  // stdout/stderr キャプチャを作成
  const stdoutCapture = new OutputCapture();
  const stderrCapture = new OutputCapture();

  try {
    // jco を動的インポート（ブラウザ用）
    const jco = await import('@bytecodealliance/jco');

    // Step 1: jco でランタイム transpile
    const { files } = await jco.transpile(wasmBinary, {
      name: commandName,
      instantiation: { tag: 'async' },
    });

    // Step 2: 生成されたファイルを分類
    // files は Array<[string, Uint8Array]> の形式
    const jsFileName = `${commandName}.js`;
    const jsFile = files.find(([name]: [string, Uint8Array]) => name === jsFileName);
    if (!jsFile) {
      throw new Error(`Generated JS file not found: ${jsFileName}`);
    }

    // Step 3: core WASM ファイルをコンパイルしてマップに保存
    const wasmModules = new Map<string, WebAssembly.Module>();
    for (const [name, content] of files) {
      if (name.endsWith('.wasm')) {
        const module = await WebAssembly.compile(content);
        wasmModules.set(name, module);
      }
    }

    // Step 4: getCoreModule コールバックを作成
    const getCoreModule = (name: string): WebAssembly.Module => {
      const module = wasmModules.get(name);
      if (!module) {
        throw new Error(`Core module not found: ${name}`);
      }
      return module;
    };

    const jsCode = new TextDecoder().decode(jsFile[1]);

    // Step 5: Blob URL で動的ロード
    const jsBlob = new Blob([jsCode], { type: 'text/javascript' });
    const jsUrl = URL.createObjectURL(jsBlob);

    try {
      // Step 6: 動的インポート
      const module = await import(/* @vite-ignore */ jsUrl);

      // Step 7: instantiate を呼び出し
      if (typeof module.instantiate !== 'function') {
        throw new Error('No instantiate function found in generated module');
      }

      // WASI imports を準備（stdout/stderr キャプチャ付き、stdin データあり）
      const wasiImports = await getWasiImports(input.cwd, stdoutCapture, stderrCapture, input.stdin);
      const instance = await module.instantiate(getCoreModule, wasiImports);

      // Step 8: run() を呼び出し（exit code のみを返す）
      let exitCode = 0;
      if (typeof instance.run === 'function') {
        exitCode = instance.run(input);
      } else {
        throw new Error('No run function found in WASM module');
      }

      // Step 9: キャプチャした stdout/stderr と exit code を返す
      return {
        stdout: stdoutCapture.getOutput(),
        stderr: stderrCapture.getOutput(),
        exitCode,
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
 *
 * preview2-shim の型定義は `export type *` なので値としてのエクスポートがない。
 * ブラウザ専用の内部API にアクセスするため動的インポートを使用。
 *
 * stdout/stderr のキャプチャも設定する。
 */
async function getWasiImports(
  _cwd: string,
  stdoutCapture: OutputCapture,
  stderrCapture: OutputCapture,
  stdinData?: string
): Promise<Record<string, unknown>> {
  // VirtualFileSystem のデータを preview2-shim 形式に変換して同期
  const fs = getFileSystem();
  const fileData = convertToPreview2Format(fs);

  // ブラウザ専用の内部APIを動的インポートで取得
  const filesystemModule = (await import(
    '@bytecodealliance/preview2-shim/filesystem'
  )) as BrowserFilesystemApi;

  const cliModule = (await import(
    '@bytecodealliance/preview2-shim/cli'
  )) as unknown as BrowserCliApi;

  filesystemModule._setFileData(fileData);

  // stdout/stderr のキャプチャを設定
  cliModule._setStdout(stdoutCapture.handler);
  cliModule._setStderr(stderrCapture.handler);

  // stdin のハンドラを設定
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

  // WASIShim を使ってインポートオブジェクトを生成
  const shim = new WASIShim();
  return shim.getImportObject();
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
