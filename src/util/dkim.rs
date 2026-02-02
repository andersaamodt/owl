use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, anyhow, bail};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use ring::{
    rand::SystemRandom,
    signature::{Ed25519KeyPair, KeyPair},
};
use sha2::{Digest, Sha256};
use time::OffsetDateTime;

use crate::fsops::io_atom::write_atomic;

#[derive(Debug, Clone)]
pub struct DkimMaterial {
    pub private_key_path: PathBuf,
    pub public_key_path: PathBuf,
    pub dns_record_path: PathBuf,
    pub public_key: String,
    pub selector: String,
}

pub fn ensure_ed25519_keypair(dir: &Path, selector: &str) -> Result<DkimMaterial> {
    fs::create_dir_all(dir)?;
    let private = dir.join(format!("{selector}.private"));
    let public = dir.join(format!("{selector}.public"));
    let dns = dir.join(format!("{selector}.dns"));

    let mut generated = false;
    if !private.exists() || !public.exists() {
        let rng = SystemRandom::new();
        let pkcs8 = Ed25519KeyPair::generate_pkcs8(&rng)
            .map_err(|err| anyhow!("failed to generate ed25519 DKIM keypair: {err:?}"))?;
        write_atomic(&private, pkcs8.as_ref())?;
        set_private_permissions(&private)?;
        let keypair = Ed25519KeyPair::from_pkcs8(pkcs8.as_ref())
            .map_err(|err| anyhow!("generated DKIM keypair invalid: {err}"))?;
        let public_b64 = STANDARD.encode(keypair.public_key().as_ref());
        write_atomic(&public, public_b64.as_bytes())?;
        generated = true;
    }

    let public_key = fs::read_to_string(&public)
        .with_context(|| format!("reading {}", public.display()))?
        .trim()
        .to_string();
    let dns_value = format!("v=DKIM1; k=ed25519; p={public_key}");

    if generated || !dns.exists() {
        write_atomic(&dns, dns_value.as_bytes())?;
    } else {
        let existing = fs::read_to_string(&dns)
            .with_context(|| format!("reading {}", dns.display()))?
            .trim()
            .to_string();
        if existing != dns_value {
            write_atomic(&dns, dns_value.as_bytes())?;
        }
    }

    Ok(DkimMaterial {
        private_key_path: private,
        public_key_path: public,
        dns_record_path: dns,
        public_key,
        selector: selector.to_string(),
    })
}

#[derive(Debug)]
pub struct DkimSigner {
    selector: String,
    keypair: Ed25519KeyPair,
}

impl DkimSigner {
    pub fn from_material(material: &DkimMaterial) -> Result<Self> {
        let pkcs8 = fs::read(&material.private_key_path)
            .with_context(|| format!("reading {}", material.private_key_path.display()))?;
        let keypair = Ed25519KeyPair::from_pkcs8(&pkcs8)
            .map_err(|err| anyhow!("failed to parse DKIM private key: {err}"))?;
        Ok(Self {
            selector: material.selector.clone(),
            keypair,
        })
    }

    pub fn sign(
        &self,
        domain: &str,
        headers_raw: &str,
        body: &[u8],
        header_names: &[&str],
    ) -> Result<String> {
        let canonical_headers = collect_signed_headers(headers_raw, header_names)?;
        let canonical_body = canonicalize_body_simple(body);
        let mut hasher = Sha256::new();
        hasher.update(&canonical_body);
        let body_hash = STANDARD.encode(hasher.finalize());
        let timestamp = OffsetDateTime::now_utc().unix_timestamp();
        let header_list = header_names.join(":");
        let mut value = format!(
            "v=1; a=ed25519-sha256; d={domain}; s={}; c=simple/simple; q=dns/txt; t={timestamp}; h={header_list}; bh={body_hash}; b=",
            self.selector
        );

        let mut to_sign = Vec::new();
        for header in &canonical_headers {
            to_sign.extend_from_slice(header.as_bytes());
        }
        let dkim_header = format!("DKIM-Signature: {value}");
        to_sign.extend_from_slice(dkim_header.as_bytes());
        to_sign.extend_from_slice(b"\r\n");

        let signature = self.keypair.sign(&to_sign);
        value.push_str(&STANDARD.encode(signature.as_ref()));
        Ok(value)
    }
}

