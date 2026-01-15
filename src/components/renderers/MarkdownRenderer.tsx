import { useMemo, ReactNode, Fragment } from 'react';
import Prism from 'prismjs';
import type {
  RendererProps,
  MarkdownEvent,
  MarkdownTag,
  MarkdownProps,
} from './types';

// Import common language support
import 'prismjs/components/prism-javascript';
import 'prismjs/components/prism-typescript';
import 'prismjs/components/prism-jsx';
import 'prismjs/components/prism-tsx';
import 'prismjs/components/prism-css';
import 'prismjs/components/prism-rust';
import 'prismjs/components/prism-bash';
import 'prismjs/components/prism-json';
import 'prismjs/components/prism-markdown';
import 'prismjs/components/prism-python';
import 'prismjs/components/prism-go';
import 'prismjs/components/prism-yaml';
import 'prismjs/components/prism-toml';

// Token colors for syntax highlighting
const tokenColors: Record<string, string> = {
  comment: 'text-term-comment',
  prolog: 'text-term-comment',
  doctype: 'text-term-comment',
  cdata: 'text-term-comment',
  punctuation: 'text-term-text',
  property: 'text-term-number',
  tag: 'text-term-number',
  boolean: 'text-term-number',
  number: 'text-term-number',
  constant: 'text-term-number',
  symbol: 'text-term-number',
  deleted: 'text-term-number',
  selector: 'text-term-string',
  'attr-name': 'text-term-string',
  string: 'text-term-string',
  char: 'text-term-string',
  builtin: 'text-term-string',
  inserted: 'text-term-string',
  operator: 'text-term-text',
  entity: 'text-term-text',
  url: 'text-term-text',
  atrule: 'text-term-keyword',
  'attr-value': 'text-term-keyword',
  keyword: 'text-term-keyword',
  function: 'text-term-function',
  'class-name': 'text-term-function',
};

// Heading class mapping
const headingClasses: Record<number, string> = {
  1: 'text-2xl font-bold text-term-keyword mt-4 mb-2',
  2: 'text-xl font-bold text-term-keyword mt-3.5 mb-1.5',
  3: 'text-lg font-bold text-term-keyword mt-3 mb-1',
  4: 'text-base font-bold text-term-keyword mt-2.5 mb-1',
  5: 'text-sm font-bold text-term-keyword mt-2 mb-1',
  6: 'text-sm font-bold text-term-keyword mt-2 mb-1',
};

// Syntax highlighting with Prism
function highlightCodeToElements(code: string, language?: string): ReactNode[] {
  const aliases: Record<string, string> = {
    js: 'javascript',
    ts: 'typescript',
    sh: 'bash',
    shell: 'bash',
    py: 'python',
    yml: 'yaml',
    rs: 'rust',
  };
  const effectiveLang = aliases[language || ''] || language;

  if (!effectiveLang || !Prism.languages[effectiveLang]) {
    return [code];
  }

  try {
    const tokens = Prism.tokenize(code, Prism.languages[effectiveLang]);
    return tokensToReact(tokens, 0);
  } catch {
    return [code];
  }
}

// Convert Prism tokens to React elements
function tokensToReact(
  tokens: (string | Prism.Token)[],
  keyOffset: number
): ReactNode[] {
  return tokens.map((token, i) => {
    const key = keyOffset + i;
    if (typeof token === 'string') {
      return <Fragment key={key}>{token}</Fragment>;
    }

    const content =
      typeof token.content === 'string'
        ? token.content
        : Array.isArray(token.content)
          ? tokensToReact(token.content, key * 1000)
          : String(token.content);

    const tokenType = Array.isArray(token.type) ? token.type[0] : token.type;
    const colorClass = tokenColors[tokenType] || 'text-term-text';

    return (
      <span key={key} className={colorClass}>
        {content}
      </span>
    );
  });
}

