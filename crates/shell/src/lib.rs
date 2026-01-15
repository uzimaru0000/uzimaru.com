//! シェルパーサー WASM コンポーネント

mod ast;
mod expander;
mod lexer;
mod parser;

use std::collections::HashMap;

wit_bindgen::generate!({
    world: "shell",
});

use uzimaru::shell::types;

struct ShellImpl;

impl exports::uzimaru::shell::parser::Guest for ShellImpl {
    fn parse(input: String) -> Result<types::ParseResult, types::ParseError> {
        match parser::Parser::parse_input(&input) {
            Ok(result) => Ok(convert_parse_result(result)),
            Err(e) => Err(types::ParseError {
                message: e.message,
                position: e.position,
            }),
        }
    }
}

impl exports::uzimaru::shell::expander::Guest for ShellImpl {
    fn expand_word(word: types::ParsedWord, env: Vec<(String, String)>) -> String {
        let rust_word = convert_from_wit_word(word);
        let env_map: HashMap<String, String> = env.into_iter().collect();
        expander::expand_word(&rust_word, &env_map)
    }
}

// 型変換関数

fn convert_parse_result(result: ast::ParseResult) -> types::ParseResult {
    types::ParseResult {
        elements: result
            .elements
            .into_iter()
            .map(convert_conditional_element)
            .collect(),
        substitutions: result
            .substitutions
            .into_iter()
            .map(convert_command_substitution)
            .collect(),
    }
}

fn convert_conditional_element(elem: ast::ConditionalElement) -> types::ConditionalElement {
    types::ConditionalElement {
        connector: convert_connector(elem.connector),
        pipeline: convert_pipeline(elem.pipeline),
    }
}

fn convert_connector(conn: ast::Connector) -> types::Connector {
    match conn {
        ast::Connector::None => types::Connector::None,
        ast::Connector::And => types::Connector::And,
        ast::Connector::Or => types::Connector::Or,
    }
}

fn convert_pipeline(pipeline: ast::Pipeline) -> types::Pipeline {
    types::Pipeline {
        commands: pipeline
            .commands
            .into_iter()
            .map(convert_simple_command)
            .collect(),
    }
}

fn convert_simple_command(cmd: ast::SimpleCommand) -> types::SimpleCommand {
    types::SimpleCommand {
        args: cmd.args.into_iter().map(convert_parsed_word).collect(),
        redirects: cmd.redirects.into_iter().map(convert_redirect).collect(),
    }
}

fn convert_parsed_word(word: ast::ParsedWord) -> types::ParsedWord {
    types::ParsedWord {
        segments: word
            .segments
            .into_iter()
            .map(convert_word_segment)
            .collect(),
    }
}

fn convert_word_segment(seg: ast::WordSegment) -> types::WordSegment {
    match seg {
        ast::WordSegment::Literal(s) => types::WordSegment::Literal(s),
        ast::WordSegment::EnvVar(env_ref) => types::WordSegment::EnvVar(types::EnvRef {
            name: env_ref.name,
            default_value: env_ref.default,
        }),
        ast::WordSegment::CommandSubst(id) => types::WordSegment::CommandSubst(id),
    }
}

fn convert_redirect(redirect: ast::Redirect) -> types::Redirect {
    types::Redirect {
        kind: convert_redirect_kind(redirect.kind),
        target: convert_parsed_word(redirect.target),
    }
}

fn convert_redirect_kind(kind: ast::RedirectKind) -> types::RedirectKind {
    match kind {
        ast::RedirectKind::Stdin => types::RedirectKind::Stdin,
        ast::RedirectKind::Stdout => types::RedirectKind::Stdout,
        ast::RedirectKind::StdoutAppend => types::RedirectKind::StdoutAppend,
    }
}

fn convert_command_substitution(subst: ast::CommandSubstitution) -> types::CommandSubstitution {
    types::CommandSubstitution {
        id: subst.id,
        input: subst.input,
    }
}

// WIT 型から Rust 型への変換

fn convert_from_wit_word(word: types::ParsedWord) -> ast::ParsedWord {
    ast::ParsedWord {
        segments: word
            .segments
            .into_iter()
            .map(convert_from_wit_segment)
            .collect(),
    }
}

fn convert_from_wit_segment(seg: types::WordSegment) -> ast::WordSegment {
    match seg {
        types::WordSegment::Literal(s) => ast::WordSegment::Literal(s),
        types::WordSegment::EnvVar(env_ref) => ast::WordSegment::EnvVar(ast::EnvRef {
            name: env_ref.name,
            default: env_ref.default_value,
        }),
        types::WordSegment::CommandSubst(id) => ast::WordSegment::CommandSubst(id),
    }
}

export!(ShellImpl);
