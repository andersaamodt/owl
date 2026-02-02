use std::{collections::HashMap, fs, path::Path, str::FromStr};

use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize, PartialEq)]
pub struct EnvConfig {
    pub dmarc_policy: String,
    pub dkim_selector: String,
    pub letsencrypt_method: String,
    pub keep_plus_tags: bool,
    pub max_size_quarantine: String,
    pub max_size_approved_default: String,
    pub contacts_dir: String,
    pub logging: String,
    pub render_mode: String,
    pub load_external_per_message: bool,
    pub retry_backoff: Vec<String>,
    #[serde(default)]
    pub smtp_host: Option<String>,
    #[serde(default)]
    pub smtp_port: u16,
    #[serde(default)]
    pub smtp_username: Option<String>,
    #[serde(default)]
    pub smtp_password: Option<String>,
    #[serde(default)]
    pub smtp_starttls: bool,
}

impl Default for EnvConfig {
    fn default() -> Self {
        Self {
            dmarc_policy: "none".into(),
            dkim_selector: "mail".into(),
            letsencrypt_method: "http".into(),
            keep_plus_tags: false,
            max_size_quarantine: "25M".into(),
            max_size_approved_default: "50M".into(),
            contacts_dir: "/home/pi/contacts".into(),
            logging: "minimal".into(),
            render_mode: "strict".into(),
            load_external_per_message: true,
            retry_backoff: vec!["1m".into(), "5m".into(), "15m".into(), "1h".into()],
            smtp_host: Some("127.0.0.1".into()),
            smtp_port: 25,
            smtp_username: None,
            smtp_password: None,
            smtp_starttls: true,
        }
    }
}

impl EnvConfig {
    pub fn from_file(path: &Path) -> Result<Self> {
        let data =
            fs::read_to_string(path).with_context(|| format!("reading {}", path.display()))?;
        data.parse()
    }

    pub fn parse_env(data: &str) -> Result<Self> {
        let mut map = HashMap::new();
        for (idx, line) in data.lines().enumerate() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            let Some((key, value)) = line.split_once('=') else {
                anyhow::bail!("invalid line {}: {}", idx + 1, line);
            };
            map.insert(key.trim().to_ascii_lowercase(), value.trim().to_string());
        }
        Ok(Self {
            dmarc_policy: map
                .get("dmarc_policy")
                .cloned()
                .unwrap_or_else(|| Self::default().dmarc_policy),
            dkim_selector: map
                .get("dkim_selector")
                .cloned()
                .unwrap_or_else(|| Self::default().dkim_selector),
            letsencrypt_method: map
                .get("letsencrypt_method")
                .cloned()
                .unwrap_or_else(|| Self::default().letsencrypt_method),
            keep_plus_tags: map
                .get("keep_plus_tags")
                .map(|v| matches!(v.as_str(), "true" | "1" | "yes"))
                .unwrap_or_else(|| Self::default().keep_plus_tags),
            max_size_quarantine: map
                .get("max_size_quarantine")
                .cloned()
                .unwrap_or_else(|| Self::default().max_size_quarantine),
            max_size_approved_default: map
                .get("max_size_approved_default")
                .cloned()
                .unwrap_or_else(|| Self::default().max_size_approved_default),
            contacts_dir: map
                .get("contacts_dir")
                .cloned()
                .unwrap_or_else(|| Self::default().contacts_dir),
            logging: map
                .get("logging")
                .cloned()
                .unwrap_or_else(|| Self::default().logging),
            render_mode: map
                .get("render_mode")
                .cloned()
                .unwrap_or_else(|| Self::default().render_mode),
            load_external_per_message: map
                .get("load_external_per_message")
                .map(|v| matches!(v.as_str(), "true" | "1" | "yes"))
                .unwrap_or_else(|| Self::default().load_external_per_message),
            retry_backoff: map
                .get("retry_backoff")
                .map(|v| {
                    v.split(',')
                        .map(|s| s.trim().to_string())
                        .filter(|s| !s.is_empty())
                        .collect()
                })
                .filter(|v: &Vec<String>| !v.is_empty())
                .unwrap_or_else(|| Self::default().retry_backoff),
            smtp_host: map.get("smtp_host").cloned(),
            smtp_port: map
                .get("smtp_port")
                .and_then(|v| v.parse::<u16>().ok())
                .unwrap_or_else(|| Self::default().smtp_port),
            smtp_username: map.get("smtp_username").cloned(),
            smtp_password: map.get("smtp_password").cloned(),
            smtp_starttls: map
                .get("smtp_starttls")
                .map(|v| matches!(v.as_str(), "true" | "1" | "yes"))
                .unwrap_or_else(|| Self::default().smtp_starttls),
        })
    }

    pub fn to_env_string(&self) -> String {
        format!(
            concat!(
                "dmarc_policy={}\n",
                "dkim_selector={}\n",
                "letsencrypt_method={}\n",
                "keep_plus_tags={}\n",
                "max_size_quarantine={}\n",
                "max_size_approved_default={}\n",
                "contacts_dir={}\n",
                "logging={}\n",
                "render_mode={}\n",
                "load_external_per_message={}\n",
                "retry_backoff={}\n",
                "smtp_host={}\n",
                "smtp_port={}\n",
                "smtp_starttls={}\n"
            ),
            self.dmarc_policy,
            self.dkim_selector,
            self.letsencrypt_method,
            bool_to_env(self.keep_plus_tags),
            self.max_size_quarantine,
            self.max_size_approved_default,
            self.contacts_dir,
            self.logging,
            self.render_mode,
            bool_to_env(self.load_external_per_message),
            self.retry_backoff.join(","),
            self.smtp_host.clone().unwrap_or_else(|| "127.0.0.1".into()),
            self.smtp_port,
            bool_to_env(self.smtp_starttls)
        )
    }
}

