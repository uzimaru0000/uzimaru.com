/**
 * シェルパーサー WASM モジュールのローダーと実行
 */

import { getFileSystem } from '../filesystem';
import { WASIShim } from '@bytecodealliance/preview2-shim/instantiation';
import type {
  ShellParserModule,
  ParseResult,
  ParseError,
  ParsedWord,
} from './shell-types';

let shellParserModule: ShellParserModule | null = null;

/**
 * WASI imports を取得（シェルパーサーは I/O を使わないが、WASI shim は必要）
 */
async function getWasiImports(): Promise<Record<string, unknown>> {
  const shim = new WASIShim();
  return shim.getImportObject();
}

/**
 * シェルパーサー WASM をロード
 */
export async function loadShellParser(): Promise<ShellParserModule> {
  if (shellParserModule) {
    return shellParserModule;
  }

  const fs = getFileSystem();
  const result = fs.readFile('/bin/shell.wasm');

  if (result.tag === 'err') {
    throw new Error('Shell parser not found at /bin/shell.wasm');
  }

  // jco を動的インポート
  const jco = await import('@bytecodealliance/jco');

  // Transpile
  const { files } = await jco.transpile(result.val, {
    name: 'shell',
    instantiation: { tag: 'async' },
  });

  // JS ファイルを探す
  const jsFile = files.find(([name]: [string, Uint8Array]) => name === 'shell.js');
  if (!jsFile) {
    throw new Error('Generated JS file not found');
  }

  // WASM モジュールをコンパイル
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

  // Blob URL で動的ロード
  const jsCode = new TextDecoder().decode(jsFile[1]);
  const jsBlob = new Blob([jsCode], { type: 'text/javascript' });
  const jsUrl = URL.createObjectURL(jsBlob);

  try {
    const module = await import(/* @vite-ignore */ jsUrl);

    if (typeof module.instantiate !== 'function') {
      throw new Error('No instantiate function found');
    }

    // WASI imports を提供してインスタンス化
    const wasiImports = await getWasiImports();
    const instance = await module.instantiate(getCoreModule, wasiImports);

    shellParserModule = instance as ShellParserModule;
    return shellParserModule;
  } finally {
    URL.revokeObjectURL(jsUrl);
  }
}

/**
 * チルダ展開を行う
 * ~ → $HOME
 * ~/path → $HOME/path
 */
function expandTilde(value: string, home: string): string {
  if (value === '~') {
    return home;
  }
  if (value.startsWith('~/')) {
    return home + value.slice(1);
  }
  return value;
}

/**
 * パース結果からワードを展開
 */
export function expandWord(
  word: ParsedWord,
  env: Map<string, string>,
  substitutions: Map<number, string>
): string {
  const home = env.get('HOME') ?? '/home/uzimaru0000';
  const segments = word.segments;

  // 最初のセグメントがリテラルでチルダから始まる場合は展開
  const expanded = segments.map((seg, index) => {
    switch (seg.tag) {
      case 'literal':
        // 最初のセグメントのみチルダ展開を適用
        if (index === 0) {
          return expandTilde(seg.val, home);
        }
        return seg.val;
      case 'env-var':
        return env.get(seg.val.name) ?? seg.val.defaultValue ?? '';
      case 'command-subst':
        return substitutions.get(seg.val) ?? '';
      default:
        return '';
    }
  });

  return expanded.join('');
}

/**
 * シェルコマンドをパース
 */
export async function parseShellCommand(
  input: string
): Promise<{ ok: true; value: ParseResult } | { ok: false; error: ParseError }> {
  try {
    const parser = await loadShellParser();
    const result = parser.parser.parse(input);

    // jco が生成するコードでは Result 型は直接値を返す
    // エラーの場合は例外を投げる
    if ('elements' in result) {
      return { ok: true, value: result as unknown as ParseResult };
    } else if ('tag' in result) {
      if (result.tag === 'ok') {
        return { ok: true, value: result.val };
      } else {
        return { ok: false, error: result.val };
      }
    } else {
      return { ok: false, error: { message: 'Unknown parse result format', position: 0 } };
    }
  } catch (e) {
    // jco のエラー形式: { payload: ParseError }
    const error = e as { payload?: ParseError; message?: string };
    if (error.payload && typeof error.payload === 'object') {
      return { ok: false, error: error.payload };
    }
    return {
      ok: false,
      error: {
        message: error.message || String(e),
        position: 0,
      },
    };
  }
}
