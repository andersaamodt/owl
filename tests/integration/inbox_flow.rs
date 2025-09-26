use owl::{
    cli::{run, Commands, OwlCli},
    envcfg::EnvConfig,
    fsops::layout::MailLayout,
    model::address::Address,
    pipeline::smtp_in::InboundPipeline,
    ruleset::eval::Route,
};
use serial_test::serial;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::panic;

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

#[test]
#[serial]
fn delivers_to_quarantine() {
    with_fake_sanitizer(|| {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        let pipeline = InboundPipeline::new(layout, EnvConfig::default()).unwrap();
        let sender = Address::parse("alice@example.org", false).unwrap();
        let message = b"Subject: Integration\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nbody";
        let path = pipeline
            .deliver_quarantine(&sender, "Integration", message)
            .unwrap();
        assert!(path.exists());
    });
}

#[test]
#[serial]
fn delivers_to_accepted_route() {
    with_fake_sanitizer(|| {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        let pipeline = InboundPipeline::new(layout, EnvConfig::default()).unwrap();
        let sender = Address::parse("bob@example.org", false).unwrap();
        let message = b"Subject: Integration\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nbody";
        let path = pipeline
            .deliver_to_route(Route::Accepted, &sender, "Integration", message)
            .unwrap();
        assert!(path.starts_with(dir.path().join("accepted")));
    });
}

#[test]
fn cli_runs_triage_default() {
    let cli = OwlCli {
        env: "".into(),
        command: Some(Commands::Reload),
        json: false,
    };
    let result = run(cli, EnvConfig::default()).unwrap();
    assert!(result.starts_with("reloaded rules:"));
}
