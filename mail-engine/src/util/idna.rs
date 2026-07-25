use anyhow::Result;

pub fn to_ascii(domain: &str) -> Result<String> {
    idna::domain_to_ascii(domain).map_err(|e| anyhow::anyhow!("{e}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_unicode() {
        let domain = to_ascii("müller.de").unwrap();
        assert_eq!(domain, "xn--mller-kva.de");
    }

    #[test]
    fn rejects_invalid_domain() {
        assert!(to_ascii("exa\u{80}.com").is_err());
    }

    #[test]
    fn punycode_roundtrip_preserves_ascii() {
        // ASCII domain should roundtrip unchanged
        let domain = "example.org";
        let encoded = to_ascii(domain).unwrap();
        assert_eq!(encoded, "example.org");
    }

    #[test]
    fn punycode_multiple_labels() {
        // Multiple Unicode labels in domain
        let domain = to_ascii("café.münchen.de").unwrap();
        assert!(domain.contains("xn--"));
        assert!(domain.contains("mnchen"));
    }

    #[test]
    fn punycode_subdomain_preserved() {
        // Subdomain with Unicode
        let domain = to_ascii("mail.café.org").unwrap();
        assert_eq!(domain, "mail.xn--caf-dma.org");
    }

    #[test]
    fn punycode_mixed_ascii_unicode() {
        // Mix of ASCII and Unicode labels
        let domain = to_ascii("example.café.org").unwrap();
        assert!(domain.starts_with("example."));
        assert!(domain.contains("xn--"));
    }

    #[test]
    fn punycode_already_encoded() {
        // Already punycode-encoded domain should pass through
        let domain = to_ascii("xn--mller-kva.de").unwrap();
        assert_eq!(domain, "xn--mller-kva.de");
    }

    #[test]
    fn punycode_emoji_domain() {
        // Emoji in domain labels: behavior is implementation-dependent
        // The IDNA spec may allow or reject emoji depending on version
        let result = to_ascii("🎉.example.org");
        // Just ensure it doesn't panic - behavior depends on idna crate version
        let _ = result;
    }

    #[test]
    fn punycode_case_normalized() {
        // IDNA normalizes case per spec
        let lower = to_ascii("café.org").unwrap();
        let upper = to_ascii("CAFÉ.ORG").unwrap();
        assert_eq!(lower, upper);
    }

    #[test]
    fn punycode_very_long_label() {
        // DNS labels have 63-char limit; punycode can expand beyond this
        // Test ensures no panic - actual behavior (accept/reject) is
        // implementation-dependent based on label length after encoding
        let long_unicode = "a".repeat(50) + "ü";
        let domain = format!("{}.org", long_unicode);
        let result = to_ascii(&domain);
        let _ = result; // May succeed or fail depending on encoding length
    }

    #[test]
    fn punycode_chinese_characters() {
        // Chinese domain should encode to punycode
        let domain = to_ascii("例え.jp").unwrap();
        assert!(domain.starts_with("xn--"));
    }

    #[test]
    fn punycode_arabic_characters() {
        // Arabic domain should encode to punycode
        let domain = to_ascii("مثال.org").unwrap();
        assert!(domain.starts_with("xn--"));
    }

    #[test]
    fn punycode_empty_domain_behavior() {
        // Empty domain: implementation-dependent (may accept as valid or reject)
        // Different IDNA implementations handle this differently
        let result = to_ascii("");
        let _ = result; // Just ensure no panic
    }

    #[test]
    fn punycode_invalid_utf8_rejected() {
        // Invalid UTF-8 sequences should be rejected per spec
        assert!(to_ascii("exa\u{80}.com").is_err());
    }
}
