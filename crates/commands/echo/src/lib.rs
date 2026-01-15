wit_bindgen::generate!({
    world: "echo",
});

struct Echo;

impl Guest for Echo {
    fn run(input: CommandInput) -> i32 {
        // Skip the first arg (command name) and join the rest with spaces
        let output = input.args.into_iter().skip(1).collect::<Vec<_>>().join(" ");

        // WASI stdout に出力（WASIShim がキャプチャする）
        println!("{}", output);

        // exit code を返す
        0
    }
}

export!(Echo);
