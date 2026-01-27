wit_bindgen::generate!({
    world: "date",
});

use std::time::{SystemTime, UNIX_EPOCH};

struct Date;

impl Guest for Date {
    fn run(input: CommandInput) -> i32 {
        // システム時刻を取得
        let now = SystemTime::now();
        let duration = match now.duration_since(UNIX_EPOCH) {
            Ok(d) => d,
            Err(e) => {
                eprintln!("date: failed to get system time: {}", e);
                return 1;
            }
        };

        let timestamp_secs = duration.as_secs() as i64;

        // タイムゾーンオフセットを環境変数から取得（分単位）
        let tz_offset_mins: i32 = input
            .env
            .iter()
            .find(|(k, _)| k == "TZ_OFFSET")
            .and_then(|(_, v)| v.parse().ok())
            .unwrap_or(0);

        // タイムゾーン名を取得
        let tz_name: String = input
            .env
            .iter()
            .find(|(k, _)| k == "TZ_NAME")
            .map(|(_, v)| v.clone())
            .unwrap_or_else(|| "UTC".to_string());

        // ローカル時刻に変換
        let local_secs = timestamp_secs + (tz_offset_mins as i64 * 60);

        // フォーマット文字列を取得
        let format = if input.args.len() > 1 && input.args[1].starts_with('+') {
            input.args[1][1..].to_string()
        } else {
            // デフォルトフォーマット
            "%a %b %e %H:%M:%S %Z %Y".to_string()
        };

        let output = format_date(local_secs, &format, tz_offset_mins, &tz_name);
        println!("{}", output);

        0
    }
}

fn format_date(timestamp_secs: i64, format: &str, tz_offset_mins: i32, tz_name: &str) -> String {
    // タイムスタンプから日時コンポーネントを計算
    let (year, month, day, hour, minute, second, weekday, yearday) =
        timestamp_to_components(timestamp_secs);

    let weekdays_short = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    let weekdays_full = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ];
    let months_short = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    let months_full = [
        "January", "February", "March", "April", "May", "June", "July", "August", "September",
        "October", "November", "December",
    ];

    let mut result = String::new();
    let mut chars = format.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '%' {
            if let Some(&spec) = chars.peek() {
                chars.next();
                match spec {
                    'Y' => result.push_str(&format!("{:04}", year)),
                    'y' => result.push_str(&format!("{:02}", year % 100)),
                    'm' => result.push_str(&format!("{:02}", month)),
                    'd' => result.push_str(&format!("{:02}", day)),
                    'e' => result.push_str(&format!("{:2}", day)),
                    'H' => result.push_str(&format!("{:02}", hour)),
                    'I' => {
                        result.push_str(&format!("{:02}", if hour % 12 == 0 { 12 } else { hour % 12 }))
                    }
                    'M' => result.push_str(&format!("{:02}", minute)),
                    'S' => result.push_str(&format!("{:02}", second)),
                    'p' => result.push_str(if hour < 12 { "AM" } else { "PM" }),
                    'P' => result.push_str(if hour < 12 { "am" } else { "pm" }),
                    'a' => result.push_str(weekdays_short[weekday as usize]),
                    'A' => result.push_str(weekdays_full[weekday as usize]),
                    'b' | 'h' => result.push_str(months_short[(month - 1) as usize]),
                    'B' => result.push_str(months_full[(month - 1) as usize]),
                    'w' => result.push_str(&weekday.to_string()),
                    'u' => result.push_str(&(if weekday == 0 { 7 } else { weekday }).to_string()),
                    'j' => result.push_str(&format!("{:03}", yearday)),
                    'Z' => result.push_str(tz_name),
                    'z' => {
                        let sign = if tz_offset_mins >= 0 { '+' } else { '-' };
                        let abs_offset = tz_offset_mins.abs();
                        let hours = abs_offset / 60;
                        let mins = abs_offset % 60;
                        result.push_str(&format!("{}{:02}{:02}", sign, hours, mins));
                    }
                    'n' => result.push('\n'),
                    't' => result.push('\t'),
                    '%' => result.push('%'),
                    'F' => result.push_str(&format!("{:04}-{:02}-{:02}", year, month, day)),
                    'T' => result.push_str(&format!("{:02}:{:02}:{:02}", hour, minute, second)),
                    'R' => result.push_str(&format!("{:02}:{:02}", hour, minute)),
                    'D' => result.push_str(&format!("{:02}/{:02}/{:02}", month, day, year % 100)),
                    _ => {
                        result.push('%');
                        result.push(spec);
                    }
                }
            } else {
                result.push('%');
            }
        } else {
            result.push(c);
        }
    }

    result
}

fn timestamp_to_components(timestamp_secs: i64) -> (i32, u32, u32, u32, u32, u32, u32, u32) {
    // UNIX タイムスタンプから日時コンポーネントを計算

    let days_since_epoch = timestamp_secs.div_euclid(86400);
    let time_of_day = timestamp_secs.rem_euclid(86400);

    let hour = (time_of_day / 3600) as u32;
    let minute = ((time_of_day % 3600) / 60) as u32;
    let second = (time_of_day % 60) as u32;

    // 曜日（1970-01-01 は木曜日 = 4）
    let weekday = ((days_since_epoch % 7 + 4).rem_euclid(7)) as u32;

    // 年月日の計算
    let (year, month, day, yearday) = days_to_ymd(days_since_epoch);

    (year, month, day, hour, minute, second, weekday, yearday)
}

fn days_to_ymd(days_since_epoch: i64) -> (i32, u32, u32, u32) {
    // 1970-01-01 からの日数を年月日に変換

    let mut days = days_since_epoch;
    let mut year = 1970i32;

    // 年を計算
    if days >= 0 {
        loop {
            let days_in_year = if is_leap_year(year) { 366 } else { 365 };
            if days < days_in_year {
                break;
            }
            days -= days_in_year;
            year += 1;
        }
    } else {
        loop {
            year -= 1;
            let days_in_year = if is_leap_year(year) { 366 } else { 365 };
            days += days_in_year;
            if days >= 0 {
                break;
            }
        }
    }

    let yearday = days as u32 + 1;

    // 月と日を計算
    let leap = is_leap_year(year);
    let days_in_months: [i64; 12] = if leap {
        [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    };

    let mut month = 1u32;
    for (i, &dim) in days_in_months.iter().enumerate() {
        if days < dim {
            month = i as u32 + 1;
            break;
        }
        days -= dim;
    }

    let day = days as u32 + 1;

    (year, month, day, yearday)
}

fn is_leap_year(year: i32) -> bool {
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
}

export!(Date);
