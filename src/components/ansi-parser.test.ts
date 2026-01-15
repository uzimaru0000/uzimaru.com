import { describe, it, expect } from 'vitest';
import { extractJson, parseAnsi, splitCustomOsc } from './ansi-parser';

describe('extractJson', () => {
  it('空文字列からはnullを返す', () => {
    expect(extractJson('', 0)).toBeNull();
  });

  it('JSONでない文字列からはnullを返す', () => {
    expect(extractJson('hello', 0)).toBeNull();
  });

  it('単純なJSONオブジェクトを抽出できる', () => {
    const text = '{"type":"test"}';
    const result = extractJson(text, 0);
    expect(result).toEqual({ json: '{"type":"test"}', endIndex: 15 });
  });

  it('ネストしたJSONオブジェクトを抽出できる', () => {
    const text = '{"type":"test","props":{"name":"value"}}';
    const result = extractJson(text, 0);
    expect(result).toEqual({
      json: '{"type":"test","props":{"name":"value"}}',
      endIndex: 40,
    });
  });

  it('JSON内の文字列に含まれる括弧を無視する', () => {
    const text = '{"content":"{}test{}"}';
    const result = extractJson(text, 0);
    expect(result).toEqual({
      json: '{"content":"{}test{}"}',
      endIndex: 22,
    });
  });

  it('JSON内のエスケープされた引用符を処理できる', () => {
    const text = '{"content":"say \\"hello\\""}';
    const result = extractJson(text, 0);
    expect(result).toEqual({
      json: '{"content":"say \\"hello\\""}',
      endIndex: 27,
    });
  });

  it('テキストの途中からJSONを抽出できる', () => {
    const text = 'prefix{"type":"test"}suffix';
    const result = extractJson(text, 6);
    expect(result).toEqual({
      json: '{"type":"test"}',
      endIndex: 21,
    });
  });

  it('閉じ括弧がない不完全なJSONからはnullを返す', () => {
    const text = '{"type":"test"';
    expect(extractJson(text, 0)).toBeNull();
  });

  it('複雑なネストを持つJSONを抽出できる', () => {
    const text = '{"a":{"b":{"c":{"d":"value"}}}}';
    const result = extractJson(text, 0);
    expect(result).toEqual({
      json: '{"a":{"b":{"c":{"d":"value"}}}}',
      endIndex: 31,
    });
  });
});

describe('parseAnsi', () => {
  it('プレーンテキストをそのまま返す', () => {
    const result = parseAnsi('hello world');
    expect(result).toEqual([{ text: 'hello world', style: {} }]);
  });

  it('赤色のANSIコードをパースできる', () => {
    const result = parseAnsi('\x1b[31mred text\x1b[0m');
    expect(result).toEqual([
      { text: 'red text', style: { color: '#f44747' } },
    ]);
  });

  it('太字のANSIコードをパースできる', () => {
    const result = parseAnsi('\x1b[1mbold\x1b[0m');
    expect(result).toEqual([{ text: 'bold', style: { fontWeight: 'bold' } }]);
  });

  it('複数のスタイルを組み合わせられる', () => {
    const result = parseAnsi('\x1b[1;31mbold red\x1b[0m');
    expect(result).toEqual([
      { text: 'bold red', style: { fontWeight: 'bold', color: '#f44747' } },
    ]);
  });

  it('リセットでスタイルがクリアされる', () => {
    const result = parseAnsi('\x1b[31mred\x1b[0m plain');
    expect(result).toHaveLength(2);
    expect(result[0]).toEqual({ text: 'red', style: { color: '#f44747' } });
    expect(result[1]).toEqual({ text: ' plain', style: {} });
  });

  it('イタリックをパースできる', () => {
    const result = parseAnsi('\x1b[3mitalic\x1b[0m');
    expect(result).toEqual([{ text: 'italic', style: { fontStyle: 'italic' } }]);
  });

  it('下線をパースできる', () => {
    const result = parseAnsi('\x1b[4munderline\x1b[0m');
    expect(result).toEqual([
      { text: 'underline', style: { textDecoration: 'underline' } },
    ]);
  });

  it('明るい色をパースできる', () => {
    const result = parseAnsi('\x1b[97mbright white\x1b[0m');
    expect(result).toEqual([
      { text: 'bright white', style: { color: '#ffffff' } },
    ]);
  });

  it('エスケープシーケンスがない場合は空配列を返さない', () => {
    const result = parseAnsi('');
    expect(result).toEqual([]);
  });
});

