use anyhow::{Result, bail};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use time::OffsetDateTime;
use walkdir::WalkDir;

use crate::{
    fsops::layout::MailLayout,
    model::message::MessageSidecar,
    ruleset::loader::LoadedRules,
    util::time::{parse_delete_after, retention_due},
};

#[derive(Debug, Default, Clone)]
pub struct RetentionSummary {
    pub messages_removed: Vec<PathBuf>,
    pub attachments_removed: Vec<PathBuf>,
}

pub fn enforce_retention(
    layout: &MailLayout,
    rules: &LoadedRules,
    now: OffsetDateTime,
) -> Result<HashMap<String, RetentionSummary>> {
    let mut results = HashMap::new();
    results.insert(
        "accepted".to_string(),
        prune_list(
            layout,
            "accepted",
            &rules.accepted.settings.delete_after,
            now,
        )?,
    );
    results.insert(
        "spam".to_string(),
        prune_list(layout, "spam", &rules.spam.settings.delete_after, now)?,
    );
    results.insert(
        "banned".to_string(),
        prune_list(layout, "banned", &rules.banned.settings.delete_after, now)?,
    );
    Ok(results)
}

pub fn prune_list(
    layout: &MailLayout,
    list: &str,
    policy: &str,
    now: OffsetDateTime,
) -> Result<RetentionSummary> {
    let list_dir = layout.root().join(list);
    let mut summary = RetentionSummary::default();
    if should_prune(policy)? && list_dir.exists() {
        for entry in fs::read_dir(&list_dir)? {
            let entry = entry?;
            if entry.file_type()?.is_dir() {
                if entry.file_name() == "attachments" {
                    continue;
                }
                let mut removed = prune_directory(&entry.path(), policy, now)?;
                summary.messages_removed.append(&mut removed);
            }
        }
    }

    let references = collect_attachment_references(&list_dir)?;
    let mut attachments = prune_attachments(&layout.attachments(list), &references)?;
    summary.attachments_removed.append(&mut attachments);
    Ok(summary)
}

pub fn prune_directory(dir: &Path, policy: &str, now: OffsetDateTime) -> Result<Vec<PathBuf>> {
    if !dir.exists() {
        return Ok(Vec::new());
    }
    let mut removed = Vec::new();
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().map(|ext| ext == "yml").unwrap_or(false) {
            let data = fs::read_to_string(&path)?;
            let sidecar: MessageSidecar = serde_yaml::from_str(&data)?;
            let last = OffsetDateTime::parse(
                &sidecar.last_activity,
                &time::format_description::well_known::Rfc3339,
            )?;
            if retention_due(last, policy, now) {
                remove_message_files(&path)?;
                removed.push(path);
            }
        }
    }
    Ok(removed)
}

fn should_prune(policy: &str) -> Result<bool> {
    let trimmed = policy.trim();
    if trimmed.eq_ignore_ascii_case("never") || trimmed.is_empty() {
        return Ok(false);
    }
    if parse_delete_after(trimmed).is_some() {
        return Ok(true);
    }
    bail!("invalid delete_after policy: {policy}");
}

fn collect_attachment_references(dir: &Path) -> Result<HashSet<String>> {
    let mut references = HashSet::new();
    if !dir.exists() {
        return Ok(references);
    }
    for entry in WalkDir::new(dir).into_iter().filter_map(Result::ok) {
        let path = entry.path();
        if entry.file_type().is_file() && path.extension().map(|ext| ext == "yml").unwrap_or(false)
        {
            let data = fs::read_to_string(path)?;
            let sidecar: MessageSidecar = serde_yaml::from_str(&data)?;
            for attachment in sidecar.attachments {
                references.insert(attachment.sha256);
            }
        }
    }
    Ok(references)
}

fn prune_attachments(dir: &Path, references: &HashSet<String>) -> Result<Vec<PathBuf>> {
    let mut removed = Vec::new();
    if !dir.exists() {
        return Ok(removed);
    }
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        if !entry.file_type()?.is_file() {
            continue;
        }
        let file_name = match entry.file_name().into_string() {
            Ok(name) => name,
            Err(_) => continue,
        };
        let sha = file_name
            .split_once("__")
            .map(|(sha, _)| sha.to_string())
            .unwrap_or_else(|| file_name.clone());
        if !references.contains(&sha) {
            let path = entry.path();
            fs::remove_file(&path)?;
            removed.push(path);
        }
    }
    Ok(removed)
}

