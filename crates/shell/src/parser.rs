//! シェルのパーサー

use crate::ast::*;
use crate::lexer::{tokenize, Token};

/// パーサー
pub struct Parser {
    tokens: Vec<Token>,
    pos: usize,
    substitutions: Vec<CommandSubstitution>,
    next_subst_id: u32,
}

impl Parser {
    pub fn new(tokens: Vec<Token>) -> Self {
        Self {
            tokens,
            pos: 0,
            substitutions: Vec::new(),
            next_subst_id: 0,
        }
    }

    /// 入力文字列をパース
    pub fn parse_input(input: &str) -> Result<ParseResult, ParseError> {
        let tokens = tokenize(input).map_err(|e| ParseError::new(e, 0))?;
        let mut parser = Parser::new(tokens);
        parser.parse()
    }

    /// パース実行
    pub fn parse(&mut self) -> Result<ParseResult, ParseError> {
        let mut result = ParseResult::new();
        let mut connector = Connector::None;

        loop {
            // 先頭の改行をスキップ
            while self.check(&Token::Newline) {
                self.advance();
            }

            // 空入力の場合
            if self.is_at_end() {
                break;
            }

            let pipeline = self.parse_pipeline()?;

            // 空のパイプラインはスキップ
            if pipeline.commands.is_empty() || pipeline.commands.iter().all(|c| c.is_empty()) {
                continue;
            }

            result.elements.push(ConditionalElement {
                connector,
                pipeline,
            });

            // 接続子または改行をチェック
            if self.check(&Token::And) {
                self.advance();
                connector = Connector::And;
            } else if self.check(&Token::Or) {
                self.advance();
                connector = Connector::Or;
            } else if self.check(&Token::Newline) {
                // 改行の場合は次のコマンドへ（接続子なし）
                connector = Connector::None;
                // 改行は次のループでスキップされる
            } else {
                break;
            }
        }

        result.substitutions = std::mem::take(&mut self.substitutions);

        Ok(result)
    }

    /// パイプラインをパース
    fn parse_pipeline(&mut self) -> Result<Pipeline, ParseError> {
        let mut commands = Vec::new();

        loop {
            let cmd = self.parse_simple_command()?;
            commands.push(cmd);

            if self.check(&Token::Pipe) {
                self.advance();
            } else {
                break;
            }
        }

        Ok(Pipeline { commands })
    }

    /// 単純コマンドをパース
    fn parse_simple_command(&mut self) -> Result<SimpleCommand, ParseError> {
        let mut cmd = SimpleCommand::new();

        while !self.is_at_end() {
            match self.peek() {
                // ワード（引数）
                Some(Token::Word(s)) => {
                    let word = self.parse_word(s.clone())?;
                    cmd.args.push(word);
                    self.advance();
                }
                // シングルクォート（展開なし）
                Some(Token::SingleQuoted(s)) => {
                    cmd.args.push(ParsedWord::literal(s.clone()));
                    self.advance();
                }
                // ダブルクォート（展開あり）
                Some(Token::DoubleQuoted(s)) => {
                    let word = self.parse_word(s.clone())?;
                    cmd.args.push(word);
                    self.advance();
                }
                // 出力リダイレクト
                Some(Token::RedirectOut) => {
                    self.advance();
                    let target = self.parse_redirect_target()?;
                    cmd.redirects.push(Redirect {
                        kind: RedirectKind::Stdout,
                        target,
                    });
                }
                // 追記リダイレクト
                Some(Token::RedirectAppend) => {
                    self.advance();
                    let target = self.parse_redirect_target()?;
                    cmd.redirects.push(Redirect {
                        kind: RedirectKind::StdoutAppend,
                        target,
                    });
                }
                // 入力リダイレクト
                Some(Token::RedirectIn) => {
                    self.advance();
                    let target = self.parse_redirect_target()?;
                    cmd.redirects.push(Redirect {
                        kind: RedirectKind::Stdin,
                        target,
                    });
                }
                // コマンド置換開始
                // レキサーは空白でトークンを分割するため、$( は常に新しいワードとして扱う
                Some(Token::SubstStart) => {
                    self.advance();
                    let subst_input = self.parse_command_substitution()?;
                    let id = self.next_subst_id;
                    self.next_subst_id += 1;
                    self.substitutions.push(CommandSubstitution {
                        id,
                        input: subst_input,
                    });

                    // 置換を新しいワードとして追加
                    cmd.args.push(ParsedWord {
                        segments: vec![WordSegment::CommandSubst(id)],
                    });
                }
                // 改行は終了
                Some(Token::Newline) => break,
                // それ以外は終了
                _ => break,
            }
        }

        Ok(cmd)
    }

