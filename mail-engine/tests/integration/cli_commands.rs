use assert_cmd::Command;

#[test]
fn cli_configure_wizard_updates_env_and_rules() {
    let temp = tempfile::tempdir().unwrap();
    let env_path = temp.path().join(".env");

    let input = "\n\
\n\
y\n\
\n\
\n\
\n\
\n\
\n\
\n\
\n\
\n\
3\n\
alice@example.org\n\
6\n\
\n\
\n\
\n\
\n\
\n\
\n\
\n\
7\n\
8\n";

    let mut cmd = Command::cargo_bin("owl").unwrap();
    cmd.args(["--env", env_path.to_str().unwrap(), "configure"])
        .write_stdin(input)
        .assert()
        .success();

    let env_contents = std::fs::read_to_string(&env_path).unwrap();
    assert!(env_contents.contains("logging="));
    assert!(env_contents.contains("dkim_selector="));
    assert!(env_contents.contains("retry_backoff="));

    let rules_path = temp.path().join("accepted/.rules");
    let rules = std::fs::read_to_string(rules_path).unwrap();
    assert!(rules.contains("alice@example.org"));

    let settings_path = temp.path().join("accepted/.settings");
    let settings = std::fs::read_to_string(settings_path).unwrap();
    assert!(settings.contains("list_status="));
    assert!(settings.contains("body_format="));
}