pub fn collect_signed_headers(headers_raw: &str, header_names: &[&str]) -> Result<Vec<String>> {
    let mut result = Vec::with_capacity(header_names.len());
    for name in header_names {
        let Some(header) = extract_header(headers_raw, name) else {
            bail!("header {name} missing for DKIM signing");
        };
        result.push(header);
    }
    Ok(result)
}

pub fn extract_header(headers_raw: &str, name: &str) -> Option<String> {
    let mut collected = String::new();
    let mut capture = false;
    let target = name.to_ascii_lowercase();
    for line in headers_raw.split_inclusive("\r\n") {
        if line == "\r\n" {
            break;
        }
        let trimmed = line.trim_end_matches("\r\n");
        if trimmed.is_empty() {
            if capture {
                break;
            }
            continue;
        }
        let first = trimmed.chars().next().unwrap_or_default();
        if matches!(first, ' ' | '\t') {
            if capture {
                collected.push_str(line);
            }
            continue;
        }
        if let Some((field, _)) = trimmed.split_once(':') {
            if field.eq_ignore_ascii_case(&target) {
                collected.clear();
                collected.push_str(line);
                capture = true;
            } else if capture {
                break;
            } else {
                capture = false;
            }
        }
    }
    if capture && !collected.is_empty() {
        Some(collected)
    } else {
        None
    }
}

pub fn canonicalize_body_simple(body: &[u8]) -> Vec<u8> {
    if body.is_empty() {
        return b"\r\n".to_vec();
    }
    let mut end = body.len();
    while end >= 2 && body[..end].ends_with(b"\r\n") {
        end -= 2;
    }
    let mut canonical = body[..end].to_vec();
    canonical.extend_from_slice(b"\r\n");
    canonical
}

#[cfg(unix)]
fn set_private_permissions(path: &Path) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    let mut perms = fs::metadata(path)?.permissions();
    perms.set_mode(0o600);
    // Ignore permission errors on systems that don't support it (e.g., some macOS filesystems)
    let _ = fs::set_permissions(path, perms);
    Ok(())
}

