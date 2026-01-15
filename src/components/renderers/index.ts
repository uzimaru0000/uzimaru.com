export { rendererRegistry, registerRenderer } from './registry';
export type {
  CustomRenderer,
  RendererProps,
  ParsedCustomPayload,
  RendererRegistration,
  MarkdownEvent,
  MarkdownTag,
  MarkdownTagEnd,
  MarkdownProps,
} from './types';

// 組み込みレンダラー
import { ImageRenderer, isImageProps } from './ImageRenderer';
import { MarkdownRenderer, isMarkdownProps } from './MarkdownRenderer';
import { registerRenderer } from './registry';

registerRenderer('image', ImageRenderer, isImageProps);
registerRenderer('markdown', MarkdownRenderer, isMarkdownProps);
