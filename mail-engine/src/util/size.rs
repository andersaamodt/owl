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

    #[test]
    fn parse_spec_quarantine_limit() {
        // Per spec: quarantine cap is 25M
        assert_eq!(parse_size("25M").unwrap(), 25 * 1024 * 1024);
    }

    #[test]
    fn parse_spec_approved_limit() {
        // Per spec: approved default cap is 50M
        assert_eq!(parse_size("50M").unwrap(), 50 * 1024 * 1024);
    }

    #[test]
    fn parse_size_whitespace_handling() {
        // Whitespace should be trimmed
        assert_eq!(parse_size("  25M  ").unwrap(), 25 * 1024 * 1024);
        assert_eq!(parse_size(" 1G ").unwrap(), 1024 * 1024 * 1024);
    }

    #[test]
    fn parse_size_case_insensitive() {
        // Suffixes are case-insensitive
        assert_eq!(parse_size("1m").unwrap(), 1024 * 1024);
        assert_eq!(parse_size("1M").unwrap(), 1024 * 1024);
        assert_eq!(parse_size("1MB").unwrap(), 1024 * 1024);
        assert_eq!(parse_size("1mb").unwrap(), 1024 * 1024);
    }

    #[test]
    fn parse_size_kibibyte_suffix() {
        // KiB, MiB, GiB explicit binary suffixes
        assert_eq!(parse_size("1KiB").unwrap(), 1024);
        assert_eq!(parse_size("1MiB").unwrap(), 1024 * 1024);
        assert_eq!(parse_size("1GiB").unwrap(), 1024 * 1024 * 1024);
    }

    #[test]
    fn parse_size_zero_value() {
        assert_eq!(parse_size("0").unwrap(), 0);
        assert_eq!(parse_size("0M").unwrap(), 0);
        assert_eq!(parse_size("0G").unwrap(), 0);
    }

    #[test]
    fn parse_size_rejects_unsupported_suffixes() {
        // TB, PB not supported
        assert!(parse_size("1TB").is_err());
        assert!(parse_size("1PB").is_err());
        assert!(parse_size("1t").is_err());

        // Invalid suffixes
        assert!(parse_size("1X").is_err());
        assert!(parse_size("10bytes").is_err());
    }

    #[test]
    fn parse_size_empty_string_error() {
        assert!(parse_size("").is_err());
        assert!(parse_size("   ").is_err());
    }

    #[test]
    fn parse_size_no_digits_error() {
        assert!(parse_size("MB").is_err());
        assert!(parse_size("K").is_err());
    }

    #[test]
    fn parse_size_boundary_at_limit() {
        // Test exactly at message size boundary
        let exactly_25mb = parse_size("25M").unwrap();
        assert_eq!(exactly_25mb, 25 * 1024 * 1024);

        // One byte over should still parse
        let bytes_str = (25 * 1024 * 1024 + 1).to_string();
        assert_eq!(parse_size(&bytes_str).unwrap(), 25 * 1024 * 1024 + 1);
    }

    #[test]
    fn parse_size_b_suffix_explicit() {
        // Explicit 'B' suffix for bytes
        assert_eq!(parse_size("512B").unwrap(), 512);
        assert_eq!(parse_size("100b").unwrap(), 100);
    }

    #[test]
    fn parse_size_overflow_detection() {
        // Ensure overflow is properly detected with checked_mul
        let near_max = u64::MAX / 1024 + 1;
        let input = format!("{}K", near_max);
        assert!(parse_size(&input).is_err());
    }
}
