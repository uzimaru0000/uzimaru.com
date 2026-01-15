import type { FC } from 'react';

/**
 * レンダラーコンポーネントに渡されるprops
 */
export interface RendererProps<T = Record<string, unknown>> {
  props: T;
  id?: string;
}

/**
 * カスタムレンダラーコンポーネントの型
 */
export type CustomRenderer<T = Record<string, unknown>> = FC<RendererProps<T>>;

/**
 * パース済みのカスタムOSCペイロード
 */
export interface ParsedCustomPayload {
  type: string;
  id?: string;
  props: Record<string, unknown>;
}

/**
 * レンダラー登録情報
 */
export interface RendererRegistration<T = Record<string, unknown>> {
  component: CustomRenderer<T>;
  validate?: (props: unknown) => props is T;
}

// Markdown AST Types
export type MarkdownEvent =
  | { type: 'Start'; tag: MarkdownTag }
  | { type: 'End'; tag: MarkdownTagEnd }
  | { type: 'Text'; content: string }
  | { type: 'Code'; content: string }
  | { type: 'Html'; content: string }
  | { type: 'InlineHtml'; content: string }
  | { type: 'SoftBreak' }
  | { type: 'HardBreak' }
  | { type: 'Rule' }
  | { type: 'TaskListMarker'; checked: boolean }
  | { type: 'FootnoteReference'; label: string };

export type MarkdownTag =
  | { type: 'Paragraph' }
  | { type: 'Heading'; level: number; id?: string }
  | { type: 'BlockQuote'; kind?: string }
  | { type: 'CodeBlock'; language?: string }
  | { type: 'List'; start_number?: number }
  | { type: 'Item' }
  | { type: 'Emphasis' }
  | { type: 'Strong' }
  | { type: 'Strikethrough' }
  | { type: 'Link'; url: string; title?: string }
  | { type: 'Image'; url: string; title?: string }
  | { type: 'Table'; alignments: string[] }
  | { type: 'TableHead' }
  | { type: 'TableRow' }
  | { type: 'TableCell' }
  | { type: 'HtmlBlock' };

export type MarkdownTagEnd =
  | { type: 'Paragraph' }
  | { type: 'Heading'; level: number }
  | { type: 'BlockQuote' }
  | { type: 'CodeBlock' }
  | { type: 'List'; ordered: boolean }
  | { type: 'Item' }
  | { type: 'Emphasis' }
  | { type: 'Strong' }
  | { type: 'Strikethrough' }
  | { type: 'Link' }
  | { type: 'Image' }
  | { type: 'Table' }
  | { type: 'TableHead' }
  | { type: 'TableRow' }
  | { type: 'TableCell' }
  | { type: 'HtmlBlock' };

export interface MarkdownProps {
  events: MarkdownEvent[];
}
