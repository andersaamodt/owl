use owl::{
    envcfg::EnvConfig,
    fsops::layout::MailLayout,
    pipeline::outbox::OutboxPipeline,
    util::logging::{LogLevel, Logger},
};

#[test]
fn queued_message_is_left_for_the_submission_server_to_sign() {
    let dir = tempfile::tempdir().unwrap();
    let layout = MailLayout::new(dir.path());
    layout.ensure().unwrap();
    let logger = Logger::new(layout.root(), LogLevel::Off).unwrap();
    let pipeline = OutboxPipeline::new(layout.clone(), EnvConfig::default(), logger);

    let draft_ulid = owl::util::ulid::generate();
    let draft_path = layout.drafts().join(format!("{draft_ulid}.md"));
    std::fs::write(
        &draft_path,
        "---\nsubject: Check-in\nfrom: Stellar <me@example.org>\nto:\n  - Dana <dana@example.net>\n---\nHi Dana,\n",
    )
    .unwrap();

    let message_path = pipeline.queue_draft(&draft_path).unwrap();
    let message = std::fs::read_to_string(message_path).unwrap();

    assert!(message.contains("From: Stellar <me@example.org>"));
    assert!(!message.to_ascii_lowercase().contains("dkim-signature:"));
    assert!(!layout.root().join("dkim").exists());
}