impl FromStr for EnvConfig {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::parse_env(s)
    }
}

fn bool_to_env(value: bool) -> &'static str {
    if value { "true" } else { "false" }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_defaults() {
        let cfg = EnvConfig::default();
        assert_eq!(cfg.retry_backoff.len(), 4);
        assert_eq!(cfg.smtp_port, 25);
        assert!(cfg.smtp_starttls);
    }

    #[test]
    fn parse_ignores_comments_and_blanks() {
        let cfg: EnvConfig = "# comment\n\nlogging=verbose_full\n".parse().unwrap();
        assert_eq!(cfg.logging, "verbose_full");
    }

    #[test]
    fn parse_custom() {
        let cfg: EnvConfig = "keep_plus_tags=true\nretry_backoff=1m,2m\n"
            .parse()
            .unwrap();
        assert!(cfg.keep_plus_tags);
        assert_eq!(cfg.retry_backoff, vec!["1m", "2m"]);
    }

    #[test]
    fn parse_all_fields() {
        let cfg: EnvConfig = "dmarc_policy=quarantine\ndkim_selector=owl\nletsencrypt_method=dns\nmax_size_quarantine=10M\nmax_size_approved_default=20M\ncontacts_dir=/tmp/contacts\nlogging=verbose_full\nrender_mode=moderate\nload_external_per_message=false\nretry_backoff=1m\nsmtp_host=smtp.example.org\nsmtp_port=2525\nsmtp_username=alice\nsmtp_password=secret\nsmtp_starttls=false\n"
            .parse()
            .unwrap();
        assert_eq!(cfg.dmarc_policy, "quarantine");
        assert_eq!(cfg.dkim_selector, "owl");
        assert_eq!(cfg.letsencrypt_method, "dns");
        assert_eq!(cfg.max_size_quarantine, "10M");
        assert_eq!(cfg.max_size_approved_default, "20M");
        assert_eq!(cfg.contacts_dir, "/tmp/contacts");
        assert_eq!(cfg.logging, "verbose_full");
        assert_eq!(cfg.render_mode, "moderate");
        assert!(!cfg.load_external_per_message);
        assert_eq!(cfg.retry_backoff, vec!["1m"]);
        assert_eq!(cfg.smtp_host.as_deref(), Some("smtp.example.org"));
        assert_eq!(cfg.smtp_port, 2525);
        assert_eq!(cfg.smtp_username.as_deref(), Some("alice"));
        assert_eq!(cfg.smtp_password.as_deref(), Some("secret"));
        assert!(!cfg.smtp_starttls);
    }

    #[test]
    fn parse_from_file_roundtrip() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("env");
        std::fs::write(&path, "logging=off\n").unwrap();
        let cfg = EnvConfig::from_file(&path).unwrap();
        assert_eq!(cfg.logging, "off");
    }

    #[test]
    fn parse_invalid_line_fails() {
        assert!("invalid".parse::<EnvConfig>().is_err());
    }

    #[test]
    fn serialize_to_env() {
        let cfg = EnvConfig {
            keep_plus_tags: true,
            ..EnvConfig::default()
        };
        let rendered = cfg.to_env_string();
        assert!(rendered.contains("keep_plus_tags=true"));
        assert!(rendered.contains("smtp_host="));
        assert!(rendered.contains("smtp_port="));
    }

    #[test]
    fn from_file_missing_reports_context() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("missing.env");
        let err = EnvConfig::from_file(&path).unwrap_err();
        assert!(err.to_string().contains("reading"));
    }

    #[test]
    fn to_env_string_defaults_missing_host() {
        let cfg = EnvConfig {
            smtp_host: None,
            ..EnvConfig::default()
        };
        let env = cfg.to_env_string();
        assert!(env.contains("smtp_host=127.0.0.1"));
    }

    #[test]
    fn retry_backoff_spec_default() {
        // Per spec: default is "1m,5m,15m,1h"
        let cfg = EnvConfig::default();
        assert_eq!(cfg.retry_backoff, vec!["1m", "5m", "15m", "1h"]);
    }

    #[test]
    fn retry_backoff_custom_parsing() {
        let cfg: EnvConfig = "retry_backoff=30s,2m,10m,1h,6h\n".parse().unwrap();
        assert_eq!(cfg.retry_backoff, vec!["30s", "2m", "10m", "1h", "6h"]);
    }

    #[test]
    fn retry_backoff_whitespace_trimmed() {
        let cfg: EnvConfig = "retry_backoff= 1m , 5m , 15m \n".parse().unwrap();
        assert_eq!(cfg.retry_backoff, vec!["1m", "5m", "15m"]);
    }

    #[test]
    fn retry_backoff_empty_entries_filtered() {
        // Empty entries should be filtered out
        let cfg: EnvConfig = "retry_backoff=1m,,5m,\n".parse().unwrap();
        assert_eq!(cfg.retry_backoff, vec!["1m", "5m"]);
    }

    #[test]
    fn retry_backoff_empty_list_uses_default() {
        // Empty list should fall back to default
        let cfg: EnvConfig = "retry_backoff=\n".parse().unwrap();
        assert_eq!(cfg.retry_backoff, vec!["1m", "5m", "15m", "1h"]);

        let cfg2: EnvConfig = "retry_backoff=,,,\n".parse().unwrap();
        assert_eq!(cfg2.retry_backoff, vec!["1m", "5m", "15m", "1h"]);
    }

    #[test]
    fn max_size_quarantine_spec_default() {
        // Per spec: quarantine cap is 25M
        let cfg = EnvConfig::default();
        assert_eq!(cfg.max_size_quarantine, "25M");
    }

    #[test]
    fn max_size_approved_spec_default() {
        // Per spec: approved default cap is 50M
        let cfg = EnvConfig::default();
        assert_eq!(cfg.max_size_approved_default, "50M");
    }

    #[test]
    fn max_size_custom_values() {
        let cfg: EnvConfig = "max_size_quarantine=10M\nmax_size_approved_default=100M\n"
            .parse()
            .unwrap();
        assert_eq!(cfg.max_size_quarantine, "10M");
        assert_eq!(cfg.max_size_approved_default, "100M");
    }

    #[test]
    fn logging_levels_spec_values() {
        // Per spec: off | minimal | verbose_sanitized | verbose_full
        let off: EnvConfig = "logging=off\n".parse().unwrap();
        assert_eq!(off.logging, "off");

        let minimal: EnvConfig = "logging=minimal\n".parse().unwrap();
        assert_eq!(minimal.logging, "minimal");

        let sanitized: EnvConfig = "logging=verbose_sanitized\n".parse().unwrap();
        assert_eq!(sanitized.logging, "verbose_sanitized");

        let full: EnvConfig = "logging=verbose_full\n".parse().unwrap();
        assert_eq!(full.logging, "verbose_full");
    }

    #[test]
    fn render_mode_spec_values() {
        // Per spec: strict | moderate
        let strict: EnvConfig = "render_mode=strict\n".parse().unwrap();
        assert_eq!(strict.render_mode, "strict");

        let moderate: EnvConfig = "render_mode=moderate\n".parse().unwrap();
        assert_eq!(moderate.render_mode, "moderate");
    }

    #[test]
    fn keep_plus_tags_boolean_variations() {
        // Test all truthy values
        let t1: EnvConfig = "keep_plus_tags=true\n".parse().unwrap();
        assert!(t1.keep_plus_tags);

        let t2: EnvConfig = "keep_plus_tags=1\n".parse().unwrap();
        assert!(t2.keep_plus_tags);

        let t3: EnvConfig = "keep_plus_tags=yes\n".parse().unwrap();
        assert!(t3.keep_plus_tags);

        // Test falsy values
        let f1: EnvConfig = "keep_plus_tags=false\n".parse().unwrap();
        assert!(!f1.keep_plus_tags);

        let f2: EnvConfig = "keep_plus_tags=0\n".parse().unwrap();
        assert!(!f2.keep_plus_tags);

        let f3: EnvConfig = "keep_plus_tags=no\n".parse().unwrap();
        assert!(!f3.keep_plus_tags);
    }

    #[test]
    fn smtp_starttls_boolean_variations() {
        let t: EnvConfig = "smtp_starttls=true\n".parse().unwrap();
        assert!(t.smtp_starttls);

        let f: EnvConfig = "smtp_starttls=false\n".parse().unwrap();
        assert!(!f.smtp_starttls);
    }

    #[test]
    fn load_external_boolean_variations() {
        let t: EnvConfig = "load_external_per_message=true\n".parse().unwrap();
        assert!(t.load_external_per_message);

        let f: EnvConfig = "load_external_per_message=false\n".parse().unwrap();
        assert!(!f.load_external_per_message);
    }

    #[test]
    fn smtp_port_custom_value() {
        let cfg: EnvConfig = "smtp_port=587\n".parse().unwrap();
        assert_eq!(cfg.smtp_port, 587);
    }

    #[test]
    fn smtp_port_invalid_uses_default() {
        let cfg: EnvConfig = "smtp_port=invalid\n".parse().unwrap();
        assert_eq!(cfg.smtp_port, 25); // default
    }

    #[test]
    fn dmarc_policy_spec_values() {
        // Common DMARC policy values
        let none: EnvConfig = "dmarc_policy=none\n".parse().unwrap();
        assert_eq!(none.dmarc_policy, "none");

        let quarantine: EnvConfig = "dmarc_policy=quarantine\n".parse().unwrap();
        assert_eq!(quarantine.dmarc_policy, "quarantine");

        let reject: EnvConfig = "dmarc_policy=reject\n".parse().unwrap();
        assert_eq!(reject.dmarc_policy, "reject");
    }

    #[test]
    fn case_insensitive_keys() {
        // Keys should be lowercased
        let cfg: EnvConfig = "LOGGING=off\nLogging=verbose_full\n".parse().unwrap();
        // Last value wins
        assert_eq!(cfg.logging, "verbose_full");
    }

    #[test]
    fn whitespace_in_values_preserved() {
        let cfg: EnvConfig = "contacts_dir= /home/pi/contacts \n".parse().unwrap();
        assert_eq!(cfg.contacts_dir, "/home/pi/contacts");
    }

    #[test]
    fn empty_config_uses_defaults() {
        let cfg: EnvConfig = "".parse().unwrap();
        assert_eq!(cfg.dmarc_policy, "none");
        assert_eq!(cfg.dkim_selector, "mail");
        assert_eq!(cfg.max_size_quarantine, "25M");
        assert_eq!(cfg.logging, "minimal");
        assert!(!cfg.keep_plus_tags);
    }

    #[test]
    fn config_with_only_comments() {
        let cfg: EnvConfig = "# comment 1\n# comment 2\n".parse().unwrap();
        // Should match defaults except for smtp_host which is Some in default but not parsed
        assert_eq!(cfg.dmarc_policy, EnvConfig::default().dmarc_policy);
        assert_eq!(cfg.logging, EnvConfig::default().logging);
        assert_eq!(cfg.keep_plus_tags, EnvConfig::default().keep_plus_tags);
        // smtp_host is None when parsed from empty config
        assert_eq!(cfg.smtp_host, None);
    }

    #[test]
    fn invalid_line_without_equals() {
        let result: Result<EnvConfig, _> = "invalid_line".parse();
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("invalid line"));
    }

    #[test]
    fn multiple_equals_in_value() {
        // Value can contain = signs
        let cfg: EnvConfig = "smtp_password=pass=word=123\n".parse().unwrap();
        assert_eq!(cfg.smtp_password, Some("pass=word=123".to_string()));
    }

    #[test]
    fn smtp_optional_fields() {
        let cfg: EnvConfig = "smtp_host=mail.example.org\nsmtp_username=user\n"
            .parse()
            .unwrap();
        assert_eq!(cfg.smtp_host, Some("mail.example.org".to_string()));
        assert_eq!(cfg.smtp_username, Some("user".to_string()));
        assert_eq!(cfg.smtp_password, None); // Not set
    }

    #[test]
    fn smtp_port_defaults_to_25() {
        let cfg: EnvConfig = "".parse().unwrap();
        assert_eq!(cfg.smtp_port, 25);
    }

    #[test]
    fn empty_value_for_optional_string() {
        // Empty value should set Some("")
        let cfg: EnvConfig = "smtp_host=\n".parse().unwrap();
        assert_eq!(cfg.smtp_host, Some("".to_string()));
    }

    #[test]
    fn retry_backoff_empty_list() {
        // If not specified, uses default
        let cfg: EnvConfig = "".parse().unwrap();
        assert_eq!(cfg.retry_backoff, vec!["1m", "5m", "15m", "1h"]);
    }

    #[test]
    fn retry_backoff_single_value() {
        let cfg: EnvConfig = "retry_backoff=30s\n".parse().unwrap();
        assert_eq!(cfg.retry_backoff, vec!["30s"]);
    }

    #[test]
    fn retry_backoff_custom_values() {
        let cfg: EnvConfig = "retry_backoff=1m,10m,1h,6h\n".parse().unwrap();
        assert_eq!(cfg.retry_backoff, vec!["1m", "10m", "1h", "6h"]);
    }

    #[test]
    fn letsencrypt_method_variations() {
        let http: EnvConfig = "letsencrypt_method=http\n".parse().unwrap();
        assert_eq!(http.letsencrypt_method, "http");

        let dns: EnvConfig = "letsencrypt_method=dns\n".parse().unwrap();
        assert_eq!(dns.letsencrypt_method, "dns");
    }

    #[test]
    fn from_file_with_tempfile() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join(".env");
        std::fs::write(&path, "logging=off\nkeep_plus_tags=true\n").unwrap();

        let cfg = EnvConfig::from_file(&path).unwrap();
        assert_eq!(cfg.logging, "off");
        assert!(cfg.keep_plus_tags);
    }

    #[test]
    fn from_file_missing_returns_error() {
        let path = Path::new("/nonexistent/path/.env");
        let result = EnvConfig::from_file(path);
        assert!(result.is_err());
    }

    #[test]
    fn config_clone_equals_original() {
        let cfg = EnvConfig::default();
        let cloned = cfg.clone();
        assert_eq!(cfg, cloned);
    }

    #[test]
    fn config_debug_format() {
        let cfg = EnvConfig::default();
        let debug = format!("{:?}", cfg);
        assert!(debug.contains("EnvConfig"));
        assert!(debug.contains("dmarc_policy"));
    }
}
