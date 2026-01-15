import { VirtualFileSystem, getFileSystem } from './index';
import { getBinaryFiles } from './content-loader';

/**
 * 初期 WASM バイナリを仮想ファイルシステムに読み込む
 */
export async function initWasmBinaries(): Promise<void> {
  const fs = getFileSystem();
  const binaryFiles = getBinaryFiles();

  // 各 WASM バイナリを fetch して FS に書き込み
  for (const file of binaryFiles) {
    // 既に存在する場合はスキップ
    if (fs.exists(file.path)) {
      continue;
    }

    // 親ディレクトリを作成
    const parentPath = file.path.split('/').slice(0, -1).join('/');
    if (parentPath && !fs.exists(parentPath)) {
      fs.mkdir(parentPath);
    }

    try {
      const response = await fetch(file.url);
      if (!response.ok) {
        console.warn(`Failed to fetch ${file.path}: ${response.status}`);
        continue;
      }

      const binary = new Uint8Array(await response.arrayBuffer());
      fs.writeFile(file.path, binary);
      console.log(`Loaded ${file.path} (${binary.length} bytes)`);
    } catch (error) {
      console.warn(`Failed to load ${file.path}:`, error);
    }
  }
}

/**
 * FS が初期化済みかどうか
 */
let initialized = false;

/**
 * FS を初期化（一度だけ実行）
 */
export async function ensureInitialized(): Promise<VirtualFileSystem> {
  const fs = getFileSystem();

  if (!initialized) {
    await initWasmBinaries();
    initialized = true;
  }

  return fs;
}
