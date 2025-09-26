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
}
