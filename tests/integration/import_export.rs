use assert_cmd::Command;
use owl::{
    fsops::attach::AttachmentStore, fsops::layout::MailLayout, model::message::MessageSidecar,
};
use serial_test::serial;
use std::panic;
use std::{fs, os::unix::fs::PermissionsExt, path::Path};

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

fn run_owl(args: &[&str]) -> assert_cmd::assert::Assert {
    let mut cmd = Command::cargo_bin("owl").unwrap();
    cmd.args(args).assert()
}

fn with_fake_sanitizer<T>(f: impl FnOnce() -> T) -> T {
    let script_dir = tempfile::tempdir().unwrap();
    let script_path = script_dir.path().join("sanitize-html");
    fs::write(&script_path, "#!/bin/sh\ncat\n").unwrap();
    let mut perms = fs::metadata(&script_path).unwrap().permissions();
    perms.set_mode(0o755);
    fs::set_permissions(&script_path, perms).unwrap();

    let original = std::env::var_os("PATH");
    let mut new_path = std::ffi::OsString::from(script_dir.path());
    if let Some(ref orig) = original {
        new_path.push(":");
        new_path.push(orig);
    }
    unsafe { std::env::set_var("PATH", &new_path) };
    let result = panic::catch_unwind(panic::AssertUnwindSafe(f));
    match original {
        Some(orig) => unsafe { std::env::set_var("PATH", orig) },
        None => unsafe { std::env::remove_var("PATH") },
    }
    match result {
        Ok(value) => value,
        Err(err) => panic::resume_unwind(err),
    }
}

fn load_sidecar(path: &Path) -> MessageSidecar {
    let yaml = fs::read_to_string(path).unwrap();
    serde_yaml::from_str(&yaml).unwrap()
}

#[test]
#[serial]
fn cli_import_maildir_delivers_to_quarantine() {
    with_fake_sanitizer(|| {
        let temp = tempfile::tempdir().unwrap();
        let env_path = temp.path().join(".env");
        fs::write(&env_path, "logging=minimal\n").unwrap();

        run_owl(&["--env", env_path.to_str().unwrap(), "install"])
            .success()
            .stdout(predicates::str::contains("installed"));

        let maildir = temp.path().join("maildir");
        fs::create_dir_all(maildir.join("cur")).unwrap();
        let message = b"From: Alice <alice@example.org>\r\nSubject: Imported\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nBody\r\n";
        fs::write(maildir.join("cur/1.eml"), message).unwrap();

        run_owl(&[
            "--env",
            env_path.to_str().unwrap(),
            "import",
            maildir.to_str().unwrap(),
        ])
        .success()
        .stdout(predicates::str::contains("imported 1 messages"));

        let layout = MailLayout::new(env_path.parent().unwrap());
        let sender_dir = layout.quarantine().join("alice@example.org");
        assert!(sender_dir.exists());
        let sidecar_path = fs::read_dir(&sender_dir)
            .unwrap()
            .filter_map(|entry| entry.ok())
            .map(|entry| entry.path())
            .find(|path| path.extension().and_then(|ext| ext.to_str()) == Some("yml"))
            .expect("sidecar not found");
        let sidecar = load_sidecar(&sidecar_path);
        assert_eq!(sidecar.headers_cache.subject, "Imported");
        assert_eq!(sidecar.status_shadow, "quarantine");
    });
}

#[test]
#[serial]
fn cli_import_mbox_delivers_to_quarantine() {
    with_fake_sanitizer(|| {
        let temp = tempfile::tempdir().unwrap();
        let env_path = temp.path().join(".env");
        fs::write(&env_path, "logging=minimal\n").unwrap();

        run_owl(&["--env", env_path.to_str().unwrap(), "install"])
            .success()
            .stdout(predicates::str::contains("installed"));

        let mbox_path = temp.path().join("mailbox.mbox");
        let message = concat!(
            "From sender@example.org Sat Jan 01 00:00:00 2025\n",
            "From: Sender <sender@example.org>\n",
            "Subject: Mbox Import\n",
            "Content-Type: text/plain; charset=utf-8\n",
            "\n",
            "Body\n"
        );
        fs::write(&mbox_path, message).unwrap();

        run_owl(&[
            "--env",
            env_path.to_str().unwrap(),
            "import",
            mbox_path.to_str().unwrap(),
        ])
        .success()
        .stdout(predicates::str::contains("imported 1 messages"));

        let layout = MailLayout::new(env_path.parent().unwrap());
        let sender_dir = layout.quarantine().join("sender@example.org");
        assert!(sender_dir.exists());
    });
}
