/**
 * Shell 関連の型定義
 */

export interface CommandInput {
  args: string[];
  env: Array<[string, string]>;
  cwd: string;
  stdin?: string;
}

export interface CommandOutput {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export interface ShellState {
  cwd: string;
  env: Map<string, string>;
  aliases: Map<string, string>;
}

export interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

/**
 * stdin入力リクエスト
 */
export interface StdinRequest {
  resolve: (input: string) => void;
}

/**
 * コマンド実行状態
 */
export type ExecutionStatus = 'running' | 'waiting-stdin' | 'completed';

export interface ExecutionState {
  status: ExecutionStatus;
  stdinRequest?: StdinRequest;
}
