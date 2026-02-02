use std::{
    fs::{self, File, OpenOptions},
    io::Write,
    path::{Path, PathBuf},
    str::FromStr,
    sync::Arc,
};

use anyhow::Result;
use parking_lot::Mutex;
use serde::{Deserialize, Serialize};
use time::{OffsetDateTime, format_description::well_known::Rfc3339};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum LogLevel {
    Off,
    Minimal,
    VerboseSanitized,
    VerboseFull,
}

impl LogLevel {
    pub fn as_str(self) -> &'static str {
        match self {
            LogLevel::Off => "off",
            LogLevel::Minimal => "minimal",
            LogLevel::VerboseSanitized => "verbose_sanitized",
            LogLevel::VerboseFull => "verbose_full",
        }
    }

    fn allows(self, event: LogLevel) -> bool {
        self != LogLevel::Off && self >= event
    }
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

#[derive(Debug, Clone)]
pub struct Logger {
    inner: Arc<LoggerInner>,
}

#[derive(Debug)]
struct LoggerInner {
    level: LogLevel,
    path: PathBuf,
    file: Mutex<Option<File>>,
}

impl Logger {
    pub fn new(root: impl Into<PathBuf>, level: LogLevel) -> Result<Self> {
        let root = root.into();
        let logs_dir = root.join("logs");
        if level != LogLevel::Off {
            fs::create_dir_all(&logs_dir)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let perms = fs::Permissions::from_mode(0o700);
                // Ignore permission errors on systems that don't support it (e.g., some macOS filesystems)
                let _ = fs::set_permissions(&logs_dir, perms);
            }
        }
        Ok(Self {
            inner: Arc::new(LoggerInner {
                level,
                path: logs_dir.join("owl.log"),
                file: Mutex::new(None),
            }),
        })
    }

    pub fn level(&self) -> LogLevel {
        self.inner.level
    }

    pub fn log(
        &self,
        event_level: LogLevel,
        message: impl AsRef<str>,
        detail: Option<&str>,
    ) -> Result<()> {
        if !self.inner.level.allows(event_level) {
            return Ok(());
        }

        let mut guard = self.inner.file.lock();
        if guard.is_none() {
            *guard = Some(self.create_file()?);
        }

        if let Some(file) = guard.as_mut() {
            let entry = LogEntry::new(event_level, message.as_ref(), detail);
            let line = serde_json::to_string(&entry)?;
            file.write_all(line.as_bytes())?;
            file.write_all(b"\n")?;
            file.flush()?;
        }

        Ok(())
    }

    fn create_file(&self) -> Result<File> {
        let mut options = OpenOptions::new();
        options.create(true).append(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        let file = options.open(&self.inner.path)?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let perms = fs::Permissions::from_mode(0o600);
            // Ignore permission errors on systems that don't support it (e.g., some macOS filesystems)
            let _ = fs::set_permissions(&self.inner.path, perms);
        }
        Ok(file)
    }

    pub fn log_path(&self) -> PathBuf {
        self.inner.path.clone()
    }

    pub fn load_entries(path: &Path) -> Result<Vec<LogEntry>> {
        if !path.exists() {
            return Ok(Vec::new());
        }
        let data = fs::read_to_string(path)?;
        let mut entries = Vec::new();
        for (idx, line) in data.lines().enumerate() {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            let entry: LogEntry = serde_json::from_str(trimmed)
                .map_err(|err| anyhow::anyhow!("failed to parse log line {}: {}", idx + 1, err))?;
            entries.push(entry);
        }
        Ok(entries)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LogEntry {
    pub timestamp: String,
    pub level: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
}

impl LogEntry {
    fn new(level: LogLevel, message: &str, detail: Option<&str>) -> Self {
        let timestamp = OffsetDateTime::now_utc()
            .format(&Rfc3339)
            .unwrap_or_else(|_| "1970-01-01T00:00:00Z".to_string());
        Self {
            timestamp,
            level: level.as_str().to_string(),
            message: message.to_string(),
            detail: detail.map(|d| d.to_string()),
        }
    }

    pub fn format_human(&self) -> String {
        match &self.detail {
            Some(detail) if !detail.is_empty() => format!(
                "[{}] {} {} :: {}",
                self.timestamp, self.level, self.message, detail
            ),
            _ => format!("[{}] {} {}", self.timestamp, self.level, self.message),
        }
    }
}

pub fn tail(entries: &[LogEntry], max: usize) -> &[LogEntry] {
    if entries.len() <= max {
        entries
    } else {
        &entries[entries.len() - max..]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[cfg(unix)]
    use std::os::unix::fs::PermissionsExt;

    #[test]
    fn parse_levels() {
        assert_eq!(LogLevel::from_str("off").unwrap(), LogLevel::Off);
        assert_eq!(
            LogLevel::from_str("verbose_full").unwrap(),
            LogLevel::VerboseFull
        );
        assert_eq!(
            LogLevel::from_str("verbose_sanitized").unwrap(),
            LogLevel::VerboseSanitized
        );
        assert!(LogLevel::from_str("nope").is_err());
    }

    #[test]
    fn off_level_skips_logging() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::Off).unwrap();
        logger
            .log(LogLevel::Minimal, "install", Some("root=/tmp/mail"))
            .unwrap();
        assert!(!logger.log_path().exists());
    }

    #[test]
    fn minimal_level_writes_entries() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();
        logger
            .log(LogLevel::Minimal, "install", Some("root=/tmp/mail"))
            .unwrap();
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].level, "minimal");
        assert!(entries[0].format_human().contains("install"));
    }

    #[test]
    fn as_str_and_level_round_trip() {
        assert_eq!(LogLevel::Off.as_str(), "off");
        assert_eq!(LogLevel::VerboseFull.as_str(), "verbose_full");

        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::VerboseSanitized).unwrap();
        assert_eq!(logger.level(), LogLevel::VerboseSanitized);
    }

    #[test]
    fn verbose_filters_respect_threshold() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();
        logger
            .log(LogLevel::VerboseSanitized, "debug", None)
            .unwrap();
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(entries.is_empty());
    }

    #[test]
    fn verbose_full_includes_detail() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::VerboseFull).unwrap();
        logger
            .log(LogLevel::VerboseFull, "retry", Some("attempt=3"))
            .unwrap();
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].detail.as_deref(), Some("attempt=3"));
        assert!(entries[0].format_human().contains("attempt=3"));
    }

    #[test]
    #[cfg(unix)]
    fn new_logger_sets_strict_permissions() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();
        let logs_dir = dir.path().join("logs");
        let dir_mode = fs::metadata(&logs_dir).unwrap().permissions().mode() & 0o777;
        assert_eq!(dir_mode, 0o700);

        logger
            .log(LogLevel::Minimal, "permission.check", None)
            .unwrap();
        let file_mode = fs::metadata(logger.log_path())
            .unwrap()
            .permissions()
            .mode()
            & 0o777;
        assert_eq!(file_mode, 0o600);
    }

    #[test]
    fn logger_reuses_open_file_between_writes() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();
        logger.log(LogLevel::Minimal, "first", None).unwrap();
        logger.log(LogLevel::Minimal, "second", None).unwrap();
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert_eq!(entries.len(), 2);
    }

    #[test]
    fn load_entries_skips_blank_lines() {
        let dir = tempfile::tempdir().unwrap();
        let log_path = dir.path().join("owl.log");
        let mut file = std::fs::File::create(&log_path).unwrap();
        let entry = LogEntry::new(LogLevel::Minimal, "event", None);
        let line = serde_json::to_string(&entry).unwrap();
        use std::io::Write;
        writeln!(file, "{line}").unwrap();
        writeln!(file).unwrap();
        writeln!(file, "   \t  ").unwrap();
        let entries = Logger::load_entries(&log_path).unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].message, "event");
    }

    #[test]
    fn format_human_without_detail() {
        let entry = LogEntry {
            timestamp: "2024-01-02T03:04:05Z".into(),
            level: "minimal".into(),
            message: "noop".into(),
            detail: None,
        };
        let rendered = entry.format_human();
        assert!(rendered.contains("noop"));
        assert!(!rendered.contains("::"));
    }

    #[test]
    fn tail_returns_suffix() {
        let entries = vec![
            LogEntry::new(LogLevel::Minimal, "a", None),
            LogEntry::new(LogLevel::Minimal, "b", None),
            LogEntry::new(LogLevel::Minimal, "c", None),
        ];
        let slice = tail(&entries, 2);
        assert_eq!(slice.len(), 2);
        assert_eq!(slice[0].message, "b");
        assert_eq!(slice[1].message, "c");
    }

    #[test]
    fn tail_returns_all_when_max_exceeds_len() {
        let entries = vec![LogEntry::new(LogLevel::Minimal, "only", None)];
        let slice = tail(&entries, 5);
        assert_eq!(slice.len(), 1);
        assert_eq!(slice[0].message, "only");
    }

    #[test]
    fn tail_handles_zero_max() {
        let entries = vec![
            LogEntry::new(LogLevel::Minimal, "a", None),
            LogEntry::new(LogLevel::Minimal, "b", None),
        ];
        let slice = tail(&entries, 0);
        assert!(slice.is_empty());
    }

    #[test]
    fn load_entries_missing_file_returns_empty() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("absent.log");
        let entries = Logger::load_entries(&path).unwrap();
        assert!(entries.is_empty());
    }

    #[test]
    fn load_entries_reports_json_errors() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("owl.log");
        fs::write(&path, "{not json}\n").unwrap();
        let err = Logger::load_entries(&path).unwrap_err();
        assert!(err.to_string().contains("failed to parse log line 1"));
    }

    #[test]
    fn log_level_spec_values() {
        // Per spec: off | minimal | verbose_sanitized | verbose_full
        assert_eq!(LogLevel::from_str("off").unwrap(), LogLevel::Off);
        assert_eq!(LogLevel::from_str("minimal").unwrap(), LogLevel::Minimal);
        assert_eq!(
            LogLevel::from_str("verbose_sanitized").unwrap(),
            LogLevel::VerboseSanitized
        );
        assert_eq!(
            LogLevel::from_str("verbose_full").unwrap(),
            LogLevel::VerboseFull
        );
    }

    #[test]
    fn log_level_ordering() {
        // Ordering: Off < Minimal < VerboseSanitized < VerboseFull
        assert!(LogLevel::Off < LogLevel::Minimal);
        assert!(LogLevel::Minimal < LogLevel::VerboseSanitized);
        assert!(LogLevel::VerboseSanitized < LogLevel::VerboseFull);
    }

    #[test]
    fn log_level_allows_checks() {
        // Off allows nothing
        assert!(!LogLevel::Off.allows(LogLevel::Minimal));
        assert!(!LogLevel::Off.allows(LogLevel::VerboseFull));

        // Minimal allows minimal, not verbose
        assert!(LogLevel::Minimal.allows(LogLevel::Minimal));
        assert!(!LogLevel::Minimal.allows(LogLevel::VerboseSanitized));
        assert!(!LogLevel::Minimal.allows(LogLevel::VerboseFull));

        // VerboseSanitized allows minimal and sanitized, not full
        assert!(LogLevel::VerboseSanitized.allows(LogLevel::Minimal));
        assert!(LogLevel::VerboseSanitized.allows(LogLevel::VerboseSanitized));
        assert!(!LogLevel::VerboseSanitized.allows(LogLevel::VerboseFull));

        // VerboseFull allows all
        assert!(LogLevel::VerboseFull.allows(LogLevel::Minimal));
        assert!(LogLevel::VerboseFull.allows(LogLevel::VerboseSanitized));
        assert!(LogLevel::VerboseFull.allows(LogLevel::VerboseFull));
    }

    #[test]
    fn minimal_level_filters_verbose_events() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();

        // Minimal event should be logged
        logger
            .log(LogLevel::Minimal, "minimal_event", None)
            .unwrap();

        // Verbose events should be filtered
        logger
            .log(LogLevel::VerboseSanitized, "verbose_sanitized_event", None)
            .unwrap();
        logger
            .log(LogLevel::VerboseFull, "verbose_full_event", None)
            .unwrap();

        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].message, "minimal_event");
    }

    #[test]
    fn verbose_sanitized_includes_minimal() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::VerboseSanitized).unwrap();

        logger.log(LogLevel::Minimal, "minimal", None).unwrap();
        logger
            .log(LogLevel::VerboseSanitized, "sanitized", None)
            .unwrap();
        logger.log(LogLevel::VerboseFull, "full", None).unwrap();

        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].message, "minimal");
        assert_eq!(entries[1].message, "sanitized");
    }

    #[test]
    fn verbose_full_includes_all_levels() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::VerboseFull).unwrap();

        logger.log(LogLevel::Minimal, "minimal", None).unwrap();
        logger
            .log(LogLevel::VerboseSanitized, "sanitized", None)
            .unwrap();
        logger.log(LogLevel::VerboseFull, "full", None).unwrap();

        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert_eq!(entries.len(), 3);
    }

    #[test]
    fn log_entry_format_with_detail() {
        let entry = LogEntry::new(
            LogLevel::VerboseFull,
            "outbox_retry",
            Some("attempt=3 next=5m"),
        );
        let formatted = entry.format_human();

        assert!(formatted.contains("outbox_retry"));
        assert!(formatted.contains("attempt=3 next=5m"));
        assert!(formatted.contains("::"));
    }

    #[test]
    fn log_entry_format_without_detail() {
        let entry = LogEntry::new(LogLevel::Minimal, "simple_event", None);
        let formatted = entry.format_human();

        assert!(formatted.contains("simple_event"));
        assert!(!formatted.contains("::"));
    }

    #[test]
    fn log_entry_empty_detail_omitted() {
        let entry = LogEntry::new(LogLevel::Minimal, "event", Some(""));
        let formatted = entry.format_human();

        // Empty detail should be omitted (no :: separator)
        assert!(!formatted.contains("::"));
    }

    #[test]
    fn logger_creates_logs_directory() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();

        let logs_dir = dir.path().join("logs");
        assert!(logs_dir.exists());
        assert!(logs_dir.is_dir());

        // Log path should be inside logs dir
        assert!(logger.log_path().starts_with(&logs_dir));
    }

    #[test]
    fn off_level_does_not_create_logs_directory() {
        let dir = tempfile::tempdir().unwrap();
        let _logger = Logger::new(dir.path(), LogLevel::Off).unwrap();

        let logs_dir = dir.path().join("logs");
        // Off level should not create logs directory
        assert!(!logs_dir.exists());
    }
}
