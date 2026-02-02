use anyhow::{Result, bail};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ListSettings {
    pub list_status: String,
    pub delete_after: String,
    pub from: Option<String>,
    pub reply_to: Option<String>,
    pub signature: Option<String>,
    pub body_format: String,
    pub collapse_signatures: bool,
}

impl Default for ListSettings {
    fn default() -> Self {
        Self {
            list_status: "accepted".into(),
            delete_after: "never".into(),
            from: None,
            reply_to: None,
            signature: None,
            body_format: "both".into(),
            collapse_signatures: true,
        }
    }
}

impl ListSettings {
    pub fn parse(data: &str) -> Result<Self> {
        let mut settings = Self::default();
        for (idx, line) in data.lines().enumerate() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            let Some((key, value)) = line.split_once('=') else {
                bail!("invalid settings line {}", idx + 1);
            };
            let key = key.trim();
            let value = value.trim();
            match key {
                "list_status" => settings.list_status = value.to_string(),
                "delete_after" => settings.delete_after = value.to_string(),
                "from" => settings.from = Some(value.to_string()),
                "reply_to" => settings.reply_to = Some(value.to_string()),
                "signature" => settings.signature = Some(value.to_string()),
                "body_format" => settings.body_format = value.to_string(),
                "collapse_signatures" => {
                    settings.collapse_signatures = matches!(value, "true" | "1" | "yes")
                }
                _ => bail!("unknown key {key}"),
            }
        }
        Ok(settings)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_applied() {
        let settings = ListSettings::default();
        assert_eq!(settings.body_format, "both");
    }

    #[test]
    fn parse_values() {
        let settings =
            ListSettings::parse("from=Team <team@example.org>\ncollapse_signatures=false").unwrap();
        assert_eq!(settings.from.as_deref(), Some("Team <team@example.org>"));
        assert!(!settings.collapse_signatures);
    }

    #[test]
    fn parse_skips_comments_and_blanks() {
        let settings = ListSettings::parse("# comment\n\nbody_format=html\n").unwrap();
        assert_eq!(settings.body_format, "html");
    }

    #[test]
    fn parse_all_keys() {
        let settings = ListSettings::parse(
            "reply_to=list@example.org\nsignature=~/sig.txt\nbody_format=html\nlist_status=banned\ndelete_after=30d",
        )
        .unwrap();
        assert_eq!(settings.reply_to.as_deref(), Some("list@example.org"));
        assert_eq!(settings.signature.as_deref(), Some("~/sig.txt"));
        assert_eq!(settings.body_format, "html");
        assert_eq!(settings.list_status, "banned");
        assert_eq!(settings.delete_after, "30d");
    }

    #[test]
    fn parse_unknown_key_fails() {
        assert!(ListSettings::parse("unknown=value").is_err());
    }

    #[test]
    fn parse_invalid_line_fails() {
        assert!(ListSettings::parse("invalid line").is_err());
    }

    #[test]
    fn body_format_variations() {
        // Per spec: body_format can be both|plain|html
        let both = ListSettings::parse("body_format=both").unwrap();
        assert_eq!(both.body_format, "both");

        let plain = ListSettings::parse("body_format=plain").unwrap();
        assert_eq!(plain.body_format, "plain");

        let html = ListSettings::parse("body_format=html").unwrap();
        assert_eq!(html.body_format, "html");
    }

    #[test]
    fn delete_after_variations() {
        // Per spec: delete_after can be never|30d|6m|2y
        let never = ListSettings::parse("delete_after=never").unwrap();
        assert_eq!(never.delete_after, "never");

        let days = ListSettings::parse("delete_after=30d").unwrap();
        assert_eq!(days.delete_after, "30d");

        let months = ListSettings::parse("delete_after=6m").unwrap();
        assert_eq!(months.delete_after, "6m");

        let years = ListSettings::parse("delete_after=2y").unwrap();
        assert_eq!(years.delete_after, "2y");
    }

    #[test]
    fn collapse_signatures_variations() {
        // Per spec: collapse_signatures is a boolean
        let true_val = ListSettings::parse("collapse_signatures=true").unwrap();
        assert!(true_val.collapse_signatures);

        let one_val = ListSettings::parse("collapse_signatures=1").unwrap();
        assert!(one_val.collapse_signatures);

        let yes_val = ListSettings::parse("collapse_signatures=yes").unwrap();
        assert!(yes_val.collapse_signatures);

        let false_val = ListSettings::parse("collapse_signatures=false").unwrap();
        assert!(!false_val.collapse_signatures);

        let other_val = ListSettings::parse("collapse_signatures=no").unwrap();
        assert!(!other_val.collapse_signatures);
    }

