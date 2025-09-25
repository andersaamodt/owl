use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogLevel {
    Off,
    Minimal,
    VerboseSanitized,
    VerboseFull,
}

impl FromStr for LogLevel {
    type Err = &'static str;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "off" => Ok(Self::Off),
            "minimal" => Ok(Self::Minimal),
            "verbose_sanitized" => Ok(Self::VerboseSanitized),
            "verbose_full" => Ok(Self::VerboseFull),
            _ => Err("unknown level"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_levels() {
        assert_eq!(LogLevel::from_str("off").unwrap(), LogLevel::Off);
        assert!(LogLevel::from_str("nope").is_err());
    }
}
