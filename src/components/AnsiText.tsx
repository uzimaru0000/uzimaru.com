import { useMemo } from 'react';
import { rendererRegistry } from './renderers';
import { splitCustomOsc } from './ansi-parser';

interface AnsiTextProps {
  text: string;
  baseColor?: string;
}

export function AnsiText({ text, baseColor = '#d4d4d4' }: AnsiTextProps) {
  const segments = useMemo(() => splitCustomOsc(text), [text]);

  return (
    <span className="whitespace-pre-wrap">
      {segments.map((segment, i) => {
        if (segment.kind === 'custom') {
          return rendererRegistry.render(segment.payload, `custom-${i}`);
        }

        if (segment.kind === 'error') {
          return (
            <span
              key={`error-${i}`}
              className="text-term-error bg-red-950 px-1 py-0.5 rounded-sm"
            >
              [Parse error: {segment.message}]
            </span>
          );
        }

        // テキストセグメント - ANSI スタイルは動的なのでインラインスタイルを維持
        return segment.spans.map((span, j) => (
          <span key={`${i}-${j}`} style={{ color: baseColor, ...span.style }}>
            {span.text}
          </span>
        ));
      })}
    </span>
  );
}
