import type { CSSProperties } from 'react';
import type { ParsedCustomPayload } from './renderers';

export interface AnsiSpan {
  text: string;
  style: CSSProperties;
}

export type ParsedSegment =
  | { kind: 'text'; spans: AnsiSpan[] }
  | { kind: 'custom'; payload: ParsedCustomPayload }
  | { kind: 'error'; message: string; raw: string };

// ANSI color codes to CSS colors
const COLORS: Record<number, string> = {
  30: '#000000', // black
  31: '#f44747', // red
  32: '#6a9955', // green
  33: '#dcdcaa', // yellow
  34: '#569cd6', // blue
  35: '#c586c0', // magenta
  36: '#4ec9b0', // cyan
  37: '#d4d4d4', // white
  90: '#808080', // bright black (gray)
  91: '#f44747', // bright red
  92: '#6a9955', // bright green
  93: '#dcdcaa', // bright yellow
  94: '#569cd6', // bright blue
  95: '#c586c0', // bright magenta
  96: '#4ec9b0', // bright cyan
  97: '#ffffff', // bright white
};

// 256-color palette to hex
function ansi256ToHex(n: number): string {
  if (n < 16) {
    // Standard colors (0-15)
    const standard = [
      '#000000', '#800000', '#008000', '#808000',
      '#000080', '#800080', '#008080', '#c0c0c0',
      '#808080', '#ff0000', '#00ff00', '#ffff00',
      '#0000ff', '#ff00ff', '#00ffff', '#ffffff',
    ];
    return standard[n] || '#ffffff';
  } else if (n < 232) {
    // 216 colors (16-231): 6x6x6 cube
    const i = n - 16;
    const r = Math.floor(i / 36);
    const g = Math.floor((i % 36) / 6);
    const b = i % 6;
    const toHex = (v: number) => (v === 0 ? 0 : 55 + v * 40).toString(16).padStart(2, '0');
    return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
  } else {
    // Grayscale (232-255): 24 shades
    const gray = 8 + (n - 232) * 10;
    const hex = gray.toString(16).padStart(2, '0');
    return `#${hex}${hex}${hex}`;
  }
}

// カスタムOSCのプレフィックス
const CUSTOM_OSC_PREFIX = '\x1b]custom;';

/**
 * 文字列からバランスのとれたJSONを抽出
 */
export function extractJson(
  text: string,
  startIndex: number
): { json: string; endIndex: number } | null {
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

/**
 * ANSIエスケープシーケンスをパースしてスパンに分割
 */
export function parseAnsi(text: string): AnsiSpan[] {
  const spans: AnsiSpan[] = [];
  const regex = /\x1b\[([0-9;]*)m/g;

  let currentStyle: CSSProperties = {};
  let lastIndex = 0;
  let match;

  while ((match = regex.exec(text)) !== null) {
    // Add text before this escape sequence
    if (match.index > lastIndex) {
      spans.push({
        text: text.slice(lastIndex, match.index),
        style: { ...currentStyle },
      });
    }

    // Parse the escape codes
    const codes = match[1]
      .split(';')
      .map(Number)
      .filter((n) => !isNaN(n));

    for (let i = 0; i < codes.length; i++) {
      const code = codes[i];
      if (code === 0) {
        // Reset
        currentStyle = {};
      } else if (code === 1) {
        // Bold
        currentStyle.fontWeight = 'bold';
      } else if (code === 2) {
        // Dim
        currentStyle.opacity = 0.7;
      } else if (code === 3) {
        // Italic
        currentStyle.fontStyle = 'italic';
      } else if (code === 4) {
        // Underline
        currentStyle.textDecoration = 'underline';
      } else if (code >= 30 && code <= 37) {
        // Foreground color
        currentStyle.color = COLORS[code];
      } else if (code >= 40 && code <= 47) {
        // Background color
        currentStyle.backgroundColor = COLORS[code - 10];
      } else if (code >= 90 && code <= 97) {
        // Bright foreground color
        currentStyle.color = COLORS[code];
      } else if (code >= 100 && code <= 107) {
        // Bright background color
        currentStyle.backgroundColor = COLORS[code - 10];
      } else if (code === 38 && codes[i + 1] === 5) {
        // 256-color foreground: 38;5;N
        currentStyle.color = ansi256ToHex(codes[i + 2]);
        i += 2;
      } else if (code === 48 && codes[i + 1] === 5) {
        // 256-color background: 48;5;N
        currentStyle.backgroundColor = ansi256ToHex(codes[i + 2]);
        i += 2;
      }
    }

    lastIndex = match.index + match[0].length;
  }

  // Add remaining text
  if (lastIndex < text.length) {
    spans.push({
      text: text.slice(lastIndex),
      style: { ...currentStyle },
    });
  }

  return spans;
}

/**
 * テキストからカスタムOSCを分離してセグメントに分割
 */
export function splitCustomOsc(text: string): ParsedSegment[] {
  const segments: ParsedSegment[] = [];
  let lastIndex = 0;
  let searchIndex = 0;

  while (searchIndex < text.length) {
    const prefixIndex = text.indexOf(CUSTOM_OSC_PREFIX, searchIndex);
    if (prefixIndex === -1) break;

    // OSC前のテキスト
    if (prefixIndex > lastIndex) {
      const textBefore = text.slice(lastIndex, prefixIndex);
      const spans = parseAnsi(textBefore);
      if (spans.length > 0) {
        segments.push({ kind: 'text', spans });
      }
    }

    // JSONの開始位置
    const jsonStart = prefixIndex + CUSTOM_OSC_PREFIX.length;
    const result = extractJson(text, jsonStart);

    if (result) {
      // JSONペイロードをパース
      try {
        const payload = JSON.parse(result.json) as ParsedCustomPayload;
        if (payload.type && typeof payload.type === 'string') {
          segments.push({ kind: 'custom', payload });
        } else {
          segments.push({
            kind: 'error',
            message: 'Missing "type" field',
            raw: text.slice(prefixIndex, result.endIndex),
          });
        }
      } catch (e) {
        segments.push({
          kind: 'error',
          message: e instanceof Error ? e.message : 'JSON parse error',
          raw: text.slice(prefixIndex, result.endIndex),
        });
      }

      // 終端文字をスキップ（あれば）
      let endIndex = result.endIndex;
      if (text[endIndex] === '\x07') endIndex++;
      else if (text.slice(endIndex, endIndex + 2) === '\x1b\\') endIndex += 2;
      else if (text[endIndex] === '\n') endIndex++;

      lastIndex = endIndex;
      searchIndex = endIndex;
    } else {
      // JSONが見つからない場合は、プレフィックスをそのまま出力
      searchIndex = jsonStart;
      lastIndex = prefixIndex;
    }
  }

  // 残りのテキスト
  if (lastIndex < text.length) {
    const spans = parseAnsi(text.slice(lastIndex));
    if (spans.length > 0) {
      segments.push({ kind: 'text', spans });
    }
  }

  return segments;
}
