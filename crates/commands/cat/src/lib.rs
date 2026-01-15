wit_bindgen::generate!({
    world: "cat",
});

use std::io::{self, BufRead, Read};

struct Cat;

impl Guest for Cat {
    fn run(input: CommandInput) -> i32 {
        // 引数がある場合はファイルを読み込む
        if input.args.len() > 1 {
            for arg in input.args.iter().skip(1) {
                let path = if arg.starts_with('/') {
                    arg.clone()
                } else {
                    format!("{}/{}", input.cwd.trim_end_matches('/'), arg)
                };

                match std::fs::read_to_string(&path) {
                    Ok(content) => print!("{}", content),
                    Err(e) => {
                        eprintln!("cat: {}: {}", path, e);
                        return 1;
                    }
                }
            }
        } else {
            // 引数がない場合は stdin から読み込む
            let stdin = io::stdin();
            let mut buffer = String::new();

            // 一度だけ読み込みを試行（ブラウザ環境では EOF が返される）
            match stdin.lock().read_to_string(&mut buffer) {
                Ok(_) => {
                    if !buffer.is_empty() {
                        print!("{}", buffer);
                    } else {
                        println!("(stdin is empty - interactive input not yet supported)");
                    }
                }
                Err(e) => {
                    eprintln!("cat: stdin: {}", e);
                    return 1;
                }
            }
        }

        0
    }
}

export!(Cat);
