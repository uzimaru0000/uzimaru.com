//! シェルのレキサー（トークナイザー）

use nom::{
    branch::alt,
    bytes::complete::{escaped_transform, is_not, tag, take_while, take_while1},
    character::complete::{char, none_of},
    combinator::{map, opt, value, verify},
    sequence::delimited,
    IResult,
};

/// トークン種別
#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    /// 通常のワード
    Word(String),
    /// シングルクォート文字列
    SingleQuoted(String),
    /// ダブルクォート文字列
    DoubleQuoted(String),
    /// パイプ |
    Pipe,
    /// AND &&
    And,
    /// OR ||
    Or,
    /// 出力リダイレクト >
    RedirectOut,
    /// 追記リダイレクト >>
    RedirectAppend,
    /// 入力リダイレクト <
    RedirectIn,
    /// コマンド置換開始 $(
    SubstStart,
    /// 括弧閉じ )
    ParenClose,
    /// 改行
    Newline,
}

/// シェルのメタ文字かどうか
/// $は環境変数のプレフィックスなのでメタ文字から除外
/// $( はコマンド置換として別途処理する
fn is_meta(c: char) -> bool {
    matches!(
        c,
        '|' | '&' | '<' | '>' | '(' | ')' | ';' | '\n' | ' ' | '\t' | '"' | '\''
    )
}

/// 空白をスキップ
pub fn skip_whitespace(input: &str) -> IResult<&str, ()> {
    let (input, _) = take_while(|c| c == ' ' || c == '\t')(input)?;
    Ok((input, ()))
}

/// 通常のワードをパース
fn word(input: &str) -> IResult<&str, Token> {
    let (input, s) = take_while1(|c: char| !is_meta(c))(input)?;
    Ok((input, Token::Word(s.to_string())))
}

/// シングルクォート文字列をパース
fn single_quoted(input: &str) -> IResult<&str, Token> {
    let (input, s) = delimited(
        char('\''),
        map(opt(is_not("'")), |s| s.unwrap_or("").to_string()),
        char('\''),
    )(input)?;
    Ok((input, Token::SingleQuoted(s)))
}

/// ダブルクォート文字列をパース（エスケープ処理あり）
fn double_quoted(input: &str) -> IResult<&str, Token> {
    let (input, _) = char('"')(input)?;

    let mut result = String::new();
    let mut remaining = input;
    let mut closed = false;

    while !remaining.is_empty() {
        if remaining.starts_with('"') {
            remaining = &remaining[1..];
            closed = true;
            break;
        } else if remaining.starts_with('\\') && remaining.len() > 1 {
            let next = remaining.chars().nth(1).unwrap();
            match next {
                '\\' => result.push('\\'),
                '"' => result.push('"'),
                '$' => result.push('$'),
                'n' => result.push('\n'),
                't' => result.push('\t'),
                _ => {
                    result.push('\\');
                    result.push(next);
                }
            }
            remaining = &remaining[2..];
        } else {
            let c = remaining.chars().next().unwrap();
            result.push(c);
            remaining = &remaining[c.len_utf8()..];
        }
    }

    if !closed {
        return Err(nom::Err::Error(nom::error::Error::new(
            input,
            nom::error::ErrorKind::Tag,
        )));
    }

    Ok((remaining, Token::DoubleQuoted(result)))
}

/// 演算子をパース
fn operator(input: &str) -> IResult<&str, Token> {
    alt((
        value(Token::And, tag("&&")),
        value(Token::Or, tag("||")),
        value(Token::RedirectAppend, tag(">>")),
        value(Token::SubstStart, tag("$(")),
        value(Token::Pipe, char('|')),
        value(Token::RedirectOut, char('>')),
        value(Token::RedirectIn, char('<')),
        value(Token::ParenClose, char(')')),
    ))(input)
}

