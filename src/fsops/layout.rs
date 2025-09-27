use std::fs;
use std::path::{Path, PathBuf};

use anyhow::Result;

#[derive(Debug, Clone)]
pub struct MailLayout {
    root: PathBuf,
}

impl MailLayout {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    pub fn quarantine(&self) -> PathBuf {
        self.root.join("quarantine")
    }

    pub fn accepted(&self) -> PathBuf {
        self.root.join("accepted")
    }

    pub fn spam(&self) -> PathBuf {
        self.root.join("spam")
    }

    pub fn banned(&self) -> PathBuf {
        self.root.join("banned")
    }

    pub fn drafts(&self) -> PathBuf {
        self.root.join("drafts")
    }

    pub fn outbox(&self) -> PathBuf {
        self.root.join("outbox")
    }

    pub fn sent(&self) -> PathBuf {
        self.root.join("sent")
    }

    pub fn logs_dir(&self) -> PathBuf {
        self.root.join("logs")
    }

    pub fn log_file(&self) -> PathBuf {
        self.logs_dir().join("owl.log")
    }

    pub fn attachments(&self, list: &str) -> PathBuf {
        self.root.join(list).join("attachments")
    }

    pub fn ensure(&self) -> Result<()> {
        fs::create_dir_all(&self.root)?;
        fs::create_dir_all(self.quarantine())?;
        for list in ["accepted", "spam", "banned"] {
            self.ensure_list(list)?;
        }
        for leaf in ["drafts", "outbox", "sent", "logs", "dkim"] {
            fs::create_dir_all(self.root.join(leaf))?;
        }
        Ok(())
    }

    pub fn dkim_dir(&self) -> PathBuf {
        self.root.join("dkim")
    }

    pub fn dkim_private_key(&self, selector: &str) -> PathBuf {
        self.dkim_dir().join(format!("{selector}.private"))
    }

    pub fn dkim_public_key(&self, selector: &str) -> PathBuf {
        self.dkim_dir().join(format!("{selector}.public"))
    }

    pub fn dkim_dns_record(&self, selector: &str) -> PathBuf {
        self.dkim_dir().join(format!("{selector}.dns"))
    }

    fn ensure_list(&self, list: &str) -> Result<()> {
        let dir = self.root.join(list);
        fs::create_dir_all(&dir)?;
        fs::create_dir_all(dir.join("attachments"))?;
        let rules = dir.join(".rules");
        if !rules.exists() {
            fs::write(&rules, b"# owl routing rules\n")?;
        }
        let settings = dir.join(".settings");
        if !settings.exists() {
            fs::write(&settings, default_settings(list))?;
        }
        Ok(())
    }
}

fn default_settings(list: &str) -> Vec<u8> {
    let status = match list {
        "banned" => "banned",
        "spam" => "rejected",
        _ => "accepted",
    };
    format!(
        "list_status={status}\ndelete_after=never\nfrom=\nreply_to=\nsignature=\nbody_format=both\ncollapse_signatures=true\n"
    )
    .into_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn layout_paths() {
        let layout = MailLayout::new("/tmp/mail");
        assert_eq!(layout.quarantine(), Path::new("/tmp/mail/quarantine"));
        assert_eq!(
            layout.attachments("accepted"),
            Path::new("/tmp/mail/accepted/attachments")
        );
        assert_eq!(layout.accepted(), Path::new("/tmp/mail/accepted"));
        assert_eq!(layout.spam(), Path::new("/tmp/mail/spam"));
        assert_eq!(layout.banned(), Path::new("/tmp/mail/banned"));
        assert_eq!(layout.drafts(), Path::new("/tmp/mail/drafts"));
        assert_eq!(layout.outbox(), Path::new("/tmp/mail/outbox"));
        assert_eq!(layout.sent(), Path::new("/tmp/mail/sent"));
        assert_eq!(layout.logs_dir(), Path::new("/tmp/mail/logs"));
        assert_eq!(layout.log_file(), Path::new("/tmp/mail/logs/owl.log"));
        assert_eq!(layout.dkim_dir(), Path::new("/tmp/mail/dkim"));
        assert_eq!(
            layout.dkim_private_key("mail"),
            Path::new("/tmp/mail/dkim/mail.private")
        );
        assert_eq!(
            layout.dkim_public_key("mail"),
            Path::new("/tmp/mail/dkim/mail.public")
        );
        assert_eq!(
            layout.dkim_dns_record("mail"),
            Path::new("/tmp/mail/dkim/mail.dns")
        );
        assert_eq!(layout.root(), Path::new("/tmp/mail"));
    }

    #[test]
    fn ensure_creates_structure_once() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        for leaf in [
            "quarantine",
            "accepted",
            "spam",
            "banned",
            "drafts",
            "outbox",
            "sent",
            "logs",
            "dkim",
        ] {
            assert!(dir.path().join(leaf).exists(), "{leaf} missing");
        }
        let settings_path = dir.path().join("banned/.settings");
        fs::write(&settings_path, "list_status=banned\ncustom=true\n").unwrap();
        layout.ensure().unwrap();
        let after = fs::read_to_string(&settings_path).unwrap();
        assert_eq!(after, "list_status=banned\ncustom=true\n");
        assert!(dir.path().join("accepted/.rules").exists());
        let accepted_settings = fs::read_to_string(dir.path().join("accepted/.settings")).unwrap();
        assert!(accepted_settings.contains("list_status=accepted"));
        let spam_settings = fs::read_to_string(dir.path().join("spam/.settings")).unwrap();
        assert!(spam_settings.contains("list_status=rejected"));
    }
}
