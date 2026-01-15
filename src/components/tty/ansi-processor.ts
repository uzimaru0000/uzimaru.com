/**
 * ANSI シーケンスをパースして AnsiAction に変換する
 */

export type AnsiAction =
  | { type: 'text'; text: string }
  | { type: 'sgr'; codes: number[] }
  | { type: 'cuu'; n: number }  // Cursor Up
  | { type: 'cud'; n: number }  // Cursor Down
  | { type: 'cuf'; n: number }  // Cursor Forward
  | { type: 'cub'; n: number }  // Cursor Back
  | { type: 'cup'; row: number; col: number }  // Cursor Position
  | { type: 'ed'; n: number }   // Erase Display
  | { type: 'el'; n: number }   // Erase Line
  | { type: 'cr' }  // Carriage Return
  | { type: 'lf' }  // Line Feed
  | { type: 'bs' }  // Backspace
  | { type: 'custom'; payload: unknown };  // カスタム OSC

const ESC = '\x1b';
const BEL = '\x07';
const ST = ESC + '\\';

/**
 * ANSI シーケンスストリームをパースしてアクションの配列を返す
 */
export function parseAnsiStream(text: string): AnsiAction[] {
  const actions: AnsiAction[] = [];
  let i = 0;
  let textBuffer = '';

  const flushText = () => {
    if (textBuffer) {
      actions.push({ type: 'text', text: textBuffer });
      textBuffer = '';
    }
  };

  while (i < text.length) {
    const char = text[i];

    // 制御文字
    if (char === '\r') {
      flushText();
      actions.push({ type: 'cr' });
      i++;
      continue;
    }

    if (char === '\n') {
      flushText();
      actions.push({ type: 'lf' });
      i++;
      continue;
    }

    if (char === '\b' || char === '\x08') {
      flushText();
      actions.push({ type: 'bs' });
      i++;
      continue;
    }

    // ESC シーケンス
    if (char === ESC) {
      flushText();

      // CSI シーケンス: ESC [
      if (text[i + 1] === '[') {
        const result = parseCSI(text, i + 2);
        if (result) {
          actions.push(result.action);
          i = result.endIndex;
          continue;
        }
      }

      // OSC シーケンス: ESC ]
      if (text[i + 1] === ']') {
        const result = parseOSC(text, i + 2);
        if (result) {
          actions.push(result.action);
          i = result.endIndex;
          continue;
        }
      }

      // 不明な ESC シーケンスはスキップ
      i++;
      continue;
    }

    // 通常の文字
    textBuffer += char;
    i++;
  }

  flushText();
  return actions;
}

/**
 * CSI シーケンスをパース
 * ESC [ の後から開始
 */
function parseCSI(text: string, start: number): { action: AnsiAction; endIndex: number } | null {
  let i = start;
  let params = '';

  // パラメータを収集（数字とセミコロン）
  while (i < text.length && /[0-9;]/.test(text[i])) {
    params += text[i];
    i++;
  }

  if (i >= text.length) return null;

  const command = text[i];
  i++;

  // パラメータを数値配列に変換
  const numbers = params ? params.split(';').map(n => parseInt(n, 10) || 0) : [];

  switch (command) {
    case 'm': // SGR - Select Graphic Rendition
      return {
        action: { type: 'sgr', codes: numbers.length ? numbers : [0] },
        endIndex: i,
      };

    case 'A': // CUU - Cursor Up
      return {
        action: { type: 'cuu', n: numbers[0] || 1 },
        endIndex: i,
      };

    case 'B': // CUD - Cursor Down
      return {
        action: { type: 'cud', n: numbers[0] || 1 },
        endIndex: i,
      };

    case 'C': // CUF - Cursor Forward
      return {
        action: { type: 'cuf', n: numbers[0] || 1 },
        endIndex: i,
      };

    case 'D': // CUB - Cursor Back
      return {
        action: { type: 'cub', n: numbers[0] || 1 },
        endIndex: i,
      };

    case 'H': // CUP - Cursor Position
    case 'f': // HVP - Horizontal Vertical Position (同じ)
      return {
        action: {
          type: 'cup',
          row: (numbers[0] || 1) - 1,  // 1-based to 0-based
          col: (numbers[1] || 1) - 1,
        },
        endIndex: i,
      };

    case 'J': // ED - Erase Display
      return {
        action: { type: 'ed', n: numbers[0] || 0 },
        endIndex: i,
      };

    case 'K': // EL - Erase Line
      return {
        action: { type: 'el', n: numbers[0] || 0 },
        endIndex: i,
      };

    default:
      // 未対応のシーケンスは無視
      return null;
  }
}

/**
 * OSC シーケンスをパース
 * ESC ] の後から開始
 */
function parseOSC(text: string, start: number): { action: AnsiAction; endIndex: number } | null {
  // カスタム OSC: ESC ] custom; {...} BEL or ST
  if (text.slice(start, start + 7) === 'custom;') {
    const jsonStart = start + 7;
    const result = extractJson(text, jsonStart);

    if (result) {
      let endIndex = result.endIndex;

      // 終端文字をスキップ
      if (text[endIndex] === BEL) {
        endIndex++;
      } else if (text.slice(endIndex, endIndex + 2) === ST) {
        endIndex += 2;
      }

      try {
        const payload = JSON.parse(result.json);
        return {
          action: { type: 'custom', payload },
          endIndex,
        };
      } catch {
        // JSON パースエラーは無視
        return null;
      }
    }
  }

  // その他の OSC は終端まで読み飛ばす
  let i = start;
  while (i < text.length) {
    if (text[i] === BEL) {
      return null;
    }
    if (text.slice(i, i + 2) === ST) {
      return null;
    }
    i++;
  }

  return null;
}

/**
 * バランスの取れた JSON を抽出
 */
function extractJson(text: string, startIndex: number): { json: string; endIndex: number } | null {
  if (text[startIndex] !== '{') return null;

  let depth = 0;
  let inString = false;
  let escape = false;

  for (let i = startIndex; i < text.length; i++) {
    const char = text[i];

    if (escape) {
      escape = false;
      continue;
    }

    if (char === '\\' && inString) {
      escape = true;
      continue;
    }

    if (char === '"') {
      inString = !inString;
      continue;
    }

    if (inString) continue;

    if (char === '{') depth++;
    else if (char === '}') {
      depth--;
      if (depth === 0) {
        return { json: text.slice(startIndex, i + 1), endIndex: i + 1 };
      }
    }
  }

  return null;
}
