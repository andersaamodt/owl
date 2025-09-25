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
    parse_delete_after(policy).map_or(false, |duration| last_activity + duration < now)
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
}
