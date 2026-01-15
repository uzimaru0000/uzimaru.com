wit_bindgen::generate!({
    world: "markdown",
});

use pulldown_cmark::{Alignment, CodeBlockKind, Event, HeadingLevel, Options, Parser, Tag, TagEnd};
use serde::Serialize;
use std::io::Write;

struct Markdown;

// Serializable event types
#[derive(Serialize)]
#[serde(tag = "type")]
enum SerEvent {
    Start { tag: SerTag },
    End { tag: SerTagEnd },
    Text { content: String },
    Code { content: String },
    Html { content: String },
    InlineHtml { content: String },
    SoftBreak,
    HardBreak,
    Rule,
    TaskListMarker { checked: bool },
    FootnoteReference { label: String },
}

#[derive(Serialize)]
#[serde(tag = "type")]
enum SerTag {
    Paragraph,
    Heading { level: u8, id: Option<String> },
    BlockQuote { kind: Option<String> },
    CodeBlock { language: Option<String> },
    List { start_number: Option<u64> },
    Item,
    Emphasis,
    Strong,
    Strikethrough,
    Link { url: String, title: Option<String> },
    Image { url: String, title: Option<String> },
    Table { alignments: Vec<String> },
    TableHead,
    TableRow,
    TableCell,
    HtmlBlock,
}

#[derive(Serialize)]
#[serde(tag = "type")]
enum SerTagEnd {
    Paragraph,
    Heading { level: u8 },
    BlockQuote,
    CodeBlock,
    List { ordered: bool },
    Item,
    Emphasis,
    Strong,
    Strikethrough,
    Link,
    Image,
    Table,
    TableHead,
    TableRow,
    TableCell,
    HtmlBlock,
}

fn convert_heading_level(level: HeadingLevel) -> u8 {
    match level {
        HeadingLevel::H1 => 1,
        HeadingLevel::H2 => 2,
        HeadingLevel::H3 => 3,
        HeadingLevel::H4 => 4,
        HeadingLevel::H5 => 5,
        HeadingLevel::H6 => 6,
    }
}

fn convert_alignment(align: &Alignment) -> String {
    match align {
        Alignment::None => "None".to_string(),
        Alignment::Left => "Left".to_string(),
        Alignment::Center => "Center".to_string(),
        Alignment::Right => "Right".to_string(),
    }
}

fn convert_tag(tag: Tag) -> SerTag {
    match tag {
        Tag::Paragraph => SerTag::Paragraph,
        Tag::Heading { level, id, .. } => SerTag::Heading {
            level: convert_heading_level(level),
            id: id.map(|s| s.to_string()),
        },
        Tag::BlockQuote(kind) => SerTag::BlockQuote {
            kind: kind.map(|k| {
                match k {
                    pulldown_cmark::BlockQuoteKind::Note => "Note",
                    pulldown_cmark::BlockQuoteKind::Tip => "Tip",
                    pulldown_cmark::BlockQuoteKind::Important => "Important",
                    pulldown_cmark::BlockQuoteKind::Warning => "Warning",
                    pulldown_cmark::BlockQuoteKind::Caution => "Caution",
                }
                .to_string()
            }),
        },
        Tag::CodeBlock(kind) => SerTag::CodeBlock {
            language: match kind {
                CodeBlockKind::Fenced(lang) if !lang.is_empty() => Some(lang.to_string()),
                _ => None,
            },
        },
        Tag::List(start) => SerTag::List {
            start_number: start,
        },
        Tag::Item => SerTag::Item,
        Tag::Emphasis => SerTag::Emphasis,
        Tag::Strong => SerTag::Strong,
        Tag::Strikethrough => SerTag::Strikethrough,
        Tag::Link { dest_url, title, .. } => SerTag::Link {
            url: dest_url.to_string(),
            title: if title.is_empty() {
                None
            } else {
                Some(title.to_string())
            },
        },
        Tag::Image { dest_url, title, .. } => SerTag::Image {
            url: dest_url.to_string(),
            title: if title.is_empty() {
                None
            } else {
                Some(title.to_string())
            },
        },
        Tag::Table(alignments) => SerTag::Table {
            alignments: alignments.iter().map(convert_alignment).collect(),
        },
        Tag::TableHead => SerTag::TableHead,
        Tag::TableRow => SerTag::TableRow,
        Tag::TableCell => SerTag::TableCell,
        Tag::HtmlBlock => SerTag::HtmlBlock,
        _ => SerTag::Paragraph, // Fallback for any unhandled variants
    }
}

