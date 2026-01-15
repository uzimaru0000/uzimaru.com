import type { ReactNode } from 'react';
import type {
  CustomRenderer,
  RendererRegistration,
  ParsedCustomPayload,
} from './types';

/**
 * カスタムレンダラーのレジストリ
 */
class RendererRegistry {
  private renderers = new Map<string, RendererRegistration>();

  /**
   * レンダラーを登録
   */
  register<T>(type: string, registration: RendererRegistration<T>): void {
    if (this.renderers.has(type)) {
      console.warn(`Renderer "${type}" is already registered. Overwriting.`);
    }
    this.renderers.set(type, registration as RendererRegistration);
  }

  /**
   * レンダラーを取得
   */
  get(type: string): RendererRegistration | undefined {
    return this.renderers.get(type);
  }

  /**
   * 登録済みレンダラー一覧
   */
  getRegisteredTypes(): string[] {
    return Array.from(this.renderers.keys());
  }

  /**
   * レンダラーが存在するかチェック
   */
  has(type: string): boolean {
    return this.renderers.has(type);
  }

  /**
   * ペイロードからReact要素を生成
   */
  render(payload: ParsedCustomPayload, key: string | number): ReactNode {
    const registration = this.renderers.get(payload.type);

    if (!registration) {
      // 未登録のレンダラー: フォールバック表示（JSON内容を表示）
      return (
        <span
          key={key}
          style={{
            display: 'inline-block',
            padding: '4px 8px',
            margin: '2px 0',
            backgroundColor: '#2d2d2d',
            border: '1px solid #444',
            borderRadius: '4px',
            fontSize: '0.9em',
          }}
        >
          <span style={{ color: '#569cd6' }}>[{payload.type}]</span>{' '}
          <span style={{ color: '#808080' }}>
            {JSON.stringify(payload.props)}
          </span>
        </span>
      );
    }

    // バリデーションがあれば実行
    if (registration.validate && !registration.validate(payload.props)) {
      return (
        <span key={key} style={{ color: '#f44747' }}>
          [Invalid props for renderer: {payload.type}]
        </span>
      );
    }

    const Component = registration.component;
    return <Component key={key} props={payload.props} id={payload.id} />;
  }
}

// シングルトンインスタンス
export const rendererRegistry = new RendererRegistry();

/**
 * レンダラーを登録する便利関数
 */
export function registerRenderer<T>(
  type: string,
  component: CustomRenderer<T>,
  validate?: (props: unknown) => props is T
): void {
  rendererRegistry.register(type, { component, validate });
}
