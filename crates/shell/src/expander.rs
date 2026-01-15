//! 変数展開

use crate::ast::{ParsedWord, WordSegment};
use std::collections::HashMap;

/// パース済みワードを展開
pub fn expand_word(word: &ParsedWord, env: &HashMap<String, String>) -> String {
    word.segments
        .iter()
        .map(|seg| match seg {
            WordSegment::Literal(s) => s.clone(),
            WordSegment::EnvVar(env_ref) => {
                env.get(&env_ref.name)
                    .cloned()
                    .unwrap_or_else(|| env_ref.default.clone().unwrap_or_default())
            }
            WordSegment::CommandSubst(_) => {
                // コマンド置換はここでは展開しない
                // TypeScript 側で解決される
                String::new()
            }
        })
        .collect()
}

/// 環境変数リストを HashMap に変換
pub fn env_list_to_map(env: &[(String, String)]) -> HashMap<String, String> {
    env.iter().cloned().collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ast::EnvRef;

    #[test]
    fn test_literal() {
        let word = ParsedWord::literal("hello");
        let env = HashMap::new();
        assert_eq!(expand_word(&word, &env), "hello");
    }

    #[test]
    fn test_env_var() {
        let word = ParsedWord {
            segments: vec![WordSegment::EnvVar(EnvRef {
                name: "HOME".to_string(),
                default: None,
            })],
        };
        let mut env = HashMap::new();
        env.insert("HOME".to_string(), "/home/user".to_string());
        assert_eq!(expand_word(&word, &env), "/home/user");
    }

    #[test]
    fn test_env_var_default() {
        let word = ParsedWord {
            segments: vec![WordSegment::EnvVar(EnvRef {
                name: "MISSING".to_string(),
                default: Some("default".to_string()),
            })],
        };
        let env = HashMap::new();
        assert_eq!(expand_word(&word, &env), "default");
    }

    #[test]
    fn test_mixed() {
        let word = ParsedWord {
            segments: vec![
                WordSegment::Literal("Hello, ".to_string()),
                WordSegment::EnvVar(EnvRef {
                    name: "USER".to_string(),
                    default: None,
                }),
                WordSegment::Literal("!".to_string()),
            ],
        };
        let mut env = HashMap::new();
        env.insert("USER".to_string(), "world".to_string());
        assert_eq!(expand_word(&word, &env), "Hello, world!");
    }
}