fn convert_tag_end(tag_end: TagEnd) -> SerTagEnd {
    match tag_end {
        TagEnd::Paragraph => SerTagEnd::Paragraph,
        TagEnd::Heading(level) => SerTagEnd::Heading {
            level: convert_heading_level(level),
        },
        TagEnd::BlockQuote(_) => SerTagEnd::BlockQuote,
        TagEnd::CodeBlock => SerTagEnd::CodeBlock,
        TagEnd::List(ordered) => SerTagEnd::List { ordered },
        TagEnd::Item => SerTagEnd::Item,
        TagEnd::Emphasis => SerTagEnd::Emphasis,
        TagEnd::Strong => SerTagEnd::Strong,
        TagEnd::Strikethrough => SerTagEnd::Strikethrough,
        TagEnd::Link => SerTagEnd::Link,
        TagEnd::Image => SerTagEnd::Image,
        TagEnd::Table => SerTagEnd::Table,
        TagEnd::TableHead => SerTagEnd::TableHead,
        TagEnd::TableRow => SerTagEnd::TableRow,
        TagEnd::TableCell => SerTagEnd::TableCell,
        TagEnd::HtmlBlock => SerTagEnd::HtmlBlock,
        _ => SerTagEnd::Paragraph, // Fallback
    }
}

fn convert_event(event: Event) -> SerEvent {
    match event {
        Event::Start(tag) => SerEvent::Start {
            tag: convert_tag(tag),
        },
        Event::End(tag_end) => SerEvent::End {
            tag: convert_tag_end(tag_end),
        },
        Event::Text(text) => SerEvent::Text {
            content: text.to_string(),
        },
        Event::Code(code) => SerEvent::Code {
            content: code.to_string(),
        },
        Event::Html(html) => SerEvent::Html {
            content: html.to_string(),
        },
        Event::InlineHtml(html) => SerEvent::InlineHtml {
            content: html.to_string(),
        },
        Event::SoftBreak => SerEvent::SoftBreak,
        Event::HardBreak => SerEvent::HardBreak,
        Event::Rule => SerEvent::Rule,
        Event::TaskListMarker(checked) => SerEvent::TaskListMarker { checked },
        Event::FootnoteReference(label) => SerEvent::FootnoteReference {
            label: label.to_string(),
        },
        _ => SerEvent::Text {
            content: String::new(),
        }, // Fallback for math, etc.
    }
}

impl Guest for Markdown {
    fn run(input: CommandInput) -> i32 {
        if input.args.len() < 2 {
            eprintln!("markdown: missing file operand");
            return 1;
        }

        let path = if input.args[1].starts_with('/') {
            input.args[1].clone()
        } else {
            format!("{}/{}", input.cwd.trim_end_matches('/'), &input.args[1])
        };

        match std::fs::read_to_string(&path) {
            Ok(content) => {
                let mut options = Options::empty();
                options.insert(Options::ENABLE_TABLES);
                options.insert(Options::ENABLE_STRIKETHROUGH);
                options.insert(Options::ENABLE_TASKLISTS);
                let parser = Parser::new_ext(&content, options);
                let events: Vec<SerEvent> = parser.map(convert_event).collect();

                // Create OSC payload
                let payload = serde_json::json!({
                    "type": "markdown",
                    "props": {
                        "events": events
                    }
                });

                // Output OSC sequence (using ESC \ as terminator instead of BEL)
                print!(
                    "\x1b]custom;{}\x1b\\",
                    serde_json::to_string(&payload).unwrap()
                );
                // Explicitly flush stdout to ensure all data is written
                let _ = std::io::stdout().flush();
                0
            }
            Err(e) => {
                eprintln!("markdown: {}: {}", path, e);
                1
            }
        }
    }
}

export!(Markdown);