    /// リダイレクトのターゲットをパース
    fn parse_redirect_target(&mut self) -> Result<ParsedWord, ParseError> {
        match self.peek() {
            Some(Token::Word(s)) => {
                let word = self.parse_word(s.clone())?;
                self.advance();
                Ok(word)
            }
            Some(Token::SingleQuoted(s)) => {
                let word = ParsedWord::literal(s.clone());
                self.advance();
                Ok(word)
            }
            Some(Token::DoubleQuoted(s)) => {
                let word = self.parse_word(s.clone())?;
                self.advance();
                Ok(word)
            }
            _ => Err(ParseError::new(
                "Expected redirect target",
                self.pos as u32,
            )),
        }
    }

    /// ワード内の環境変数参照をパース
    fn parse_word(&mut self, s: String) -> Result<ParsedWord, ParseError> {
        let mut segments = Vec::new();
        let mut chars = s.chars().peekable();
        let mut current_literal = String::new();

        while let Some(c) = chars.next() {
            if c == '$' {
                // リテラルをフラッシュ
                if !current_literal.is_empty() {
                    segments.push(WordSegment::Literal(std::mem::take(&mut current_literal)));
                }

                match chars.peek() {
                    // コマンド置換 $(
                    Some('(') => {
                        chars.next(); // '(' を消費
                        let mut depth = 1;
                        let mut content = String::new();

                        while let Some(c) = chars.next() {
                            match c {
                                '(' => {
                                    depth += 1;
                                    content.push(c);
                                }
                                ')' => {
                                    depth -= 1;
                                    if depth == 0 {
                                        break;
                                    }
                                    content.push(c);
                                }
                                _ => content.push(c),
                            }
                        }

                        let id = self.next_subst_id;
                        self.next_subst_id += 1;
                        self.substitutions.push(CommandSubstitution {
                            id,
                            input: content,
                        });
                        segments.push(WordSegment::CommandSubst(id));
                    }
                    // ${VAR} または ${VAR:-default}
                    Some('{') => {
                        chars.next(); // '{' を消費
                        let mut name = String::new();
                        let mut default = None;

                        // 変数名を取得
                        while let Some(&c) = chars.peek() {
                            if c == '}' || c == ':' {
                                break;
                            }
                            name.push(chars.next().unwrap());
                        }

                        // デフォルト値をチェック
                        if chars.peek() == Some(&':') {
                            chars.next(); // ':' を消費
                            if chars.peek() == Some(&'-') {
                                chars.next(); // '-' を消費
                                let mut def = String::new();
                                while let Some(&c) = chars.peek() {
                                    if c == '}' {
                                        break;
                                    }
                                    def.push(chars.next().unwrap());
                                }
                                default = Some(def);
                            }
                        }

                        // '}' を消費
                        if chars.peek() == Some(&'}') {
                            chars.next();
                        }

                        segments.push(WordSegment::EnvVar(EnvRef { name, default }));
                    }
                    // $VAR
                    Some(c) if c.is_alphanumeric() || *c == '_' => {
                        let mut name = String::new();
                        while let Some(&c) = chars.peek() {
                            if c.is_alphanumeric() || c == '_' {
                                name.push(chars.next().unwrap());
                            } else {
                                break;
                            }
                        }
                        segments.push(WordSegment::EnvVar(EnvRef {
                            name,
                            default: None,
                        }));
                    }
                    // リテラル $
                    _ => {
                        current_literal.push('$');
                    }
                }
            } else {
                current_literal.push(c);
            }
        }

        // 残りのリテラルをフラッシュ
        if !current_literal.is_empty() {
            segments.push(WordSegment::Literal(current_literal));
        }

        // セグメントが空の場合は空文字列を追加
        if segments.is_empty() {
            segments.push(WordSegment::Literal(String::new()));
        }

        Ok(ParsedWord { segments })
    }