    #[test]
    fn list_status_variations() {
        // Per spec: list_status can be accepted|rejected|banned
        let accepted = ListSettings::parse("list_status=accepted").unwrap();
        assert_eq!(accepted.list_status, "accepted");

        let rejected = ListSettings::parse("list_status=rejected").unwrap();
        assert_eq!(rejected.list_status, "rejected");

        let banned = ListSettings::parse("list_status=banned").unwrap();
        assert_eq!(banned.list_status, "banned");
    }

    #[test]
    fn settings_accepts_invalid_list_status_values() {
        // Current implementation doesn't validate - just stores the value
        // This test documents current behavior (may want to change to validation)
        let invalid = ListSettings::parse("list_status=invalid_value").unwrap();
        assert_eq!(invalid.list_status, "invalid_value");
    }

    #[test]
    fn settings_accepts_invalid_delete_after_format() {
        // Current implementation doesn't validate - parser handles it separately
        let invalid = ListSettings::parse("delete_after=invalid").unwrap();
        assert_eq!(invalid.delete_after, "invalid");
    }

    #[test]
    fn settings_accepts_invalid_body_format() {
        // Current implementation doesn't validate
        let invalid = ListSettings::parse("body_format=markdown").unwrap();
        assert_eq!(invalid.body_format, "markdown");
    }

    #[test]
    fn settings_with_empty_values() {
        let empty = ListSettings::parse("from=\nreply_to=\nsignature=").unwrap();
        assert_eq!(empty.from, Some("".to_string()));
        assert_eq!(empty.reply_to, Some("".to_string()));
        assert_eq!(empty.signature, Some("".to_string()));
    }

    #[test]
    fn settings_with_whitespace_values() {
        let ws =
            ListSettings::parse("from=  alice@example.org  \nsignature=  ~/sig.txt  ").unwrap();
        // Values are trimmed
        assert_eq!(ws.from, Some("alice@example.org".to_string()));
        assert_eq!(ws.signature, Some("~/sig.txt".to_string()));
    }

    #[test]
    fn settings_with_equals_in_value() {
        let eq = ListSettings::parse("signature=/path/with=equals/file.txt").unwrap();
        assert_eq!(eq.signature, Some("/path/with=equals/file.txt".to_string()));
    }

    #[test]
    fn settings_case_sensitive_keys() {
        // Keys should be case-sensitive (lowercase expected)
        let result = ListSettings::parse("List_Status=accepted");
        assert!(result.is_err()); // Unknown key
    }

    #[test]
    fn settings_duplicate_keys_last_wins() {
        let dup = ListSettings::parse("from=first@example.org\nfrom=second@example.org").unwrap();
        assert_eq!(dup.from, Some("second@example.org".to_string()));
    }

    #[test]
    fn settings_all_defaults() {
        let defaults = ListSettings::default();
        assert_eq!(defaults.list_status, "accepted");
        assert_eq!(defaults.delete_after, "never");
        assert!(defaults.from.is_none());
        assert!(defaults.reply_to.is_none());
        assert!(defaults.signature.is_none());
        assert_eq!(defaults.body_format, "both");
        assert!(defaults.collapse_signatures);
    }

    #[test]
    fn settings_roundtrip_serialization() {
        let settings = ListSettings {
            list_status: "banned".to_string(),
            delete_after: "30d".to_string(),
            from: Some("Team <team@example.org>".to_string()),
            reply_to: Some("list@example.org".to_string()),
            signature: Some("~/sig.txt".to_string()),
            body_format: "plain".to_string(),
            collapse_signatures: false,
        };

        // Serialize to string
        let serialized = format!(
            "list_status={}\ndelete_after={}\nfrom={}\nreply_to={}\nsignature={}\nbody_format={}\ncollapse_signatures={}",
            settings.list_status,
            settings.delete_after,
            settings.from.as_ref().unwrap(),
            settings.reply_to.as_ref().unwrap(),
            settings.signature.as_ref().unwrap(),
            settings.body_format,
            if settings.collapse_signatures {
                "true"
            } else {
                "false"
            }
        );

        // Parse it back
        let parsed = ListSettings::parse(&serialized).unwrap();
        assert_eq!(parsed.list_status, settings.list_status);
        assert_eq!(parsed.delete_after, settings.delete_after);
        assert_eq!(parsed.from, settings.from);
    }
}
