use owl::fsops::attach::AttachmentStore;

#[test]
fn store_and_export_attachment() {
    let dir = tempfile::tempdir().unwrap();
    let store = AttachmentStore::new(dir.path());
    let stored = store.store("invoice.pdf", b"data").unwrap();
    let loaded = store
        .load(stored.path.file_name().unwrap().to_str().unwrap())
        .unwrap();
    assert_eq!(loaded, b"data");
    assert_eq!(stored.sha256.len(), 64);
}
