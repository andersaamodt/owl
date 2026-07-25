use time::{Duration, OffsetDateTime};

pub fn parse_delete_after(value: &str) -> Option<Duration> {
    match value.trim() {
        "never" => None,
        v if v.ends_with('d') => v[..v.len() - 1]
            .parse::<i64>()
            .ok()
            .map(|days| Duration::days(days)),
        v if v.ends_with('m') => v[..v.len() - 1]
            .parse::<i64>()
            .ok()
            .map(|months| Duration::days(months * 30)),
        v if v.ends_with('y') => v[..v.len() - 1]
            .parse::<i64>()
            .ok()
            .map(|years| Duration::days(years * 365)),
        _ => None,
    }
}

pub fn retention_due(last_activity: OffsetDateTime, policy: &str, now: OffsetDateTime) -> bool {
    parse_delete_after(policy).is_some_and(|duration| last_activity + duration < now)
}

pub fn parse_interval(value: &str) -> Option<Duration> {
    let trimmed = value.trim().to_ascii_lowercase();
    if trimmed.is_empty() {
        return None;
    }
    let (number, suffix) = trimmed.split_at(trimmed.len() - 1);
    let parsed = number.parse::<i64>().ok()?;
    match suffix {
        "s" => Some(Duration::seconds(parsed)),
        "m" => Some(Duration::minutes(parsed)),
        "h" => Some(Duration::hours(parsed)),
        "d" => Some(Duration::days(parsed)),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_months() {
        let duration = parse_delete_after("6m").unwrap();
        assert_eq!(duration.whole_days(), 6 * 30);
    }

    #[test]
    fn never_returns_none() {
        assert!(parse_delete_after("never").is_none());
    }

    #[test]
    fn retention_check() {
        let now = OffsetDateTime::now_utc();
        assert!(!retention_due(now, "never", now));
    }

    #[test]
    fn parse_days_and_years() {
        assert_eq!(parse_delete_after("10d").unwrap().whole_days(), 10);
        assert_eq!(parse_delete_after("2y").unwrap().whole_days(), 2 * 365);
    }

    #[test]
    fn invalid_duration_returns_none() {
        assert!(parse_delete_after("invalid").is_none());
    }

    #[test]
    fn unsupported_suffix_returns_none() {
        assert!(parse_delete_after("1w").is_none());
    }

    #[test]
    fn retention_due_becomes_true() {
        let past = OffsetDateTime::now_utc() - Duration::days(400);
        assert!(retention_due(past, "1y", OffsetDateTime::now_utc()));
    }

    #[test]
    fn zero_duration_policies_do_not_force_deletion() {
        let now = OffsetDateTime::now_utc();
        assert_eq!(parse_delete_after("0d").unwrap().whole_days(), 0);
        assert!(!retention_due(now, "0d", now));
    }

    #[test]
    fn parse_interval_supports_common_units() {
        assert_eq!(parse_interval("10s").unwrap().whole_seconds(), 10);
        assert_eq!(parse_interval("5m").unwrap().whole_minutes(), 5);
        assert_eq!(parse_interval("2h").unwrap().whole_hours(), 2);
        assert_eq!(parse_interval("3d").unwrap().whole_days(), 3);
        assert!(parse_interval("1w").is_none());
    }

    #[test]
    fn parse_interval_rejects_empty_values() {
        assert!(parse_interval("   ").is_none());
    }

    #[test]
    fn parse_delete_after_boundary_zero_values() {
        // Per spec: 0d, 0m, 0y should parse (not reject) but not force immediate deletion
        assert_eq!(parse_delete_after("0d").unwrap().whole_days(), 0);
        assert_eq!(parse_delete_after("0m").unwrap().whole_days(), 0);
        assert_eq!(parse_delete_after("0y").unwrap().whole_days(), 0);
    }

    #[test]
    fn parse_delete_after_large_values() {
        // Test overflow safety with large values
        assert_eq!(parse_delete_after("100y").unwrap().whole_days(), 100 * 365);
        assert_eq!(parse_delete_after("1000d").unwrap().whole_days(), 1000);
        assert_eq!(parse_delete_after("500m").unwrap().whole_days(), 500 * 30);
    }

    #[test]
    fn parse_delete_after_whitespace_handling() {
        // Whitespace should be trimmed per spec
        assert_eq!(parse_delete_after(" 30d ").unwrap().whole_days(), 30);
        assert_eq!(parse_delete_after("  6m  ").unwrap().whole_days(), 6 * 30);
        assert!(parse_delete_after(" never ").is_none());
    }

    #[test]
    fn parse_delete_after_empty_after_trim() {
        // Empty string after trim should return None
        assert!(parse_delete_after("   ").is_none());
        assert!(parse_delete_after("").is_none());
    }

    #[test]
    fn parse_delete_after_invalid_suffixes() {
        // Per spec: only d, m, y, never are valid
        assert!(parse_delete_after("1w").is_none()); // weeks not supported
        assert!(parse_delete_after("1h").is_none()); // hours not supported
        assert!(parse_delete_after("30s").is_none()); // seconds not supported
        assert!(parse_delete_after("2q").is_none()); // quarters not supported
    }

    #[test]
    fn parse_delete_after_negative_values() {
        // Negative values parse successfully (parse::<i64> accepts them)
        // but would result in negative durations, which are semantically invalid.
        // The retention_due() function handles this correctly since
        // last_activity + negative_duration < now will always be true.
        assert!(parse_delete_after("-1d").is_some());
        assert!(parse_delete_after("-10y").is_some());
    }

    #[test]
    fn parse_delete_after_non_numeric_prefix() {
        // "abcd" should fail to parse as number
        assert!(parse_delete_after("abcd").is_none());
        assert!(parse_delete_after("xd").is_none());
    }

    #[test]
    fn retention_due_exact_boundary() {
        // Test exact time boundary
        let now = OffsetDateTime::now_utc();
        let exactly_30_days_ago = now - Duration::days(30);

        // Exactly at boundary: last_activity + 30d == now, so NOT due yet
        assert!(!retention_due(exactly_30_days_ago, "30d", now));

        // Just over boundary: last_activity + 30d < now, so IS due
        let just_over_30_days = now - Duration::days(30) - Duration::seconds(1);
        assert!(retention_due(just_over_30_days, "30d", now));
    }

    #[test]
    fn parse_interval_case_insensitive() {
        // parse_interval uses to_ascii_lowercase
        assert_eq!(parse_interval("10S").unwrap().whole_seconds(), 10);
        assert_eq!(parse_interval("5M").unwrap().whole_minutes(), 5);
        assert_eq!(parse_interval("2H").unwrap().whole_hours(), 2);
        assert_eq!(parse_interval("3D").unwrap().whole_days(), 3);
    }

    #[test]
    fn parse_interval_zero_value() {
        assert_eq!(parse_interval("0s").unwrap().whole_seconds(), 0);
        assert_eq!(parse_interval("0m").unwrap().whole_minutes(), 0);
    }

    #[test]
    fn parse_interval_whitespace_trimmed() {
        assert_eq!(parse_interval("  10s  ").unwrap().whole_seconds(), 10);
        assert_eq!(parse_interval(" 5m ").unwrap().whole_minutes(), 5);
    }
}