describe('splitCustomOsc', () => {
  it('プレーンテキストをテキストセグメントとして返す', () => {
    const result = splitCustomOsc('hello world');
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('text');
    if (result[0].kind === 'text') {
      expect(result[0].spans).toEqual([{ text: 'hello world', style: {} }]);
    }
  });

  it('カスタムOSCをパースできる', () => {
    const text = '\x1b]custom;{"type":"test","props":{}}\x07';
    const result = splitCustomOsc(text);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('custom');
    if (result[0].kind === 'custom') {
      expect(result[0].payload.type).toBe('test');
    }
  });

  it('ESC \\ 終端のOSCをパースできる', () => {
    const text = '\x1b]custom;{"type":"test","props":{}}\x1b\\';
    const result = splitCustomOsc(text);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('custom');
  });

  it('改行終端のOSCをパースできる', () => {
    const text = '\x1b]custom;{"type":"test","props":{}}\n';
    const result = splitCustomOsc(text);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('custom');
  });

  it('テキストとOSCが混在する場合を処理できる', () => {
    const text = 'before\x1b]custom;{"type":"test","props":{}}\x07after';
    const result = splitCustomOsc(text);
    expect(result).toHaveLength(3);
    expect(result[0].kind).toBe('text');
    expect(result[1].kind).toBe('custom');
    expect(result[2].kind).toBe('text');
  });

  it('typeフィールドがないJSONはエラーになる', () => {
    const text = '\x1b]custom;{"props":{}}\x07';
    const result = splitCustomOsc(text);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('error');
  });

  it('不正なJSONはエラーになる', () => {
    const text = '\x1b]custom;{invalid json}\x07';
    const result = splitCustomOsc(text);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('error');
  });

  it('複雑なpropsを持つOSCをパースできる', () => {
    const payload = {
      type: 'markdown',
      props: {
        events: [
          { type: 'Start', tag: { type: 'Paragraph' } },
          { type: 'Text', content: 'Hello' },
          { type: 'End', tag: { type: 'Paragraph' } },
        ],
      },
    };
    const text = `\x1b]custom;${JSON.stringify(payload)}\x07`;
    const result = splitCustomOsc(text);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('custom');
    if (result[0].kind === 'custom') {
      expect(result[0].payload.type).toBe('markdown');
      expect(result[0].payload.props.events).toHaveLength(3);
    }
  });

  it('ANSIコードを含むテキストセグメントを正しく処理する', () => {
    const text = '\x1b[31mred\x1b[0m\x1b]custom;{"type":"test","props":{}}\x07';
    const result = splitCustomOsc(text);
    expect(result).toHaveLength(2);
    expect(result[0].kind).toBe('text');
    if (result[0].kind === 'text') {
      expect(result[0].spans[0].style.color).toBe('#f44747');
    }
    expect(result[1].kind).toBe('custom');
  });

  it('日本語を含むペイロードをパースできる', () => {
    const payload = {
      type: 'test',
      props: { message: 'こんにちは世界' },
    };
    const text = `\x1b]custom;${JSON.stringify(payload)}\x07`;
    const result = splitCustomOsc(text);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('custom');
    if (result[0].kind === 'custom') {
      expect(result[0].payload.props.message).toBe('こんにちは世界');
    }
  });

  it('whoami.md形式のmarkdownペイロードをパースできる', () => {
    // whoami.mdの実際の構造を再現
    const payload = {
      type: 'markdown',
      props: {
        events: [
          { type: 'Start', tag: { type: 'Heading', level: 1, id: null } },
          { type: 'Text', content: 'whoami' },
          { type: 'End', tag: { type: 'Heading', level: 1 } },
          { type: 'Start', tag: { type: 'List', start_number: null } },
          { type: 'Start', tag: { type: 'Item' } },
          { type: 'Start', tag: { type: 'Paragraph' } },
          { type: 'Start', tag: { type: 'Strong' } },
          { type: 'Text', content: 'Name' },
          { type: 'End', tag: { type: 'Strong' } },
          { type: 'Text', content: ': Shuji Oba (uzimaru)' },
          { type: 'End', tag: { type: 'Paragraph' } },
          { type: 'End', tag: { type: 'Item' } },
          { type: 'Start', tag: { type: 'Item' } },
          { type: 'Start', tag: { type: 'Paragraph' } },
          { type: 'Start', tag: { type: 'Strong' } },
          { type: 'Text', content: 'Hobby' },
          { type: 'End', tag: { type: 'Strong' } },
          { type: 'Text', content: ': Cooking, Programming' },
          { type: 'End', tag: { type: 'Paragraph' } },
          { type: 'End', tag: { type: 'Item' } },
          { type: 'Start', tag: { type: 'Item' } },
          { type: 'Start', tag: { type: 'Paragraph' } },
          { type: 'Start', tag: { type: 'Strong' } },
          { type: 'Text', content: 'Likes' },
          { type: 'End', tag: { type: 'Strong' } },
          { type: 'Text', content: ': WebFrontend, Elm, Rust' },
          { type: 'End', tag: { type: 'Paragraph' } },
          { type: 'End', tag: { type: 'Item' } },
          { type: 'End', tag: { type: 'List', ordered: false } },
        ],
      },
    };
    const jsonStr = JSON.stringify(payload);
    // ESC \ 終端（Rust側で使用）
    const text = `\x1b]custom;${jsonStr}\x1b\\`;
    const result = splitCustomOsc(text);

    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('custom');
    if (result[0].kind === 'custom') {
      expect(result[0].payload.type).toBe('markdown');
      const events = result[0].payload.props.events as unknown[];
      expect(events).toHaveLength(29);

      // 最初のイベントがHeading開始であることを確認
      const firstEvent = events[0] as { type: string; tag: { type: string } };
      expect(firstEvent.type).toBe('Start');
      expect(firstEvent.tag.type).toBe('Heading');
    }
  });

  it('非常に長いJSONペイロードをパースできる', () => {
    // 大きなevents配列を持つペイロード
    const events = [];
    for (let i = 0; i < 100; i++) {
      events.push({ type: 'Text', content: `Item ${i}` });
    }
    const payload = {
      type: 'markdown',
      props: { events },
    };
    const text = `\x1b]custom;${JSON.stringify(payload)}\x1b\\`;
    const result = splitCustomOsc(text);

    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('custom');
    if (result[0].kind === 'custom') {
      expect(result[0].payload.props.events).toHaveLength(100);
    }
  });
});
