use std::{env, fs, process};

const REQUIRED_COLUMNS: [&str; 14] = [
    "timestamp", "cpu_temperature", "cpu_usage", "cpu_frequency_mhz",
    "gpu_temperature", "gpu_usage", "gpu_core_clock_mhz", "gpu_power_watts",
    "gpu_memory_usage", "fan_percent", "fan_rpm", "memory_usage",
    "disk_usage", "thermal_status",
];

#[derive(Debug, Default)]
struct Summary {
    rows: usize,
    cpu_temp_max: Option<f64>,
    gpu_temp_max: Option<f64>,
    fan_rpm_max: Option<f64>,
}

fn parse_csv_line(line: &str) -> Result<Vec<String>, String> {
    let mut fields = Vec::new();
    let mut current = String::new();
    let mut quoted = false;
    let mut chars = line.chars().peekable();

    while let Some(ch) = chars.next() {
        match ch {
            '"' if quoted && chars.peek() == Some(&'"') => {
                current.push('"');
                chars.next();
            }
            '"' => quoted = !quoted,
            ',' if !quoted => {
                fields.push(current.trim().to_owned());
                current.clear();
            }
            _ => current.push(ch),
        }
    }

    if quoted {
        return Err("unterminated quoted CSV field".into());
    }
    fields.push(current.trim().to_owned());
    Ok(fields)
}

fn number(value: &str, row: usize, column: &str) -> Result<Option<f64>, String> {
    if value.is_empty() {
        return Ok(None);
    }
    let parsed = value
        .parse::<f64>()
        .map_err(|_| format!("row {row}: invalid {column} value: {value}"))?;
    if !parsed.is_finite() {
        return Err(format!("row {row}: non-finite {column} value"));
    }
    Ok(Some(parsed))
}

fn update_max(slot: &mut Option<f64>, value: Option<f64>) {
    if let Some(value) = value {
        *slot = Some(slot.map_or(value, |current| current.max(value)));
    }
}

fn validate(path: &str) -> Result<Summary, String> {
    let content = fs::read_to_string(path)
        .map_err(|error| format!("cannot read {path}: {error}"))?;
    let mut lines = content.lines();
    let header = lines.next().ok_or("telemetry CSV is empty")?;
    let columns = parse_csv_line(header)?;
    if columns.iter().map(String::as_str).collect::<Vec<_>>() != REQUIRED_COLUMNS {
        return Err(format!("unexpected telemetry schema; expected {} columns", REQUIRED_COLUMNS.len()));
    }

    let mut summary = Summary::default();
    for (index, line) in lines.enumerate() {
        let row = index + 2;
        if line.trim().is_empty() {
            continue;
        }
        let fields = parse_csv_line(line)?;
        if fields.len() != REQUIRED_COLUMNS.len() {
            return Err(format!("row {row}: expected {} columns, got {}", REQUIRED_COLUMNS.len(), fields.len()));
        }

        let cpu_temp = number(&fields[1], row, "cpu_temperature")?;
        let gpu_temp = number(&fields[4], row, "gpu_temperature")?;
        let fan_rpm = number(&fields[10], row, "fan_rpm")?;
        for (index, column) in REQUIRED_COLUMNS.iter().enumerate().skip(1).take(12) {
            number(&fields[index], row, column)?;
        }

        update_max(&mut summary.cpu_temp_max, cpu_temp);
        update_max(&mut summary.gpu_temp_max, gpu_temp);
        update_max(&mut summary.fan_rpm_max, fan_rpm);
        summary.rows += 1;
    }

    if summary.rows == 0 {
        return Err("telemetry CSV contains no data rows".into());
    }
    Ok(summary)
}

fn main() {
    let mut args = env::args().skip(1);
    let path = match args.next() {
        Some(path) => path,
        None => {
            eprintln!("usage: hwcontrol-telemetry-analyzer <telemetry.csv>");
            process::exit(2);
        }
    };

    if args.next().is_some() {
        eprintln!("usage: hwcontrol-telemetry-analyzer <telemetry.csv>");
        process::exit(2);
    }

    match validate(&path) {
        Ok(summary) => {
            println!("telemetry schema: OK");
            println!("rows: {}", summary.rows);
            println!("cpu_temperature_max_c: {}", summary.cpu_temp_max.map_or("n/a".into(), |v| format!("{v:.2}")));
            println!("gpu_temperature_max_c: {}", summary.gpu_temp_max.map_or("n/a".into(), |v| format!("{v:.2}")));
            println!("fan_rpm_max: {}", summary.fan_rpm_max.map_or("n/a".into(), |v| format!("{v:.0}")));
        }
        Err(error) => {
            eprintln!("telemetry validation failed: {error}");
            process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_quoted_csv_fields() {
        let fields = parse_csv_line(r#"a,"b,b","c""d""#).unwrap();
        assert_eq!(fields, ["a", "b,b", "c\"d"]);
    }

    #[test]
    fn rejects_unterminated_quotes() {
        assert!(parse_csv_line(r#"a,"b"#).is_err());
    }

    #[test]
    fn rejects_non_finite_numbers() {
        assert!(number("NaN", 1, "cpu_temperature").is_err());
        assert!(number("inf", 1, "cpu_temperature").is_err());
    }
}
