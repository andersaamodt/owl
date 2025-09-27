use owl::{
    envcfg::EnvConfig,
    fsops::layout::MailLayout,
    model::{filename::outbox_sidecar_filename, message::MessageSidecar},
    pipeline::outbox::OutboxPipeline,
    util::logging::{LogLevel, Logger},
};

#[test]
fn queue_draft_writes_sidecar_and_eml() {
    let dir = tempfile::tempdir().unwrap();
    let layout = MailLayout::new(dir.path());
    layout.ensure().unwrap();
    let env = EnvConfig::default();
    let logger = Logger::new(layout.root(), LogLevel::Off).unwrap();
    let pipeline = OutboxPipeline::new(layout.clone(), env, logger);

    let draft_ulid = owl::util::ulid::generate();
    let draft_path = layout
        .drafts()
        .join(format!("{draft_ulid}.md"));
    std::fs::write(
        &draft_path,
        "---\nsubject: Agenda\nfrom: Owl <owl@example.org>\nto:\n  - Carol <carol@example.org>\n---\nBody\n",
    )
    .unwrap();

    let message_path = pipeline.queue_draft(&draft_path).unwrap();
    assert!(message_path.exists());

    let sidecar_path = layout
        .outbox()
        .join(outbox_sidecar_filename(&draft_ulid));
    let yaml = std::fs::read_to_string(&sidecar_path).unwrap();
    let sidecar: MessageSidecar = serde_yaml::from_str(&yaml).unwrap();
    assert_eq!(sidecar.schema, 1);
    assert_eq!(sidecar.status_shadow, "outbox");
    assert!(yaml.contains("hash_sha256"));
    assert!(sidecar.outbound.is_some());
}