/// 環境変数を含む可能性のあるワードをパース
/// $VAR, ${VAR}, ${VAR:-default} を検出
fn word_with_vars(input: &str) -> IResult<&str, Token> {
    let mut result = String::new();
    let mut remaining = input;

    if remaining.is_empty() || is_meta(remaining.chars().next().unwrap()) {
        return Err(nom::Err::Error(nom::error::Error::new(
            input,
            nom::error::ErrorKind::TakeWhile1,
        )));
    }

    while !remaining.is_empty() {
        // $( の場合はコマンド置換なのでここで止める
        if remaining.starts_with("$(") {
            break;
        }

        let c = remaining.chars().next().unwrap();

        if is_meta(c) {
            break;
        }

        result.push(c);
        remaining = &remaining[c.len_utf8()..];
    }

    if result.is_empty() {
        return Err(nom::Err::Error(nom::error::Error::new(
            input,
            nom::error::ErrorKind::TakeWhile1,
        )));
    }

    Ok((remaining, Token::Word(result)))
}

/// 単一トークンをパース
pub fn token(input: &str) -> IResult<&str, Token> {
    let (input, _) = skip_whitespace(input)?;

    if input.is_empty() {
        return Err(nom::Err::Error(nom::error::Error::new(
            input,
            nom::error::ErrorKind::Eof,
        )));
    }

    alt((operator, single_quoted, double_quoted, word_with_vars))(input)
}

/// 入力文字列をトークン列にパース
pub fn tokenize(input: &str) -> Result<Vec<Token>, String> {
    let mut tokens = Vec::new();
    let mut remaining = input;

    loop {
        // 改行以外の空白をスキップ
        let (rest, _) = skip_whitespace(remaining).map_err(|e| format!("Parse error: {:?}", e))?;
        remaining = rest;

        if remaining.is_empty() {
            break;
        }

        // 改行を検出
        if remaining.starts_with('\n') {
            tokens.push(Token::Newline);
            remaining = &remaining[1..];
            continue;
        }

        match token(remaining) {
            Ok((rest, tok)) => {
                tokens.push(tok);
                remaining = rest;
            }
            Err(e) => {
                return Err(format!("Tokenize error at '{}': {:?}", remaining, e));
            }
        }
    }

    Ok(tokens)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_word() {
        let tokens = tokenize("hello").unwrap();
        assert_eq!(tokens, vec![Token::Word("hello".to_string())]);
    }

    #[test]
    fn test_multiple_words() {
        let tokens = tokenize("hello world").unwrap();
        assert_eq!(
            tokens,
            vec![
                Token::Word("hello".to_string()),
                Token::Word("world".to_string())
            ]
        );
    }

    #[test]
    fn test_single_quoted() {
        let tokens = tokenize("'hello world'").unwrap();
        assert_eq!(tokens, vec![Token::SingleQuoted("hello world".to_string())]);
    }

    #[test]
    fn test_double_quoted() {
        let tokens = tokenize("\"hello world\"").unwrap();
        assert_eq!(tokens, vec![Token::DoubleQuoted("hello world".to_string())]);
    }

    #[test]
    fn test_pipe() {
        let tokens = tokenize("ls | cat").unwrap();
        assert_eq!(
            tokens,
            vec![
                Token::Word("ls".to_string()),
                Token::Pipe,
                Token::Word("cat".to_string())
            ]
        );
    }

    #[test]
    fn test_and_or() {
        let tokens = tokenize("cmd1 && cmd2 || cmd3").unwrap();
        assert_eq!(
            tokens,
            vec![
                Token::Word("cmd1".to_string()),
                Token::And,
                Token::Word("cmd2".to_string()),
                Token::Or,
                Token::Word("cmd3".to_string())
            ]
        );
    }

    #[test]
    fn test_redirect() {
        let tokens = tokenize("echo hello > file").unwrap();
        assert_eq!(
            tokens,
            vec![
                Token::Word("echo".to_string()),
                Token::Word("hello".to_string()),
                Token::RedirectOut,
                Token::Word("file".to_string())
            ]
        );
    }

    #[test]
    fn test_env_var() {
        let tokens = tokenize("echo $HOME").unwrap();
        assert_eq!(
            tokens,
            vec![
                Token::Word("echo".to_string()),
                Token::Word("$HOME".to_string())
            ]
        );
    }
}
