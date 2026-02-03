use std::fs;
use std::path::{Path, PathBuf};

use anyhow::Result;

use super::io_atom::create_dir_all;

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
        create_dir_all(&self.root)?;
        create_dir_all(&self.quarantine())?;
        for list in ["accepted", "spam", "banned"] {
            self.ensure_list(list)?;
        }
        for leaf in ["drafts", "outbox", "sent", "logs", "dkim"] {
            create_dir_all(&self.root.join(leaf))?;
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
        create_dir_all(&dir)?;
        create_dir_all(&dir.join("attachments"))?;
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

    #[test]
    fn spec_on_disk_layout_structure() {
        // Per spec: verify exact directory structure
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        // Per spec section 1: all required directories exist
        let root = dir.path();
        assert!(root.join("quarantine").is_dir());
        assert!(root.join("accepted").is_dir());
        assert!(root.join("spam").is_dir());
        assert!(root.join("banned").is_dir());
        assert!(root.join("drafts").is_dir());
        assert!(root.join("outbox").is_dir());
        assert!(root.join("sent").is_dir());
        assert!(root.join("logs").is_dir());
    }

    #[test]
    fn spec_quarantine_has_no_rules_or_settings() {
        // Per spec: quarantine has no .rules or .settings
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let quarantine = dir.path().join("quarantine");
        assert!(!quarantine.join(".rules").exists());
        assert!(!quarantine.join(".settings").exists());
    }

    #[test]
    fn spec_lists_have_rules_and_settings() {
        // Per spec: accepted, spam, banned have .rules and .settings
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        for list in ["accepted", "spam", "banned"] {
            let list_dir = dir.path().join(list);
            assert!(list_dir.join(".rules").exists(), "{list} missing .rules");
            assert!(
                list_dir.join(".settings").exists(),
                "{list} missing .settings"
            );
        }
    }

    #[test]
    fn spec_lists_have_attachments_subdirectory() {
        // Per spec: accepted, spam, banned have attachments/ subdirectory
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        for list in ["accepted", "spam", "banned"] {
            let attachments = dir.path().join(list).join("attachments");
            assert!(attachments.is_dir(), "{list} missing attachments/");
        }
    }

    #[test]
    fn spec_default_settings_per_list() {
        // Per spec: different defaults per list
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let accepted = fs::read_to_string(dir.path().join("accepted/.settings")).unwrap();
        assert!(accepted.contains("list_status=accepted"));

        let spam = fs::read_to_string(dir.path().join("spam/.settings")).unwrap();
        assert!(spam.contains("list_status=rejected"));

        let banned = fs::read_to_string(dir.path().join("banned/.settings")).unwrap();
        assert!(banned.contains("list_status=banned"));
    }

    #[test]
    fn spec_dkim_directory_structure() {
        // Per spec: DKIM keys stored in dkim/ directory
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        assert!(dir.path().join("dkim").is_dir());

        // Check path generation for selector "mail"
        assert_eq!(
            layout.dkim_private_key("mail"),
            dir.path().join("dkim/mail.private")
        );
        assert_eq!(
            layout.dkim_public_key("mail"),
            dir.path().join("dkim/mail.public")
        );
        assert_eq!(
            layout.dkim_dns_record("mail"),
            dir.path().join("dkim/mail.dns")
        );
    }

    #[test]
    fn ensure_idempotent() {
        // Running ensure() multiple times should be safe
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());

        layout.ensure().unwrap();
        layout.ensure().unwrap();
        layout.ensure().unwrap();

        // All directories should still exist
        assert!(dir.path().join("quarantine").is_dir());
        assert!(dir.path().join("accepted").is_dir());
    }

    #[test]
    fn default_settings_include_all_fields() {
        // Default settings should include all required fields
        let settings = String::from_utf8(default_settings("accepted")).unwrap();

        assert!(settings.contains("list_status="));
        assert!(settings.contains("delete_after="));
        assert!(settings.contains("from="));
        assert!(settings.contains("reply_to="));
        assert!(settings.contains("signature="));
        assert!(settings.contains("body_format="));
        assert!(settings.contains("collapse_signatures="));
    }

    #[test]
    fn layout_clone() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        let cloned = layout.clone();

        assert_eq!(layout.root(), cloned.root());
        assert_eq!(layout.quarantine(), cloned.quarantine());
    }

    #[test]
    fn layout_debug_format() {
        let layout = MailLayout::new("/tmp/mail");
        let debug = format!("{:?}", layout);
        assert!(debug.contains("MailLayout"));
    }

    #[test]
    fn attachments_path_for_each_list() {
        let layout = MailLayout::new("/tmp/mail");

        assert_eq!(
            layout.attachments("accepted"),
            PathBuf::from("/tmp/mail/accepted/attachments")
        );
        assert_eq!(
            layout.attachments("spam"),
            PathBuf::from("/tmp/mail/spam/attachments")
        );
        assert_eq!(
            layout.attachments("banned"),
            PathBuf::from("/tmp/mail/banned/attachments")
        );
    }

    #[test]
    fn ensure_creates_all_directories() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        // Check all required directories exist
        assert!(layout.quarantine().is_dir());
        assert!(layout.accepted().is_dir());
        assert!(layout.spam().is_dir());
        assert!(layout.banned().is_dir());
        assert!(layout.drafts().is_dir());
        assert!(layout.outbox().is_dir());
        assert!(layout.sent().is_dir());
        assert!(layout.logs_dir().is_dir());
        assert!(layout.dkim_dir().is_dir());
    }

    #[test]
    fn ensure_creates_rules_and_settings_files() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        // Check that .rules and .settings files are created
        for list in ["accepted", "spam", "banned"] {
            let list_dir = dir.path().join(list);
            assert!(list_dir.join(".rules").is_file());
            assert!(list_dir.join(".settings").is_file());
        }
    }

    #[test]
    fn ensure_does_not_overwrite_existing_rules() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());

        // Create initial structure
        layout.ensure().unwrap();

        // Modify .rules file
        let rules_path = layout.accepted().join(".rules");
        fs::write(&rules_path, "custom rule\n").unwrap();

        // Run ensure again
        layout.ensure().unwrap();

        // Custom content should be preserved
        let content = fs::read_to_string(&rules_path).unwrap();
        assert_eq!(content, "custom rule\n");
    }

    #[test]
    fn dkim_selector_with_different_names() {
        let layout = MailLayout::new("/tmp/mail");

        assert_eq!(
            layout.dkim_private_key("mail"),
            PathBuf::from("/tmp/mail/dkim/mail.private")
        );
        assert_eq!(
            layout.dkim_private_key("mail2"),
            PathBuf::from("/tmp/mail/dkim/mail2.private")
        );
        assert_eq!(
            layout.dkim_dns_record("custom"),
            PathBuf::from("/tmp/mail/dkim/custom.dns")
        );
    }

    #[test]
    fn log_file_path() {
        let layout = MailLayout::new("/home/pi/mail");
        assert_eq!(
            layout.log_file(),
            PathBuf::from("/home/pi/mail/logs/owl.log")
        );
    }

    #[test]
    fn ensure_list_creates_attachments_dir() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        for list in ["accepted", "spam", "banned"] {
            let attachments = layout.attachments(list);
            assert!(
                attachments.is_dir(),
                "Attachments dir should exist for {}",
                list
            );
        }
    }
}
