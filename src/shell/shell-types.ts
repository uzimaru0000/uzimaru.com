/**
 * シェルパーサーの型定義
 * WIT インターフェースに対応
 */

/** 環境変数参照 */
export interface EnvRef {
  name: string;
  defaultValue: string | null;
}

/** ワードセグメント */
export type WordSegment =
  | { tag: 'literal'; val: string }
  | { tag: 'env-var'; val: EnvRef }
  | { tag: 'command-subst'; val: number };

/** パース済みワード */
export interface ParsedWord {
  segments: WordSegment[];
}

/** リダイレクト種別 */
export type RedirectKind = 'stdin' | 'stdout' | 'stdout-append';

/** リダイレクト */
export interface Redirect {
  kind: RedirectKind;
  target: ParsedWord;
}

/** 単純コマンド */
export interface SimpleCommand {
  args: ParsedWord[];
  redirects: Redirect[];
}

/** パイプライン */
export interface Pipeline {
  commands: SimpleCommand[];
}

/** 条件接続子 */
export type Connector = 'none' | 'and' | 'or';

/** 条件要素 */
export interface ConditionalElement {
  connector: Connector;
  pipeline: Pipeline;
}

/** コマンド置換 */
export interface CommandSubstitution {
  id: number;
  input: string;
}

/** elif ブランチ */
export interface ElifBranch {
  condition: ConditionalElement[];
  body: string;
}

/** if 文 */
export interface IfStatement {
  condition: ConditionalElement[];
  thenBody: string;
  elifBranches: ElifBranch[];
  elseBody: string | null;
}

/** for 文 */
export interface ForStatement {
  variable: string;
  values: ParsedWord[];
  body: string;
}

/** 文（ステートメント） */
export type Statement =
  | { tag: 'command'; val: ConditionalElement[] }
  | { tag: 'if-stmt'; val: IfStatement }
  | { tag: 'for-stmt'; val: ForStatement };

/** パース結果 */
export interface ParseResult {
  statements: Statement[];
  substitutions: CommandSubstitution[];
}

/** パースエラー */
export interface ParseError {
  message: string;
  position: number;
}

/** シェルパーサーモジュールのインターフェース */
export interface ShellParserModule {
  parser: {
    parse(input: string): { tag: 'ok'; val: ParseResult } | { tag: 'err'; val: ParseError };
  };
  expander: {
    expandWord(word: ParsedWord, env: [string, string][]): string;
  };
}
