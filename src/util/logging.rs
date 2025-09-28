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
                fs::set_permissions(&logs_dir, perms)?;
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
            fs::set_permissions(&self.inner.path, perms)?;
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

    #[test]
    fn parse_levels() {
        assert_eq!(LogLevel::from_str("off").unwrap(), LogLevel::Off);
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
}
