use owl::{
    envcfg::EnvConfig,
    pipeline::outbox::OutboxPipeline,
};

#[test]
fn queue_and_retry_metadata() {
    let dir = tempfile::tempdir().unwrap();
    let pipeline = OutboxPipeline::new(dir.path().join("outbox"), EnvConfig::default());
    let path = pipeline.queue("carol@example.org", "Meeting", b"body").unwrap();
    let yaml_path = std::fs::read_dir(dir.path().join("outbox"))
        .unwrap()
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .find(|path| path.extension().map(|ext| ext == "yml").unwrap_or(false))
        .unwrap();
    let yaml = std::fs::read_to_string(yaml_path).unwrap();
    assert!(yaml.contains("schema: 1"));
    assert!(path.exists());
}
