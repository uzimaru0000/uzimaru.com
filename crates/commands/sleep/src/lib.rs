wit_bindgen::generate!({
    world: "sleep",
});

use std::thread;
use std::time::Duration;

struct Sleep;

impl Guest for Sleep {
    fn run(input: CommandInput) -> i32 {
        // 引数から秒数を取得
        let seconds = match input.args.get(1) {
            Some(arg) => match arg.parse::<f64>() {
                Ok(n) if n >= 0.0 => n,
                Ok(_) => {
                    eprintln!("sleep: invalid time interval: negative number");
                    return 1;
                }
                Err(_) => {
                    eprintln!("sleep: invalid time interval: '{}'", arg);
                    return 1;
                }
            },
            None => {
                eprintln!("sleep: missing operand");
                return 1;
            }
        };

        // 指定秒数だけスリープ
        let duration = Duration::from_secs_f64(seconds);
        thread::sleep(duration);

        0
    }
}

export!(Sleep);