fn remove_message_files(sidecar: &Path) -> Result<()> {
    if let Some(stem) = sidecar.file_stem() {
        let base = stem.to_string_lossy().trim_start_matches('.').to_string();
        let eml = sidecar.with_file_name(format!("{base}.eml"));
        if eml.exists() {
            fs::remove_file(eml)?;
        }
        let html = sidecar.with_file_name(format!("{base}.html"));
        if html.exists() {
            fs::remove_file(html)?;
        }
    }
    fs::remove_file(sidecar)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{
        filename::{html_filename, message_filename, sidecar_filename},
        message::HeadersCache,
    };
    use crate::ruleset::loader::LoadedRules;

    fn write_sidecar(
        dir: &Path,
        subject: &str,
        ulid: &str,
        last_activity_days_ago: i64,
    ) -> PathBuf {
        let message = message_filename(subject, ulid);
        let html = html_filename(subject, ulid);
        let sidecar_path = dir.join(sidecar_filename(subject, ulid));
        let mut sidecar = MessageSidecar::new(
            ulid,
            message.clone(),
            "accepted",
            "strict",
            html.clone(),
            "hash",
            HeadersCache::new("Alice", subject),
        );
        sidecar.last_activity = (OffsetDateTime::now_utc()
            - time::Duration::days(last_activity_days_ago))
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap();
        sidecar.add_attachment("deadbeef", "file.txt");
        fs::write(dir.join(&message), b"body").unwrap();
        fs::write(dir.join(&html), b"<html></html>").unwrap();
        fs::write(&sidecar_path, serde_yaml::to_string(&sidecar).unwrap()).unwrap();
        sidecar_path
    }

    #[test]
    fn prune_old_files() {
        let dir = tempfile::tempdir().unwrap();
        let sidecar_path = dir.path().join(".msg (01).yml");
        let mut sidecar = MessageSidecar::new(
            "01",
            "msg (01).eml",
            "accepted",
            "strict",
            ".msg (01).html",
            "hash",
            crate::model::message::HeadersCache::new("alice", "hi"),
        );
        sidecar.last_activity = (OffsetDateTime::now_utc() - time::Duration::days(400))
            .format(&time::format_description::well_known::Rfc3339)
            .unwrap();
        std::fs::write(dir.path().join("msg (01).eml"), b"body").unwrap();
        std::fs::write(dir.path().join("msg (01).html"), b"<html></html>").unwrap();
        std::fs::write(&sidecar_path, serde_yaml::to_string(&sidecar).unwrap()).unwrap();
        let removed = prune_directory(dir.path(), "1y", OffsetDateTime::now_utc()).unwrap();
        assert_eq!(removed.len(), 1);
    }

    #[test]
    fn handles_missing_directory() {
        let dir = tempfile::tempdir().unwrap();
        let missing = dir.path().join("missing");
        let removed = prune_directory(&missing, "1y", OffsetDateTime::now_utc()).unwrap();
        assert!(removed.is_empty());
    }

    #[test]
    fn prune_list_removes_orphan_attachments() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let sender_dir = layout.accepted().join("alice@example.org");
        fs::create_dir_all(&sender_dir).unwrap();
        let sidecar_path = write_sidecar(&sender_dir, "Hello", "01ARZ3NDEKTSV4RRFFQ69G5FAV", 60);
        let attachments_dir = layout.attachments("accepted");
        fs::create_dir_all(&attachments_dir).unwrap();
        let attachment_path = attachments_dir.join("deadbeef__file.txt");
        fs::write(&attachment_path, b"data").unwrap();

        let summary = prune_list(&layout, "accepted", "30d", OffsetDateTime::now_utc()).unwrap();
        assert_eq!(summary.messages_removed.len(), 1);
        assert_eq!(summary.attachments_removed.len(), 1);
        assert!(!sidecar_path.exists());
        assert!(!attachment_path.exists());
    }

    #[test]
    fn enforce_retention_uses_list_settings() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let spam_dir = layout.spam().join("spammer@example.com");
        fs::create_dir_all(&spam_dir).unwrap();
        let spam_sidecar = write_sidecar(&spam_dir, "Spam", "01ARZ3NDEKTSV4RRFFQ69G5FAW", 90);

        let accepted_dir = layout.accepted().join("ally@example.com");
        fs::create_dir_all(&accepted_dir).unwrap();
        let accepted_sidecar =
            write_sidecar(&accepted_dir, "Fresh", "01ARZ3NDEKTSV4RRFFQ69G5FAX", 1);

        let mut rules = LoadedRules::default();
        rules.spam.settings.delete_after = "30d".into();
        let results = enforce_retention(&layout, &rules, OffsetDateTime::now_utc()).unwrap();

        let spam_summary = results.get("spam").unwrap();
        assert_eq!(spam_summary.messages_removed.len(), 1);
        assert!(!spam_sidecar.exists());

        let accepted_summary = results.get("accepted").unwrap();
        assert!(accepted_summary.messages_removed.is_empty());
        assert!(accepted_sidecar.exists());
    }

    #[test]
    fn prune_list_invalid_policy_errors() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        let err = prune_list(&layout, "accepted", "1w", OffsetDateTime::now_utc()).unwrap_err();
        assert!(err.to_string().contains("invalid delete_after"));
    }

    #[test]
    fn collect_references_for_missing_dir_is_empty() {
        let dir = tempfile::tempdir().unwrap();
        let refs = collect_attachment_references(&dir.path().join("missing")).unwrap();
        assert!(refs.is_empty());
    }

    #[test]
    fn prune_attachments_handles_missing_directory() {
        let dir = tempfile::tempdir().unwrap();
        let removed = prune_attachments(&dir.path().join("missing"), &HashSet::new()).unwrap();
        assert!(removed.is_empty());
    }

    #[test]
    fn prune_directory_preserves_recent_messages() {
        let dir = tempfile::tempdir().unwrap();

        // Old message (should be deleted)
        let old_sidecar = write_sidecar(dir.path(), "Old", "01ARZ3NDEKTSV4RRFFQ69G5FAV", 90);

        // Recent message (should be kept)
        let new_sidecar = write_sidecar(dir.path(), "New", "01ARZ3NDEKTSV4RRFFQ69G5FAW", 1);

        let removed = prune_directory(dir.path(), "30d", OffsetDateTime::now_utc()).unwrap();

        assert_eq!(removed.len(), 1);
        assert!(!old_sidecar.exists());
        assert!(new_sidecar.exists());
    }

    #[test]
    fn prune_directory_with_never_policy() {
        let dir = tempfile::tempdir().unwrap();
        let old_sidecar = write_sidecar(dir.path(), "Old", "01ARZ3NDEKTSV4RRFFQ69G5FAV", 365);

        let removed = prune_directory(dir.path(), "never", OffsetDateTime::now_utc()).unwrap();

        // "never" policy should not delete anything
        assert_eq!(removed.len(), 0);
        assert!(old_sidecar.exists());
    }

    #[test]
    fn prune_directory_deletes_message_and_sidecar() {
        let dir = tempfile::tempdir().unwrap();
        // Use write_sidecar which creates all three files
        let sidecar_path = write_sidecar(dir.path(), "Test", "01ARZ3NDEKTSV4RRFFQ69G5FAV", 90);

        // Get actual filenames from the sidecar
        use crate::model::filename::message_filename;
        let eml = dir
            .path()
            .join(message_filename("Test", "01ARZ3NDEKTSV4RRFFQ69G5FAV"));

        // Files should exist before prune
        assert!(sidecar_path.exists());
        assert!(eml.exists());

        prune_directory(dir.path(), "30d", OffsetDateTime::now_utc()).unwrap();

        // Sidecar and EML should be deleted
        assert!(!sidecar_path.exists());
        assert!(!eml.exists());
        // Note: HTML file deletion depends on remove_message_files logic
    }

    #[test]
    fn collect_attachment_references_from_multiple_messages() {
        let dir = tempfile::tempdir().unwrap();
        let sender_dir = dir.path().join("alice@example.org");
        fs::create_dir_all(&sender_dir).unwrap();

        // Message 1 with attachment "abc123"
        let mut sidecar1 = MessageSidecar::new(
            "01A",
            "msg1.eml",
            "accepted",
            "strict",
            "msg1.html",
            "hash1",
            crate::model::message::HeadersCache::new("alice", "hi"),
        );
        sidecar1.add_attachment("abc123", "file1.txt");
        let sc1_path = sender_dir.join(".msg1 (01A).yml");
        fs::write(&sc1_path, serde_yaml::to_string(&sidecar1).unwrap()).unwrap();

        // Message 2 with attachments "abc123" and "def456"
        let mut sidecar2 = MessageSidecar::new(
            "01B",
            "msg2.eml",
            "accepted",
            "strict",
            "msg2.html",
            "hash2",
            crate::model::message::HeadersCache::new("alice", "hello"),
        );
        sidecar2.add_attachment("abc123", "file1.txt");
        sidecar2.add_attachment("def456", "file2.pdf");
        let sc2_path = sender_dir.join(".msg2 (01B).yml");
        fs::write(&sc2_path, serde_yaml::to_string(&sidecar2).unwrap()).unwrap();

        let refs = collect_attachment_references(dir.path()).unwrap();

        // Should have both unique hashes
        assert!(refs.contains("abc123"));
        assert!(refs.contains("def456"));
        assert_eq!(refs.len(), 2);
    }

    #[test]
    fn prune_attachments_keeps_referenced_files() {
        let dir = tempfile::tempdir().unwrap();
        let attach_dir = dir.path();
        fs::create_dir_all(attach_dir).unwrap();

        // Create attachments
        fs::write(attach_dir.join("abc123__file.txt"), b"data1").unwrap();
        fs::write(attach_dir.join("def456__file.pdf"), b"data2").unwrap();
        fs::write(attach_dir.join("xyz789__orphan.jpg"), b"orphan").unwrap();

        // Reference only abc123 and def456
        let mut refs = HashSet::new();
        refs.insert("abc123".to_string());
        refs.insert("def456".to_string());

        let removed = prune_attachments(attach_dir, &refs).unwrap();

        // Only orphan should be removed
        assert_eq!(removed.len(), 1);
        assert!(attach_dir.join("abc123__file.txt").exists());
        assert!(attach_dir.join("def456__file.pdf").exists());
        assert!(!attach_dir.join("xyz789__orphan.jpg").exists());
    }

    #[test]
    fn prune_list_skips_attachments_subdir() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        // Attachments dir should not be scanned for messages
        let attach_dir = layout.accepted().join("attachments");
        fs::write(attach_dir.join("not-a-message.txt"), b"data").unwrap();

        let summary = prune_list(&layout, "accepted", "1y", OffsetDateTime::now_utc()).unwrap();

        // Should not try to prune the attachments directory
        assert_eq!(summary.messages_removed.len(), 0);
    }

    #[test]
    fn enforce_retention_processes_all_lists() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let rules = LoadedRules::default();
        let results = enforce_retention(&layout, &rules, OffsetDateTime::now_utc()).unwrap();

        // Should have entries for all three lists
        assert!(results.contains_key("accepted"));
        assert!(results.contains_key("spam"));
        assert!(results.contains_key("banned"));
        assert_eq!(results.len(), 3);
    }

    #[test]
    fn prune_directory_with_malformed_sidecar() {
        let dir = tempfile::tempdir().unwrap();

        // Create a malformed sidecar (invalid YAML)
        let sidecar_path = dir.path().join(".bad (01ARZ3NDEKTSV4RRFFQ69G5FAV).yml");
        fs::write(&sidecar_path, b"not valid yaml {[}").unwrap();
        fs::write(
            dir.path().join("bad (01ARZ3NDEKTSV4RRFFQ69G5FAV).eml"),
            b"body",
        )
        .unwrap();

        // Should error on parse failure
        let result = prune_directory(dir.path(), "30d", OffsetDateTime::now_utc());
        assert!(result.is_err(), "Expected error for malformed sidecar");
    }

    #[test]
    fn should_prune_validates_policy() {
        assert!(should_prune("30d").unwrap());
        assert!(should_prune("6m").unwrap());
        assert!(!should_prune("never").unwrap());

        let err = should_prune("invalid").expect_err("expected error");
        assert!(err.to_string().contains("invalid delete_after"));
    }
}