// Convert flat event stream to nested React elements
function eventsToReact(events: MarkdownEvent[]): ReactNode {
  let index = 0;
  let inTableHead = false;

  function processEvents(): ReactNode[] {
    const nodes: ReactNode[] = [];

    while (index < events.length) {
      const event = events[index];

      if (event.type === 'End') {
        index++;
        return nodes;
      }

      if (event.type === 'Start') {
        const startIndex = index;  // Start イベント自身の index をキーとして使う
        const wasInTableHead = inTableHead;
        if (event.tag.type === 'TableHead') {
          inTableHead = true;
        }
        index++;
        const children = processEvents();
        const element = renderTag(event.tag, children, startIndex);
        inTableHead = wasInTableHead;
        nodes.push(element);
      } else {
        nodes.push(renderEvent(event, index));
        index++;
      }
    }

    return nodes;
  }

  function renderTag(
    tag: MarkdownTag,
    children: ReactNode[],
    key: number
  ): ReactNode {
    switch (tag.type) {
      case 'Paragraph':
        return (
          <p key={key} className="my-2 leading-relaxed">
            {children}
          </p>
        );

      case 'Heading': {
        const HeadingTag = `h${tag.level}` as keyof JSX.IntrinsicElements;
        const headingClass = headingClasses[tag.level] || headingClasses[4];
        return (
          <HeadingTag key={key} id={tag.id} className={headingClass}>
            {children}
          </HeadingTag>
        );
      }

      case 'BlockQuote':
        return (
          <blockquote key={key} className="border-l-[3px] border-term-keyword pl-3 my-2 text-term-quote italic">
            {children}
          </blockquote>
        );

      case 'CodeBlock': {
        const codeContent = extractTextContent(children);
        const highlighted = highlightCodeToElements(codeContent, tag.language);
        return (
          <div key={key} className="font-mono bg-term-bg-dark p-3 rounded border border-term-border my-2 overflow-x-auto whitespace-pre leading-normal">
            {tag.language && (
              <div className="text-term-muted mb-2 text-sm">
                {tag.language}
              </div>
            )}
            <code>{highlighted}</code>
          </div>
        );
      }

      case 'List': {
        const isOrdered = tag.start_number !== undefined && tag.start_number !== null;
        const ListTag = isOrdered ? 'ol' : 'ul';
        const listClass = isOrdered ? 'my-2 pl-5 list-decimal' : 'my-2 pl-5 list-disc';
        return (
          <ListTag
            key={key}
            className={listClass}
            start={tag.start_number ?? undefined}
          >
            {children}
          </ListTag>
        );
      }

      case 'Item':
        return (
          <li key={key} className="my-1 text-term-text">
            {children}
          </li>
        );

      case 'Emphasis':
        return (
          <em key={key} className="italic">
            {children}
          </em>
        );

      case 'Strong':
        return (
          <strong key={key} className="font-bold">
            {children}
          </strong>
        );

      case 'Strikethrough':
        return (
          <del key={key} className="line-through">
            {children}
          </del>
        );

      case 'Link':
        return (
          <a
            key={key}
            href={tag.url}
            title={tag.title}
            className="text-term-keyword underline cursor-pointer"
            target="_blank"
            rel="noopener noreferrer"
          >
            {children}
          </a>
        );

      case 'Image': {
        // Parse width/height from URL query params
        let imgUrl = tag.url;
        let width: string | undefined;
        let height: string | undefined;
        try {
          const url = new URL(tag.url, window.location.origin);
          const widthParam = url.searchParams.get('width');
          const heightParam = url.searchParams.get('height');
          if (widthParam) width = `${widthParam}px`;
          if (heightParam) height = `${heightParam}px`;
          url.searchParams.delete('width');
          url.searchParams.delete('height');
          imgUrl = url.pathname + url.search;
        } catch {
          // Invalid URL, use as-is
        }
        return (
          <img
            key={key}
            src={imgUrl}
            alt={extractTextContent(children) || ''}
            title={tag.title}
            className="max-w-full rounded my-2"
            style={width || height ? { width, maxWidth: width, height } : undefined}
          />
        );
      }

      case 'Table': {
        // thead と tbody を分離（pulldown-cmark は TableBody を出力しないため）
        const thead: ReactNode[] = [];
        const tbody: ReactNode[] = [];
        for (const child of children) {
          if (child && typeof child === 'object' && 'type' in child && (child as React.ReactElement).type === 'thead') {
            thead.push(child);
          } else {
            tbody.push(child);
          }
        }
        return (
          <table key={key} className="border-collapse w-full my-2">
            {thead}
            {tbody.length > 0 && <tbody>{tbody}</tbody>}
          </table>
        );
      }

      case 'TableHead':
        // pulldown-cmark は TableHead 内に TableRow を出力しないため、tr で囲む
        return <thead key={key}><tr>{children}</tr></thead>;

      case 'TableRow':
        return <tr key={key}>{children}</tr>;

      case 'TableCell':
        return inTableHead ? (
          <th key={key} className="border border-term-border-light px-2.5 py-1.5 font-bold text-term-keyword">
            {children}
          </th>
        ) : (
          <td key={key} className="border border-term-border-light px-2.5 py-1.5">
            {children}
          </td>
        );

      case 'HtmlBlock':
        return <Fragment key={key}>{children}</Fragment>;

      default:
        return <span key={key}>{children}</span>;
    }
  }

  function renderEvent(event: MarkdownEvent, key: number): ReactNode {
    switch (event.type) {
      case 'Text':
        return <Fragment key={key}>{event.content}</Fragment>;

      case 'Code':
        return (
          <code key={key} className="font-mono bg-term-bg-code px-1.5 py-0.5 rounded text-term-type">
            {event.content}
          </code>
        );

      case 'Html':
      case 'InlineHtml':
        return (
          <span key={key} className="text-term-muted font-mono text-sm">
            {event.content}
          </span>
        );

      case 'SoftBreak':
        return ' ';

      case 'HardBreak':
        return <br key={key} />;

      case 'Rule':
        return <hr key={key} className="border-none border-t border-term-border-light my-4" />;

      case 'TaskListMarker':
        return (
          <input
            key={key}
            type="checkbox"
            checked={event.checked}
            readOnly
            className="mr-2 accent-term-comment"
          />
        );

      case 'FootnoteReference':
        return (
          <sup key={key} className="text-term-keyword">
            [{event.label}]
          </sup>
        );

      default:
        return null;
    }
  }

  // Helper to extract text content from ReactNode children
  function extractTextContent(nodes: ReactNode[]): string {
    return nodes
      .map((node) => {
        if (typeof node === 'string') return node;
        if (typeof node === 'number') return String(node);
        if (node && typeof node === 'object' && 'props' in node) {
          const element = node as { props?: { children?: ReactNode } };
          if (element.props?.children) {
            if (typeof element.props.children === 'string') {
              return element.props.children;
            }
            if (Array.isArray(element.props.children)) {
              return extractTextContent(element.props.children);
            }
          }
        }
        return '';
      })
      .join('');
  }

  return processEvents();
}

export function MarkdownRenderer({ props }: RendererProps<MarkdownProps>) {
  const { events } = props;

  const content = useMemo(() => {
    try {
      return eventsToReact(events);
    } catch (error) {
      console.error('Failed to render markdown:', error);
      return <span className="text-term-error">[Markdown render error]</span>;
    }
  }, [events]);

  return <div className="leading-relaxed text-term-text">{content}</div>;
}

export function isMarkdownProps(props: unknown): props is MarkdownProps {
  return (
    typeof props === 'object' &&
    props !== null &&
    Array.isArray((props as MarkdownProps).events)
  );
}