    /// コマンド置換の内容をパース
    fn parse_command_substitution(&mut self) -> Result<String, ParseError> {
        let mut content = String::new();
        let mut depth = 1;

        while !self.is_at_end() && depth > 0 {
            match self.peek() {
                Some(Token::SubstStart) => {
                    depth += 1;
                    content.push_str("$(");
                    self.advance();
                }
                Some(Token::ParenClose) => {
                    depth -= 1;
                    if depth > 0 {
                        content.push(')');
                    }
                    self.advance();
                }
                Some(tok) => {
                    content.push_str(&token_to_string(tok));
                    content.push(' ');
                    self.advance();
                }
                None => break,
            }
        }

        Ok(content.trim().to_string())
    }

    // ヘルパーメソッド

    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.pos)
    }

    fn check(&self, expected: &Token) -> bool {
        self.peek().map_or(false, |t| std::mem::discriminant(t) == std::mem::discriminant(expected))
    }

    fn advance(&mut self) -> Option<&Token> {
        if !self.is_at_end() {
            self.pos += 1;
        }
        self.tokens.get(self.pos - 1)
    }

    fn is_at_end(&self) -> bool {
        self.pos >= self.tokens.len()
    }
}

/// トークンを文字列に変換
fn token_to_string(tok: &Token) -> String {
    match tok {
        Token::Word(s) => s.clone(),
        Token::SingleQuoted(s) => format!("'{}'", s),
        Token::DoubleQuoted(s) => format!("\"{}\"", s),
        Token::Pipe => "|".to_string(),
        Token::And => "&&".to_string(),
        Token::Or => "||".to_string(),
        Token::RedirectOut => ">".to_string(),
        Token::RedirectAppend => ">>".to_string(),
        Token::RedirectIn => "<".to_string(),
        Token::SubstStart => "$(".to_string(),
        Token::ParenClose => ")".to_string(),
        Token::Newline => "\n".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_command() {
        let result = Parser::parse_input("echo hello").unwrap();
        assert_eq!(result.elements.len(), 1);
        assert_eq!(result.elements[0].pipeline.commands.len(), 1);
        assert_eq!(result.elements[0].pipeline.commands[0].args.len(), 2);
    }

    #[test]
    fn test_env_var() {
        let result = Parser::parse_input("echo $HOME").unwrap();
        let cmd = &result.elements[0].pipeline.commands[0];
        assert_eq!(cmd.args.len(), 2);

        if let WordSegment::EnvVar(env) = &cmd.args[1].segments[0] {
            assert_eq!(env.name, "HOME");
            assert_eq!(env.default, None);
        } else {
            panic!("Expected EnvVar");
        }
    }

    #[test]
    fn test_env_var_with_default() {
        let result = Parser::parse_input("echo ${FOO:-default}").unwrap();
        let cmd = &result.elements[0].pipeline.commands[0];

        if let WordSegment::EnvVar(env) = &cmd.args[1].segments[0] {
            assert_eq!(env.name, "FOO");
            assert_eq!(env.default, Some("default".to_string()));
        } else {
            panic!("Expected EnvVar");
        }
    }

    #[test]
    fn test_pipeline() {
        let result = Parser::parse_input("ls | cat").unwrap();
        assert_eq!(result.elements.len(), 1);
        assert_eq!(result.elements[0].pipeline.commands.len(), 2);
    }

    #[test]
    fn test_and_or() {
        let result = Parser::parse_input("cmd1 && cmd2 || cmd3").unwrap();
        assert_eq!(result.elements.len(), 3);
        assert_eq!(result.elements[0].connector, Connector::None);
        assert_eq!(result.elements[1].connector, Connector::And);
        assert_eq!(result.elements[2].connector, Connector::Or);
    }

    #[test]
    fn test_redirect() {
        let result = Parser::parse_input("echo hello > file").unwrap();
        let cmd = &result.elements[0].pipeline.commands[0];
        assert_eq!(cmd.redirects.len(), 1);
        assert_eq!(cmd.redirects[0].kind, RedirectKind::Stdout);
    }

    #[test]
    fn test_command_substitution() {
        let result = Parser::parse_input("echo $(ls)").unwrap();
        assert_eq!(result.substitutions.len(), 1);
        assert_eq!(result.substitutions[0].input, "ls");
    }

    #[test]
    fn test_multiline() {
        let result = Parser::parse_input("echo hello\necho world").unwrap();
        assert_eq!(result.elements.len(), 2);
    }

    #[test]
    fn test_multiline_with_empty_lines() {
        let result = Parser::parse_input("\n\necho hello\n\necho world\n").unwrap();
        assert_eq!(result.elements.len(), 2);
    }
}
