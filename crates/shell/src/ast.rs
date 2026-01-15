//! シェルの抽象構文木（AST）型定義

/// 環境変数参照
#[derive(Debug, Clone, PartialEq)]
pub struct EnvRef {
    pub name: String,
    pub default: Option<String>,
}

/// ワードセグメント
#[derive(Debug, Clone, PartialEq)]
pub enum WordSegment {
    /// リテラル文字列
    Literal(String),
    /// 環境変数参照 ($VAR, ${VAR}, ${VAR:-default})
    EnvVar(EnvRef),
    /// コマンド置換 $()
    CommandSubst(u32),
}

/// パース済みワード
#[derive(Debug, Clone, PartialEq)]
pub struct ParsedWord {
    pub segments: Vec<WordSegment>,
}

impl ParsedWord {
    /// リテラル文字列からワードを作成
    pub fn literal(s: impl Into<String>) -> Self {
        Self {
            segments: vec![WordSegment::Literal(s.into())],
        }
    }

    /// 空のワードかどうか
    pub fn is_empty(&self) -> bool {
        self.segments.is_empty()
            || (self.segments.len() == 1
                && matches!(&self.segments[0], WordSegment::Literal(s) if s.is_empty()))
    }
}

/// リダイレクト種別
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum RedirectKind {
    /// 標準入力 (<)
    Stdin,
    /// 標準出力 (>)
    Stdout,
    /// 標準出力追記 (>>)
    StdoutAppend,
}

/// リダイレクト
#[derive(Debug, Clone, PartialEq)]
pub struct Redirect {
    pub kind: RedirectKind,
    pub target: ParsedWord,
}

/// 単純コマンド（パイプや条件なし）
#[derive(Debug, Clone, PartialEq)]
pub struct SimpleCommand {
    pub args: Vec<ParsedWord>,
    pub redirects: Vec<Redirect>,
}

impl SimpleCommand {
    pub fn new() -> Self {
        Self {
            args: Vec::new(),
            redirects: Vec::new(),
        }
    }

    pub fn is_empty(&self) -> bool {
        self.args.is_empty()
    }
}

impl Default for SimpleCommand {
    fn default() -> Self {
        Self::new()
    }
}

/// パイプライン（パイプで接続されたコマンド群）
#[derive(Debug, Clone, PartialEq)]
pub struct Pipeline {
    pub commands: Vec<SimpleCommand>,
}

impl Pipeline {
    pub fn new() -> Self {
        Self {
            commands: Vec::new(),
        }
    }

    pub fn single(cmd: SimpleCommand) -> Self {
        Self {
            commands: vec![cmd],
        }
    }
}

impl Default for Pipeline {
    fn default() -> Self {
        Self::new()
    }
}

/// 条件接続子
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Connector {
    /// 最初のコマンド
    None,
    /// && (前のコマンドが成功した場合のみ実行)
    And,
    /// || (前のコマンドが失敗した場合のみ実行)
    Or,
}

/// 条件要素
#[derive(Debug, Clone, PartialEq)]
pub struct ConditionalElement {
    pub connector: Connector,
    pub pipeline: Pipeline,
}

/// コマンド置換
#[derive(Debug, Clone, PartialEq)]
pub struct CommandSubstitution {
    pub id: u32,
    pub input: String,
}

/// パース結果
#[derive(Debug, Clone, PartialEq)]
pub struct ParseResult {
    pub elements: Vec<ConditionalElement>,
    pub substitutions: Vec<CommandSubstitution>,
}

impl ParseResult {
    pub fn new() -> Self {
        Self {
            elements: Vec::new(),
            substitutions: Vec::new(),
        }
    }

    pub fn single(cmd: SimpleCommand) -> Self {
        Self {
            elements: vec![ConditionalElement {
                connector: Connector::None,
                pipeline: Pipeline::single(cmd),
            }],
            substitutions: Vec::new(),
        }
    }
}

impl Default for ParseResult {
    fn default() -> Self {
        Self::new()
    }
}

/// パースエラー
#[derive(Debug, Clone, thiserror::Error)]
#[error("{message} at position {position}")]
pub struct ParseError {
    pub message: String,
    pub position: u32,
}

impl ParseError {
    pub fn new(message: impl Into<String>, position: u32) -> Self {
        Self {
            message: message.into(),
            position,
        }
    }
}
