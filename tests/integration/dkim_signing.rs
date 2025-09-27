use base64::{engine::general_purpose::STANDARD, Engine as _};
use owl::{
    envcfg::EnvConfig,
    fsops::layout::MailLayout,
    pipeline::outbox::OutboxPipeline,
    util::dkim::{self, canonicalize_body_simple},
    util::logging::{LogLevel, Logger},
};
use ring::signature::UnparsedPublicKey;
use sha2::{Digest, Sha256};

fn parse_tag(value: &str, tag: &str) -> Option<String> {
    value
        .split(';')
        .filter_map(|part| {
            let trimmed = part.trim();
            let (key, val) = trimmed.split_once('=')?;
            if key.eq_ignore_ascii_case(tag) {
                Some(val.to_string())
            } else {
                None
            }
        })
        .next()
}

#[test]
fn queued_message_has_valid_dkim_signature() {
    let dir = tempfile::tempdir().unwrap();
    let layout = MailLayout::new(dir.path());
    layout.ensure().unwrap();
    let env = EnvConfig::default();
    let logger = Logger::new(layout.root(), LogLevel::Off).unwrap();
    let pipeline = OutboxPipeline::new(layout.clone(), env.clone(), logger);

    let draft_ulid = owl::util::ulid::generate();
    let draft_path = layout.drafts().join(format!("{draft_ulid}.md"));
    std::fs::write(
        &draft_path,
        "---\nsubject: Check-in\nfrom: Owl <owl@example.org>\nto:\n  - Dana <dana@example.org>\n---\nHi Dana,\n",
    )
    .unwrap();

    let message_path = pipeline.queue_draft(&draft_path).unwrap();
    let message_bytes = std::fs::read(&message_path).unwrap();
    let message = String::from_utf8(message_bytes.clone()).unwrap();
    let (headers_section, body_section) = message.split_once("\r\n\r\n").unwrap();
    let dkim_header = dkim::extract_header(headers_section, "dkim-signature").unwrap();
    let value = dkim_header
        .strip_prefix("DKIM-Signature:")
        .unwrap()
        .trim();
    let signature_b64 = parse_tag(value, "b").unwrap();
    let body_hash_b64 = parse_tag(value, "bh").unwrap();
    let header_list = parse_tag(value, "h").unwrap();
    let header_names: Vec<&str> = header_list.split(':').collect();

    let canonical_body = canonicalize_body_simple(body_section.as_bytes());
    let computed_hash = Sha256::digest(&canonical_body);
    assert_eq!(STANDARD.encode(computed_hash), body_hash_b64);

    let signed_headers = dkim::collect_signed_headers(headers_section, &header_names).unwrap();
    let mut to_verify = Vec::new();
    for header in signed_headers {
        to_verify.extend_from_slice(header.as_bytes());
    }
    let sig_index = dkim_header.find("b=").unwrap();
    let unsigned = format!("{}\r\n", &dkim_header[..sig_index + 2]);
    to_verify.extend_from_slice(unsigned.as_bytes());

    let public_key_b64 = std::fs::read_to_string(layout.dkim_public_key(&env.dkim_selector))
        .unwrap()
        .trim()
        .to_string();
    let public_key = STANDARD.decode(public_key_b64).unwrap();
    let signature = STANDARD.decode(signature_b64.trim()).unwrap();
    let verifier = UnparsedPublicKey::new(&ring::signature::ED25519, public_key);
    verifier.verify(&to_verify, &signature).unwrap();
}
