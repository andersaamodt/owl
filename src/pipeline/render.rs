use anyhow::{Context, Result};
use duct::cmd;

pub fn sanitize_html(input: &str) -> Result<String> {
    sanitize_html_with("sanitize-html", &[], input)
}

pub fn sanitize_html_with(command: &str, args: &[&str], input: &str) -> Result<String> {
    cmd(command, args)
        .stdin_bytes(input.as_bytes())
        .stderr_to_stdout()
        .read()
        .with_context(|| format!("running {command}"))
}

pub fn render_plaintext(html: &str) -> Result<String> {
    render_plaintext_with("lynx", &["-dump", "-stdin"], html)
}

pub fn render_plaintext_with(command: &str, args: &[&str], html: &str) -> Result<String> {
    cmd(command, args)
        .stdin_bytes(html.as_bytes())
        .stderr_to_stdout()
        .read()
        .with_context(|| format!("running {command}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serial_test::serial;
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::panic;

    fn write_script(dir: &tempfile::TempDir, name: &str, body: &str) -> String {
        let path = dir.path().join(name);
        // Write and ensure file is fully synced
        {
            let mut file = fs::File::create(&path).unwrap();
            use std::io::Write;
            file.write_all(body.as_bytes()).unwrap();
            file.sync_all().unwrap();
            // File is dropped and closed here
        }
        let mut perms = fs::metadata(&path).unwrap().permissions();
        perms.set_mode(0o755);
        // Ignore permission errors on systems that don't support it
        let _ = fs::set_permissions(&path, perms);
        path.to_string_lossy().into()
    }

    fn with_prepended_path<T>(dir: &tempfile::TempDir, f: impl FnOnce() -> T) -> T {
        let original = std::env::var_os("PATH");
        let mut new_path = std::ffi::OsString::from(dir.path());
        if let Some(ref orig) = original {
            new_path.push(":");
            new_path.push(orig);
        }
        unsafe { std::env::set_var("PATH", &new_path) };
        let result = panic::catch_unwind(panic::AssertUnwindSafe(f));
        match original {
            Some(orig) => unsafe { std::env::set_var("PATH", orig) },
            None => unsafe { std::env::set_var("PATH", "") },
        }
        result.expect("path callback panicked")
    }

    #[test]
    fn sanitize_via_custom_command() {
        let dir = tempfile::tempdir().unwrap();
        let script = write_script(
            &dir,
            "custom-sanitize",
            "#!/bin/sh\nsed 's/<script/[blocked]/g'\n",
        );
        let html = "<div><script>alert(1)</script></div>";
        let sanitized = sanitize_html_with(&script, &[], html).unwrap();
        assert!(sanitized.contains("[blocked]"));
    }

    #[test]
    #[serial]
    fn sanitize_html_searches_path() {
        let dir = tempfile::tempdir().unwrap();
        let _ = write_script(
            &dir,
            "sanitize-html",
            "#!/bin/sh\ncat | sed 's/<script/SANITIZED/g'\n",
        );
        let result = with_prepended_path(&dir, || {
            sanitize_html("<div><script>alert(1)</script></div>").unwrap()
        });
        assert!(result.contains("SANITIZED"));
    }

    #[test]
    #[serial]
    fn with_prepended_path_handles_missing_environment() {
        let dir = tempfile::tempdir().unwrap();
        let original = std::env::var_os("PATH");
        unsafe { std::env::remove_var("PATH") };
        let _ = write_script(&dir, "sanitize-html", "#!/bin/sh\nexec /bin/cat\n");
        let output = with_prepended_path(&dir, || sanitize_html("<p>ok</p>").unwrap());
        assert_eq!(output.trim(), "<p>ok</p>");
        match original {
            Some(path) => unsafe { std::env::set_var("PATH", path) },
            None => unsafe { std::env::remove_var("PATH") },
        }
    }

    #[test]
    #[serial]
    fn with_prepended_path_sets_empty_when_missing() {
        let dir = tempfile::tempdir().unwrap();
        let original = std::env::var_os("PATH");
        unsafe { std::env::remove_var("PATH") };
        let _ = write_script(&dir, "sanitize-html", "#!/bin/sh\nexec /bin/cat\n");
        with_prepended_path(&dir, || sanitize_html("<p>noop</p>").unwrap());
        assert_eq!(std::env::var("PATH").unwrap(), "");
        match original {
            Some(path) => unsafe { std::env::set_var("PATH", path) },
            None => unsafe { std::env::remove_var("PATH") },
        }
    }

    #[test]
    fn sanitize_html_failure_bubbles() {
        let dir = tempfile::tempdir().unwrap();
        let script = write_script(&dir, "fail-sanitize", "#!/bin/sh\nexit 2\n");
        let err = sanitize_html_with(&script, &[], "<div>").unwrap_err();
        assert!(err.to_string().contains("running"));
    }

    #[test]
    fn render_plaintext_invokes_command() {
        let dir = tempfile::tempdir().unwrap();
        let script = write_script(&dir, "lynx-dump", "#!/bin/sh\ntr '[:lower:]' '[:upper:]'\n");
        let rendered = render_plaintext_with(&script, &[], "Hello").unwrap();
        assert_eq!(rendered.trim(), "HELLO");
    }

    #[test]
    #[serial]
    fn render_plaintext_default_uses_lynx() {
        let dir = tempfile::tempdir().unwrap();
        let _ = write_script(&dir, "lynx", "#!/bin/sh\ncat\n");
        let rendered = with_prepended_path(&dir, || render_plaintext("body").unwrap());
        assert_eq!(rendered, "body");
    }

    #[test]
    fn render_plaintext_failure_bubbles() {
        let dir = tempfile::tempdir().unwrap();
        let script = write_script(&dir, "lynx-fail", "#!/bin/sh\nexit 1\n");
        let err = render_plaintext_with(&script, &[], "body").unwrap_err();
        assert!(err.to_string().contains("running"));
    }
}
