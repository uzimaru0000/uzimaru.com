import { getFileSystem } from '../filesystem';

const THEME_PATH = '/home/uzimaru0000/.theme.css';

/**
 * CSSファイルをパースしてCSS変数を抽出
 * :root { --color-ansi-0: #000000; } → Map { '--color-ansi-0' => '#000000' }
 */
export function parseThemeCss(content: string): Map<string, string> {
  const variables = new Map<string, string>();
  // :root { ... } 内の --xxx: yyy; を抽出
  const rootMatch = content.match(/:root\s*\{([^}]+)\}/);
  if (rootMatch) {
    const props = rootMatch[1].matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g);
    for (const [, name, value] of props) {
      variables.set(name.trim(), value.trim());
    }
  }
  return variables;
}

/**
 * CSS変数をdocument.documentElementに適用
 */
export function applyTheme(variables: Map<string, string>): void {
  const root = document.documentElement;
  for (const [name, value] of variables) {
    root.style.setProperty(name, value);
  }
}

/**
 * テーマファイルを読み込んで適用
 */
function loadAndApplyTheme(): void {
  const fs = getFileSystem();
  const result = fs.readFile(THEME_PATH);
  if (result.tag === 'ok') {
    const content = new TextDecoder().decode(result.val);
    const variables = parseThemeCss(content);
    applyTheme(variables);
  }
}

/**
 * テーマ監視を開始（アプリ起動時に呼び出し）
 */
export function initThemeWatcher(): void {
  const fs = getFileSystem();

  // 初回読み込み
  loadAndApplyTheme();

  // ファイル変更を監視
  fs.subscribe((event) => {
    if (event.type === 'write' && event.path === THEME_PATH) {
      loadAndApplyTheme();
    }
  });
}
