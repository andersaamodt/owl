use owl::fsops::layout::MailLayout;
use owl::model::{
    filename::{html_filename, message_filename, sidecar_filename},
    message::{HeadersCache, MessageSidecar},
};
use owl::pipeline::reconcile::enforce_retention;
use owl::ruleset::loader::LoadedRules;
use time::OffsetDateTime;

#[test]
fn retention_respects_list_policies_and_cleans_attachments() {
    let temp = tempfile::tempdir().unwrap();
    let layout = MailLayout::new(temp.path());
    layout.ensure().unwrap();

    // Stale accepted message with attachment
    let sender_dir = layout.accepted().join("alice@example.org");
    std::fs::create_dir_all(&sender_dir).unwrap();
    let ulid = "01ARZ3NDEKTSV4RRFFQ69G5FAY";
    let subject = "Report";
    let message_name = message_filename(subject, ulid);
    let html_name = html_filename(subject, ulid);
    let sidecar_name = sidecar_filename(subject, ulid);
    std::fs::write(sender_dir.join(&message_name), b"body").unwrap();
    std::fs::write(sender_dir.join(&html_name), b"<html></html>").unwrap();
    let mut sidecar = MessageSidecar::new(
        ulid,
        message_name.clone(),
        "accepted",
        "strict",
        html_name.clone(),
        "hash",
        HeadersCache::new("Alice", subject),
    );
    sidecar.last_activity = (OffsetDateTime::now_utc() - time::Duration::days(120))
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap();
    sidecar.add_attachment("deadbeef", "report.pdf");
    std::fs::write(
        sender_dir.join(&sidecar_name),
        serde_yaml::to_string(&sidecar).unwrap(),
    )
    .unwrap();
    let attachment_path = layout.attachments("accepted").join("deadbeef__report.pdf");
    std::fs::create_dir_all(layout.attachments("accepted")).unwrap();
    std::fs::write(&attachment_path, b"pdf").unwrap();

    // Fresh spam message should be retained because policy is never by default
    let spam_dir = layout.spam().join("spammer@example.com");
    std::fs::create_dir_all(&spam_dir).unwrap();
    let spam_ulid = "01ARZ3NDEKTSV4RRFFQ69G5FAZ";
    let spam_name = message_filename("Spam", spam_ulid);
    std::fs::write(spam_dir.join(&spam_name), b"body").unwrap();
    std::fs::write(
        spam_dir.join(sidecar_filename("Spam", spam_ulid)),
        serde_yaml::to_string(&MessageSidecar::new(
            spam_ulid,
            spam_name,
            "spam",
            "strict",
            html_filename("Spam", spam_ulid),
            "hash",
            HeadersCache::new("Mallory", "Spam"),
        ))
        .unwrap(),
    )
    .unwrap();

    let mut rules = LoadedRules::default();
    rules.accepted.settings.delete_after = "30d".into();
    let results = enforce_retention(&layout, &rules, OffsetDateTime::now_utc()).unwrap();

    let accepted = results.get("accepted").unwrap();
    assert_eq!(accepted.messages_removed.len(), 1);
    assert!(!sender_dir.join(&sidecar_name).exists());
    assert!(!attachment_path.exists());

    let spam = results.get("spam").unwrap();
    assert!(spam.messages_removed.is_empty());
}
