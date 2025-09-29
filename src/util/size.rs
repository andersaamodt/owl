use anyhow::{Context, Result, bail};

/// Parse human-readable byte sizes such as `25M` or `10MB` into raw bytes.
///
/// Supported suffixes (case-insensitive):
/// - no suffix / `B`
/// - `K`, `KB`, `KiB`
/// - `M`, `MB`, `MiB`
/// - `G`, `GB`, `GiB`
///
/// Values are interpreted using powers of two (i.e. `1K` == 1024).
pub fn parse_size(input: &str) -> Result<u64> {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        bail!("size value is empty");
    }

    let mut split = trimmed.len();
    for (idx, ch) in trimmed.char_indices() {
        if !ch.is_ascii_digit() {
            split = idx;
            break;
        }
    }

    let (number_part, suffix_part) = trimmed.split_at(split);
    if number_part.is_empty() {
        bail!("size value is missing digits");
    }

    let value: u64 = number_part
        .parse()
        .with_context(|| format!("invalid size value: {trimmed}"))?;

    let suffix = suffix_part.trim().to_ascii_lowercase();
    let multiplier = match suffix.as_str() {
        "" | "b" => 1u64,
        "k" | "kb" | "kib" => 1024u64,
        "m" | "mb" | "mib" => 1024u64 * 1024u64,
        "g" | "gb" | "gib" => 1024u64 * 1024u64 * 1024u64,
        other => bail!("unsupported size suffix: {other}"),
    };

    value
        .checked_mul(multiplier)
        .ok_or_else(|| anyhow::anyhow!("size value overflow"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_plain_bytes() {
        assert_eq!(parse_size("512").unwrap(), 512);
    }

    #[test]
    fn parses_kilobytes() {
        assert_eq!(parse_size("1K").unwrap(), 1024);
        assert_eq!(parse_size("2kb").unwrap(), 2048);
    }

    #[test]
    fn parses_megabytes() {
        assert_eq!(parse_size("1M").unwrap(), 1024 * 1024);
        assert_eq!(parse_size("3MB").unwrap(), 3 * 1024 * 1024);
    }

    #[test]
    fn parses_gigabytes() {
        assert_eq!(parse_size("2GB").unwrap(), 2 * 1024 * 1024 * 1024);
    }

    #[test]
    fn rejects_invalid_values() {
        assert!(parse_size("").is_err());
        assert!(parse_size("abc").is_err());
        assert!(parse_size("1TB").is_err());
    }

    #[test]
    fn overflows_on_large_values() {
        let huge = format!("{}K", u64::MAX);
        let err = parse_size(&huge).unwrap_err();
        assert!(err.to_string().contains("overflow"));
    }

    #[test]
    fn reports_invalid_number_context() {
        let too_big = (u64::MAX as u128 + 1).to_string();
        let err = parse_size(&too_big).unwrap_err();
        assert!(err.to_string().contains("invalid size value"));
    }
}
