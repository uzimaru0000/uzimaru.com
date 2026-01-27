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

        loop {
            // 先頭の改行をスキップ
            while self.check(&Token::Newline) {
                self.advance();
            }

            // 空入力の場合
            if self.is_at_end() {
                break;
            }

            // 文をパース
            let stmt = self.parse_statement()?;
            result.statements.push(stmt);

            // 改行またはセミコロンをスキップ
            while self.check(&Token::Newline) || self.check(&Token::Semicolon) {
                self.advance();
            }
        }

        result.substitutions = std::mem::take(&mut self.substitutions);

        Ok(result)
    }

    /// 文をパース
    fn parse_statement(&mut self) -> Result<Statement, ParseError> {
        match self.peek() {
            Some(Token::If) => self.parse_if_statement(),
            Some(Token::For) => self.parse_for_statement(),
            _ => {
                // 通常のコマンド列
                let elements = self.parse_conditional_elements()?;
                Ok(Statement::Command(elements))
            }
        }
    }

    /// 条件付き要素列をパース（&& や || でつながったコマンド）
    fn parse_conditional_elements(&mut self) -> Result<Vec<ConditionalElement>, ParseError> {
        let mut elements = Vec::new();
        let mut connector = Connector::None;

        loop {
            let pipeline = self.parse_pipeline()?;

            // 空のパイプラインはスキップ
            if pipeline.commands.is_empty() || pipeline.commands.iter().all(|c| c.is_empty()) {
                break;
            }

            elements.push(ConditionalElement {
                connector,
                pipeline,
            });

            // 接続子をチェック
            if self.check(&Token::And) {
                self.advance();
                connector = Connector::And;
            } else if self.check(&Token::Or) {
                self.advance();
                connector = Connector::Or;
            } else {
                break;
            }
        }

        Ok(elements)
    }

    /// if 文をパース
    fn parse_if_statement(&mut self) -> Result<Statement, ParseError> {
        // if キーワードを消費
        self.advance();

        // 条件をパース（then まで）
        let condition = self.parse_until_keywords(&[Token::Then])?;
        self.expect_keyword(Token::Then)?;

        // then ボディをパース（elif, else, fi まで）
        let then_body = self.parse_body_until_keywords(&[Token::Elif, Token::Else, Token::Fi])?;

        // elif ブランチをパース
        let mut elif_branches = Vec::new();
        while self.check(&Token::Elif) {
            self.advance();
            let elif_condition = self.parse_until_keywords(&[Token::Then])?;
            self.expect_keyword(Token::Then)?;
            let elif_body = self.parse_body_until_keywords(&[Token::Elif, Token::Else, Token::Fi])?;
            elif_branches.push(ElifBranch {
                condition: elif_condition,
                body: elif_body,
            });
        }

        // else ブランチをパース
        let else_body = if self.check(&Token::Else) {
            self.advance();
            Some(self.parse_body_until_keywords(&[Token::Fi])?)
        } else {
            None
        };

        // fi キーワードを消費
        self.expect_keyword(Token::Fi)?;

        Ok(Statement::If(IfStatement {
            condition,
            then_body,
            elif_branches,
            else_body,
        }))
    }

    /// for 文をパース
    fn parse_for_statement(&mut self) -> Result<Statement, ParseError> {
        // for キーワードを消費
        self.advance();

        // 変数名を取得
        let variable = match self.peek() {
            Some(Token::Word(s)) => {
                let v = s.clone();
                self.advance();
                v
            }
            _ => {
                return Err(ParseError::new(
                    "Expected variable name after 'for'",
                    self.pos as u32,
                ))
            }
        };

        // in キーワードを期待（省略可能だが、ここでは必須とする）
        self.skip_newlines_and_semicolons();
        if !self.check(&Token::In) {
            return Err(ParseError::new(
                "Expected 'in' after variable name in for loop",
                self.pos as u32,
            ));
        }
        self.advance();

        // 値リストをパース（do まで）
        let mut values = Vec::new();
        loop {
            self.skip_newlines_and_semicolons();
            if self.check(&Token::Do) {
                break;
            }
            if self.is_at_end() {
                return Err(ParseError::new(
                    "Expected 'do' in for loop",
                    self.pos as u32,
                ));
            }
            match self.peek() {
                Some(Token::Word(s)) => {
                    let word = self.parse_word(s.clone())?;
                    values.push(word);
                    self.advance();
                }
                Some(Token::SingleQuoted(s)) => {
                    values.push(ParsedWord::literal(s.clone()));
                    self.advance();
                }
                Some(Token::DoubleQuoted(s)) => {
                    let word = self.parse_word(s.clone())?;
                    values.push(word);
                    self.advance();
                }
                // コマンド置換 $(...)
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
                    values.push(ParsedWord {
                        segments: vec![WordSegment::CommandSubst(id)],
                    });
                }
                Some(Token::Semicolon) | Some(Token::Newline) => {
                    self.advance();
                }
                _ => break,
            }
        }

        // do キーワードを消費
        self.expect_keyword(Token::Do)?;

        // ボディをパース（done まで）
        let body = self.parse_body_until_keywords(&[Token::Done])?;

        // done キーワードを消費
        self.expect_keyword(Token::Done)?;

        Ok(Statement::For(ForStatement {
            variable,
            values,
            body,
        }))
    }

    /// 指定キーワードまで条件付き要素列をパース
    fn parse_until_keywords(&mut self, keywords: &[Token]) -> Result<Vec<ConditionalElement>, ParseError> {
        let mut elements = Vec::new();
        let mut connector = Connector::None;

        loop {
            self.skip_newlines_and_semicolons();

            // キーワードに到達したら終了
            if self.is_keyword_match(keywords) || self.is_at_end() {
                break;
            }

            let pipeline = self.parse_pipeline()?;

            // 空のパイプラインはスキップ
            if pipeline.commands.is_empty() || pipeline.commands.iter().all(|c| c.is_empty()) {
                continue;
            }

            elements.push(ConditionalElement {
                connector,
                pipeline,
            });

            // 接続子をチェック
            if self.check(&Token::And) {
                self.advance();
                connector = Connector::And;
            } else if self.check(&Token::Or) {
                self.advance();
                connector = Connector::Or;
            } else if self.check(&Token::Semicolon) || self.check(&Token::Newline) {
                // セミコロンや改行は条件の終端になりうる
                break;
            } else {
                break;
            }
        }

        Ok(elements)
    }

    /// 指定キーワードまでボディを文字列として収集
    fn parse_body_until_keywords(&mut self, keywords: &[Token]) -> Result<String, ParseError> {
        let mut body_tokens = Vec::new();
        let mut depth = 0;

        loop {
            // キーワードに到達したら終了（ネスト深度が0の場合のみ）
            if depth == 0 && self.is_keyword_match(keywords) {
                break;
            }

            if self.is_at_end() {
                if depth > 0 {
                    return Err(ParseError::new(
                        "Unexpected end of input in control structure",
                        self.pos as u32,
                    ));
                }
                break;
            }

            let tok = self.peek().cloned();
            if let Some(ref t) = tok {
                // ネストを追跡
                match t {
                    Token::If | Token::For => depth += 1,
                    Token::Fi | Token::Done => {
                        if depth > 0 {
                            depth -= 1;
                        } else {
                            // このキーワードは外側のものなので終了
                            break;
                        }
                    }
                    _ => {}
                }
                body_tokens.push(t.clone());
                self.advance();
            } else {
                break;
            }
        }

        // トークンを文字列に変換
        let mut body_str = String::new();
        let mut prev_was_word = false;
        for tok in body_tokens {
            let s = token_to_string(&tok);
            // ワード間にスペースを挿入
            if prev_was_word && matches!(tok, Token::Word(_) | Token::SingleQuoted(_) | Token::DoubleQuoted(_)) {
                body_str.push(' ');
            }
            body_str.push_str(&s);
            prev_was_word = matches!(tok, Token::Word(_) | Token::SingleQuoted(_) | Token::DoubleQuoted(_));
        }

        Ok(body_str)
    }

    /// キーワードを期待して消費
    fn expect_keyword(&mut self, expected: Token) -> Result<(), ParseError> {
        self.skip_newlines_and_semicolons();
        if self.check(&expected) {
            self.advance();
            Ok(())
        } else {
            Err(ParseError::new(
                format!("Expected '{}'", token_to_string(&expected)),
                self.pos as u32,
            ))
        }
    }

    /// 改行とセミコロンをスキップ
    fn skip_newlines_and_semicolons(&mut self) {
        while self.check(&Token::Newline) || self.check(&Token::Semicolon) {
            self.advance();
        }
    }

    /// 現在のトークンが指定キーワードのいずれかにマッチするか
    fn is_keyword_match(&self, keywords: &[Token]) -> bool {
        for keyword in keywords {
            if self.check(keyword) {
                return true;
            }
        }
        false
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
                // 改行またはセミコロンは終了
                Some(Token::Newline) | Some(Token::Semicolon) => break,
                // それ以外（キーワード含む）は終了
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
        Token::Semicolon => ";".to_string(),
        Token::If => "if".to_string(),
        Token::Then => "then".to_string(),
        Token::Elif => "elif".to_string(),
        Token::Else => "else".to_string(),
        Token::Fi => "fi".to_string(),
        Token::For => "for".to_string(),
        Token::In => "in".to_string(),
        Token::Do => "do".to_string(),
        Token::Done => "done".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// ヘルパー: Statement::Command から elements を取得
    fn get_command_elements(stmt: &Statement) -> &Vec<ConditionalElement> {
        match stmt {
            Statement::Command(elements) => elements,
            _ => panic!("Expected Statement::Command"),
        }
    }

    #[test]
    fn test_simple_command() {
        let result = Parser::parse_input("echo hello").unwrap();
        assert_eq!(result.statements.len(), 1);
        let elements = get_command_elements(&result.statements[0]);
        assert_eq!(elements.len(), 1);
        assert_eq!(elements[0].pipeline.commands.len(), 1);
        assert_eq!(elements[0].pipeline.commands[0].args.len(), 2);
    }

    #[test]
    fn test_env_var() {
        let result = Parser::parse_input("echo $HOME").unwrap();
        let elements = get_command_elements(&result.statements[0]);
        let cmd = &elements[0].pipeline.commands[0];
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
        let elements = get_command_elements(&result.statements[0]);
        let cmd = &elements[0].pipeline.commands[0];

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
        assert_eq!(result.statements.len(), 1);
        let elements = get_command_elements(&result.statements[0]);
        assert_eq!(elements.len(), 1);
        assert_eq!(elements[0].pipeline.commands.len(), 2);
    }

    #[test]
    fn test_and_or() {
        let result = Parser::parse_input("cmd1 && cmd2 || cmd3").unwrap();
        assert_eq!(result.statements.len(), 1);
        let elements = get_command_elements(&result.statements[0]);
        assert_eq!(elements.len(), 3);
        assert_eq!(elements[0].connector, Connector::None);
        assert_eq!(elements[1].connector, Connector::And);
        assert_eq!(elements[2].connector, Connector::Or);
    }

    #[test]
    fn test_redirect() {
        let result = Parser::parse_input("echo hello > file").unwrap();
        let elements = get_command_elements(&result.statements[0]);
        let cmd = &elements[0].pipeline.commands[0];
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
        assert_eq!(result.statements.len(), 2);
    }

    #[test]
    fn test_multiline_with_empty_lines() {
        let result = Parser::parse_input("\n\necho hello\n\necho world\n").unwrap();
        assert_eq!(result.statements.len(), 2);
    }

    #[test]
    fn test_if_statement() {
        let result = Parser::parse_input("if ls; then echo ok; fi").unwrap();
        assert_eq!(result.statements.len(), 1);
        match &result.statements[0] {
            Statement::If(if_stmt) => {
                assert!(!if_stmt.condition.is_empty());
                assert!(!if_stmt.then_body.is_empty());
                assert!(if_stmt.elif_branches.is_empty());
                assert!(if_stmt.else_body.is_none());
            }
            _ => panic!("Expected If statement"),
        }
    }

    #[test]
    fn test_if_else_statement() {
        let result = Parser::parse_input("if false; then echo no; else echo yes; fi").unwrap();
        assert_eq!(result.statements.len(), 1);
        match &result.statements[0] {
            Statement::If(if_stmt) => {
                assert!(if_stmt.else_body.is_some());
            }
            _ => panic!("Expected If statement"),
        }
    }

    #[test]
    fn test_for_statement() {
        let result = Parser::parse_input("for i in a b c; do echo $i; done").unwrap();
        assert_eq!(result.statements.len(), 1);
        match &result.statements[0] {
            Statement::For(for_stmt) => {
                assert_eq!(for_stmt.variable, "i");
                assert_eq!(for_stmt.values.len(), 3);
                assert!(!for_stmt.body.is_empty());
                // body の内容を確認
                println!("FOR BODY: '{}'", for_stmt.body);
                assert!(for_stmt.body.contains("echo"));
                assert!(for_stmt.body.contains("$i"));
            }
            _ => panic!("Expected For statement"),
        }
    }

}
