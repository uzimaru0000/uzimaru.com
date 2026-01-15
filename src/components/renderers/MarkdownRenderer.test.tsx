import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MarkdownRenderer, isMarkdownProps } from './MarkdownRenderer';
import type { MarkdownEvent, MarkdownProps } from './types';

// ヘルパー: 簡単なMarkdownイベント列を作成
function createEvents(...events: MarkdownEvent[]): MarkdownProps {
  return { events };
}

// ヘルパー: パラグラフを作成
function paragraph(...texts: string[]): MarkdownEvent[] {
  return [
    { type: 'Start', tag: { type: 'Paragraph' } },
    ...texts.map((t) => ({ type: 'Text' as const, content: t })),
    { type: 'End', tag: { type: 'Paragraph' } },
  ];
}

// ヘルパー: 見出しを作成
function heading(level: number, text: string, id?: string): MarkdownEvent[] {
  return [
    { type: 'Start', tag: { type: 'Heading', level, id } },
    { type: 'Text', content: text },
    { type: 'End', tag: { type: 'Heading', level } },
  ];
}

describe('MarkdownRenderer', () => {
  describe('isMarkdownProps', () => {
    it('正しいpropsをtrueと判定する', () => {
      expect(isMarkdownProps({ events: [] })).toBe(true);
      expect(isMarkdownProps({ events: [{ type: 'Text', content: 'hi' }] })).toBe(true);
    });

    it('不正なpropsをfalseと判定する', () => {
      expect(isMarkdownProps(null)).toBe(false);
      expect(isMarkdownProps(undefined)).toBe(false);
      expect(isMarkdownProps({})).toBe(false);
      expect(isMarkdownProps({ events: 'not array' })).toBe(false);
    });
  });

  describe('テキストレンダリング', () => {
    it('単純なテキストをレンダリングできる', () => {
      const props = createEvents(...paragraph('Hello World'));
      render(<MarkdownRenderer props={props} />);
      expect(screen.getByText('Hello World')).toBeInTheDocument();
    });

    it('複数のテキストノードを連結する', () => {
      const props = createEvents(...paragraph('Hello', ' ', 'World'));
      const { container } = render(<MarkdownRenderer props={props} />);
      expect(container.textContent).toContain('Hello');
      expect(container.textContent).toContain('World');
    });
  });

  describe('見出し', () => {
    it('H1をレンダリングできる', () => {
      const props = createEvents(...heading(1, 'Title'));
      render(<MarkdownRenderer props={props} />);
      const h1 = screen.getByRole('heading', { level: 1 });
      expect(h1).toHaveTextContent('Title');
    });

    it('H2をレンダリングできる', () => {
      const props = createEvents(...heading(2, 'Subtitle'));
      render(<MarkdownRenderer props={props} />);
      const h2 = screen.getByRole('heading', { level: 2 });
      expect(h2).toHaveTextContent('Subtitle');
    });

    it('idを持つ見出しをレンダリングできる', () => {
      const props = createEvents(...heading(1, 'Title', 'my-title'));
      render(<MarkdownRenderer props={props} />);
      const h1 = screen.getByRole('heading', { level: 1 });
      expect(h1).toHaveAttribute('id', 'my-title');
    });
  });

  describe('インラインスタイル', () => {
    it('強調をレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'Paragraph' } },
        { type: 'Start', tag: { type: 'Emphasis' } },
        { type: 'Text', content: 'emphasized' },
        { type: 'End', tag: { type: 'Emphasis' } },
        { type: 'End', tag: { type: 'Paragraph' } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      const em = screen.getByText('emphasized');
      expect(em.tagName).toBe('EM');
    });

    it('太字をレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'Paragraph' } },
        { type: 'Start', tag: { type: 'Strong' } },
        { type: 'Text', content: 'bold' },
        { type: 'End', tag: { type: 'Strong' } },
        { type: 'End', tag: { type: 'Paragraph' } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      const strong = screen.getByText('bold');
      expect(strong.tagName).toBe('STRONG');
    });

    it('インラインコードをレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'Paragraph' } },
        { type: 'Code', content: 'console.log()' },
        { type: 'End', tag: { type: 'Paragraph' } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      const code = screen.getByText('console.log()');
      expect(code.tagName).toBe('CODE');
    });
  });

  describe('リンク', () => {
    it('リンクをレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'Paragraph' } },
        { type: 'Start', tag: { type: 'Link', url: 'https://example.com', title: 'Example' } },
        { type: 'Text', content: 'Click here' },
        { type: 'End', tag: { type: 'Link' } },
        { type: 'End', tag: { type: 'Paragraph' } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      const link = screen.getByRole('link', { name: 'Click here' });
      expect(link).toHaveAttribute('href', 'https://example.com');
      expect(link).toHaveAttribute('title', 'Example');
      expect(link).toHaveAttribute('target', '_blank');
    });
  });

  describe('リスト', () => {
    it('順序なしリストをレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'List' } },
        { type: 'Start', tag: { type: 'Item' } },
        { type: 'Text', content: 'Item 1' },
        { type: 'End', tag: { type: 'Item' } },
        { type: 'Start', tag: { type: 'Item' } },
        { type: 'Text', content: 'Item 2' },
        { type: 'End', tag: { type: 'Item' } },
        { type: 'End', tag: { type: 'List', ordered: false } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      const list = screen.getByRole('list');
      expect(list.tagName).toBe('UL');
      const items = screen.getAllByRole('listitem');
      expect(items).toHaveLength(2);
    });

    it('順序付きリストをレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'List', start_number: 1 } },
        { type: 'Start', tag: { type: 'Item' } },
        { type: 'Text', content: 'First' },
        { type: 'End', tag: { type: 'Item' } },
        { type: 'End', tag: { type: 'List', ordered: true } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      const list = screen.getByRole('list');
      expect(list.tagName).toBe('OL');
    });
  });

  describe('コードブロック', () => {
    it('言語指定なしのコードブロックをレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'CodeBlock' } },
        { type: 'Text', content: 'const x = 1;' },
        { type: 'End', tag: { type: 'CodeBlock' } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      expect(screen.getByText('const x = 1;')).toBeInTheDocument();
    });

    it('言語指定ありのコードブロックをレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'CodeBlock', language: 'javascript' } },
        { type: 'Text', content: 'const x = 1;' },
        { type: 'End', tag: { type: 'CodeBlock' } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      expect(screen.getByText('javascript')).toBeInTheDocument();
    });
  });

  describe('ブロッククォート', () => {
    it('引用をレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'BlockQuote' } },
        { type: 'Start', tag: { type: 'Paragraph' } },
        { type: 'Text', content: 'Quote text' },
        { type: 'End', tag: { type: 'Paragraph' } },
        { type: 'End', tag: { type: 'BlockQuote' } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      const blockquote = screen.getByText('Quote text').closest('blockquote');
      expect(blockquote).toBeInTheDocument();
    });
  });

  describe('特殊要素', () => {
    it('水平線をレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        ...paragraph('Before'),
        { type: 'Rule' },
        ...paragraph('After'),
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      expect(screen.getByRole('separator')).toBeInTheDocument();
    });

    it('ハードブレイクをレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'Paragraph' } },
        { type: 'Text', content: 'Line 1' },
        { type: 'HardBreak' },
        { type: 'Text', content: 'Line 2' },
        { type: 'End', tag: { type: 'Paragraph' } },
      ];
      const props = createEvents(...events);
      const { container } = render(<MarkdownRenderer props={props} />);
      expect(container.querySelector('br')).toBeInTheDocument();
    });

    it('タスクリストマーカーをレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        { type: 'Start', tag: { type: 'List' } },
        { type: 'Start', tag: { type: 'Item' } },
        { type: 'TaskListMarker', checked: true },
        { type: 'Text', content: 'Done task' },
        { type: 'End', tag: { type: 'Item' } },
        { type: 'Start', tag: { type: 'Item' } },
        { type: 'TaskListMarker', checked: false },
        { type: 'Text', content: 'Todo task' },
        { type: 'End', tag: { type: 'Item' } },
        { type: 'End', tag: { type: 'List', ordered: false } },
      ];
      const props = createEvents(...events);
      render(<MarkdownRenderer props={props} />);
      const checkboxes = screen.getAllByRole('checkbox');
      expect(checkboxes).toHaveLength(2);
      expect(checkboxes[0]).toBeChecked();
      expect(checkboxes[1]).not.toBeChecked();
    });
  });

  describe('エラーハンドリング', () => {
    it('空のeventsでもクラッシュしない', () => {
      const props = createEvents();
      expect(() => render(<MarkdownRenderer props={props} />)).not.toThrow();
    });
  });

  describe('whoami.md形式', () => {
    // whoami.mdの内容:
    // # whoami
    //
    // - **Name**: Shuji Oba (uzimaru)
    // - **Hobby**: Cooking, Programming
    // - **Likes**: WebFrontend, Elm, Rust
    it('見出しと太字を含むリストをレンダリングできる', () => {
      const events: MarkdownEvent[] = [
        // # whoami
        { type: 'Start', tag: { type: 'Heading', level: 1 } },
        { type: 'Text', content: 'whoami' },
        { type: 'End', tag: { type: 'Heading', level: 1 } },
        // リスト開始
        { type: 'Start', tag: { type: 'List' } },
        // - **Name**: Shuji Oba (uzimaru)
        { type: 'Start', tag: { type: 'Item' } },
        { type: 'Start', tag: { type: 'Paragraph' } },
        { type: 'Start', tag: { type: 'Strong' } },
        { type: 'Text', content: 'Name' },
        { type: 'End', tag: { type: 'Strong' } },
        { type: 'Text', content: ': Shuji Oba (uzimaru)' },
        { type: 'End', tag: { type: 'Paragraph' } },
        { type: 'End', tag: { type: 'Item' } },
        // - **Hobby**: Cooking, Programming
        { type: 'Start', tag: { type: 'Item' } },
        { type: 'Start', tag: { type: 'Paragraph' } },
        { type: 'Start', tag: { type: 'Strong' } },
        { type: 'Text', content: 'Hobby' },
        { type: 'End', tag: { type: 'Strong' } },
        { type: 'Text', content: ': Cooking, Programming' },
        { type: 'End', tag: { type: 'Paragraph' } },
        { type: 'End', tag: { type: 'Item' } },
        // - **Likes**: WebFrontend, Elm, Rust
        { type: 'Start', tag: { type: 'Item' } },
        { type: 'Start', tag: { type: 'Paragraph' } },
        { type: 'Start', tag: { type: 'Strong' } },
        { type: 'Text', content: 'Likes' },
        { type: 'End', tag: { type: 'Strong' } },
        { type: 'Text', content: ': WebFrontend, Elm, Rust' },
        { type: 'End', tag: { type: 'Paragraph' } },
        { type: 'End', tag: { type: 'Item' } },
        // リスト終了
        { type: 'End', tag: { type: 'List', ordered: false } },
      ];
      const props = createEvents(...events);
      const { container } = render(<MarkdownRenderer props={props} />);

      // 見出しの確認
      const h1 = screen.getByRole('heading', { level: 1 });
      expect(h1).toHaveTextContent('whoami');

      // リストの確認
      const list = screen.getByRole('list');
      expect(list.tagName).toBe('UL');

      // リストアイテムの確認
      const items = screen.getAllByRole('listitem');
      expect(items).toHaveLength(3);

      // 太字テキストの確認
      const strongElements = container.querySelectorAll('strong');
      expect(strongElements).toHaveLength(3);
      expect(strongElements[0]).toHaveTextContent('Name');
      expect(strongElements[1]).toHaveTextContent('Hobby');
      expect(strongElements[2]).toHaveTextContent('Likes');

      // 全体のテキスト内容確認
      expect(container.textContent).toContain('Shuji Oba (uzimaru)');
      expect(container.textContent).toContain('Cooking, Programming');
      expect(container.textContent).toContain('WebFrontend, Elm, Rust');
    });
  });
});
