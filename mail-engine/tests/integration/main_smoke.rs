use assert_cmd::Command;

#[test]
fn runs_help() {
    let temp = tempfile::tempdir().unwrap();
    let env_path = temp.path().join(".env");
    std::fs::write(&env_path, "logging=off\n").unwrap();
    let mut cmd = Command::cargo_bin("owl").unwrap();
    cmd.args(["--env", env_path.to_str().unwrap(), "reload"]);
    cmd.assert().success();
}
