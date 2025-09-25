use ring::hmac;

#[test]
fn hmac_signature_roundtrip() {
    let key = hmac::Key::new(hmac::HMAC_SHA256, b"secret");
    let tag = hmac::sign(&key, b"payload");
    hmac::verify(&key, b"payload", tag.as_ref()).unwrap();
}
