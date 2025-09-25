use assert_cmd::Command;

#[test]
fn runs_help() {
    let mut cmd = Command::cargo_bin("owl").unwrap();
    cmd.arg("reload");
    cmd.assert().success();
}