#[cfg(not(unix))]
fn set_private_permissions(_path: &Path) -> Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn collect_signed_headers_errors_on_missing_field() {
        let err = collect_signed_headers("Subject: hi\r\n\r\n", &["from"]).unwrap_err();
        assert!(err.to_string().contains("header from missing"));
    }

    #[test]
    fn extract_header_stops_on_blank_lines() {
        let raw = "Subject: hi\r\n\r\nX-Test: value\r\n";
        assert_eq!(
            extract_header(raw, "subject"),
            Some("Subject: hi\r\n".into())
        );
        // After the blank line the capture should stop so the next header is ignored.
        assert_eq!(extract_header(raw, "x-test"), None);
    }

    #[test]
    fn extract_header_handles_whitespace_only_lines() {
        let raw = "Subject: hi\r\n\tcontinuation\r\n   \r\nNext: value\r\n";
        assert_eq!(
            extract_header(raw, "subject"),
            Some("Subject: hi\r\n\tcontinuation\r\n   \r\n".into())
        );
        assert_eq!(extract_header(raw, "next"), Some("Next: value\r\n".into()));
    }

    #[test]
    fn canonicalize_body_for_empty_input() {
        assert_eq!(canonicalize_body_simple(b""), b"\r\n".to_vec());
    }

    #[test]
    fn canonicalize_body_trims_trailing_lines() {
        let body = b"hello\r\nworld\r\n\r\n";
        let canonical = canonicalize_body_simple(body);
        assert_eq!(canonical, b"hello\r\nworld\r\n");
    }

    #[test]
    fn signer_reports_invalid_private_key() {
        let dir = tempfile::tempdir().unwrap();
        let private = dir.path().join("selector.private");
        let public = dir.path().join("selector.public");
        let dns = dir.path().join("selector.dns");
        fs::write(&private, b"not a pkcs8 key").unwrap();
        let material = DkimMaterial {
            private_key_path: private,
            public_key_path: public,
            dns_record_path: dns,
            public_key: String::new(),
            selector: "selector".into(),
        };
        let err = DkimSigner::from_material(&material).unwrap_err();
        assert!(err.to_string().contains("failed to parse DKIM private key"));
    }

    #[test]
    fn ensure_keypair_recreates_missing_dns() {
        let dir = tempfile::tempdir().unwrap();
        let material = ensure_ed25519_keypair(dir.path(), "sel").unwrap();
        fs::remove_file(&material.dns_record_path).unwrap();
        let refreshed = ensure_ed25519_keypair(dir.path(), "sel").unwrap();
        assert!(refreshed.dns_record_path.exists());
        let dns_contents = fs::read_to_string(refreshed.dns_record_path).unwrap();
        assert!(dns_contents.starts_with("v=DKIM1"));
    }

    #[test]
    fn ensure_keypair_updates_stale_dns_record() {
        let dir = tempfile::tempdir().unwrap();
        let material = ensure_ed25519_keypair(dir.path(), "sel").unwrap();
        fs::write(&material.dns_record_path, "old record").unwrap();
        let refreshed = ensure_ed25519_keypair(dir.path(), "sel").unwrap();
        let dns_contents = fs::read_to_string(refreshed.dns_record_path).unwrap();
        assert!(dns_contents.starts_with("v=DKIM1"));
        assert_ne!(dns_contents.trim(), "old record");
    }

    #[test]
    fn generates_and_persists_keys() {
        let dir = tempfile::tempdir().unwrap();
        let material = ensure_ed25519_keypair(dir.path(), "mail").unwrap();
        assert!(material.private_key_path.exists());
        assert!(material.public_key_path.exists());
        assert!(material.dns_record_path.exists());
        let dns = fs::read_to_string(material.dns_record_path).unwrap();
        assert!(dns.contains("v=DKIM1"));
        assert!(dns.contains("p="));
        assert!(material.public_key.len() > 40);
    }

    #[test]
    fn reuses_existing_keys() {
        let dir = tempfile::tempdir().unwrap();
        let material = ensure_ed25519_keypair(dir.path(), "mail").unwrap();
        let private_before = fs::read(material.private_key_path.clone()).unwrap();
        let public_before = material.public_key.clone();
        let again = ensure_ed25519_keypair(dir.path(), "mail").unwrap();
        let private_after = fs::read(again.private_key_path).unwrap();
        assert_eq!(private_before, private_after);
        assert_eq!(public_before, again.public_key);
    }

    #[test]
    fn signer_builds_header_and_signature() {
        let dir = tempfile::tempdir().unwrap();
        let material = ensure_ed25519_keypair(dir.path(), "mail").unwrap();
        let signer = DkimSigner::from_material(&material).unwrap();
        let headers = "From: Test <test@example.org>\r\nTo: Bob <bob@example.org>\r\nSubject: Hi\r\nDate: Tue, 16 Sep 2025 23:12:33 -0700\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: 7bit\r\n";
        let body = b"hello world\r\n";
        let header_names = [
            "from",
            "to",
            "subject",
            "date",
            "mime-version",
            "content-type",
            "content-transfer-encoding",
        ];
        let header_value = signer
            .sign("example.org", headers, body, &header_names)
            .unwrap();
        assert!(header_value.contains("v=1"));
        assert!(header_value.contains("d=example.org"));
        assert!(header_value.contains("bh="));
        assert!(header_value.contains("b="));
    }

    #[test]
    fn canonicalize_body_multiple_trailing_blank_lines() {
        let body = b"content\r\n\r\n\r\n\r\n";
        let canonical = canonicalize_body_simple(body);
        // Should reduce to single trailing CRLF
        assert_eq!(canonical, b"content\r\n");
    }

    #[test]
    fn canonicalize_body_preserves_internal_blank_lines() {
        let body = b"para1\r\n\r\npara2\r\n";
        let canonical = canonicalize_body_simple(body);
        assert_eq!(canonical, b"para1\r\n\r\npara2\r\n");
    }

    #[test]
    fn extract_header_case_insensitive() {
        let raw = "Subject: test\r\n";
        assert!(extract_header(raw, "subject").is_some());
        assert!(extract_header(raw, "Subject").is_some());
        assert!(extract_header(raw, "SUBJECT").is_some());
    }

    #[test]
    fn extract_header_with_folded_continuation() {
        let raw = "Subject: Long subject\r\n that continues\r\n  on multiple lines\r\n\r\n";
        let header = extract_header(raw, "subject").unwrap();
        assert!(header.contains("Long subject"));
        assert!(header.contains("that continues"));
        assert!(header.contains("on multiple lines"));
    }

    #[test]
    fn extract_header_missing_returns_none() {
        let raw = "From: alice@example.org\r\n";
        assert!(extract_header(raw, "subject").is_none());
    }

    #[test]
    fn collect_signed_headers_with_all_required() {
        let raw = "From: alice@example.org\r\nTo: bob@example.org\r\nSubject: test\r\n\r\n";
        let headers = collect_signed_headers(raw, &["from", "to", "subject"]).unwrap();
        assert_eq!(headers.len(), 3);
    }

    #[test]
    fn collect_signed_headers_preserves_order() {
        let raw = "Subject: test\r\nFrom: alice@example.org\r\nTo: bob@example.org\r\n\r\n";
        let headers = collect_signed_headers(raw, &["subject", "from", "to"]).unwrap();
        // Should preserve the order requested
        assert!(headers[0].starts_with("Subject:"));
        assert!(headers[1].starts_with("From:"));
        assert!(headers[2].starts_with("To:"));
    }

    #[test]
    fn signer_with_empty_body() {
        let dir = tempfile::tempdir().unwrap();
        let material = ensure_ed25519_keypair(dir.path(), "mail").unwrap();
        let signer = DkimSigner::from_material(&material).unwrap();
        let headers = "From: alice@example.org\r\n\r\n";
        let body = b"";

        let dkim_header = signer
            .sign("example.org", headers, body, &["from"])
            .unwrap();

        assert!(dkim_header.contains("bh="));
    }

    #[test]
    fn signer_with_large_body() {
        let dir = tempfile::tempdir().unwrap();
        let material = ensure_ed25519_keypair(dir.path(), "mail").unwrap();
        let signer = DkimSigner::from_material(&material).unwrap();
        let headers = "From: alice@example.org\r\n\r\n";

        // Large body (100KB)
        let large_body = vec![b'x'; 100 * 1024];

        let dkim_header = signer
            .sign("example.org", headers, &large_body, &["from"])
            .unwrap();

        assert!(dkim_header.contains("b="));
    }

    #[test]
    fn ensure_keypair_creates_directory() {
        let dir = tempfile::tempdir().unwrap();
        let subdir = dir.path().join("dkim");

        let material = ensure_ed25519_keypair(&subdir, "mail").unwrap();
        assert!(subdir.exists());
        assert!(material.private_key_path.exists());
    }

    #[test]
    fn dns_record_format() {
        let dir = tempfile::tempdir().unwrap();
        let material = ensure_ed25519_keypair(dir.path(), "mail").unwrap();
        let dns = fs::read_to_string(&material.dns_record_path).unwrap();

        // Per spec: v=DKIM1; k=ed25519; p=<pubkey>
        assert!(dns.starts_with("v=DKIM1"));
        assert!(dns.contains("k=ed25519"));
        assert!(dns.contains(&format!("p={}", material.public_key)));
    }

    #[test]
    fn signer_with_binary_body() {
        let dir = tempfile::tempdir().unwrap();
        let material = ensure_ed25519_keypair(dir.path(), "mail").unwrap();
        let signer = DkimSigner::from_material(&material).unwrap();
        let headers = "From: alice@example.org\r\n\r\n";

        // Binary body with non-UTF8 bytes
        let binary_body = vec![0xFF, 0xFE, 0x00, 0x01, 0xAB, 0xCD];

        let dkim_header = signer
            .sign("example.org", headers, &binary_body, &["from"])
            .unwrap();

        assert!(dkim_header.contains("b="));
    }
}
