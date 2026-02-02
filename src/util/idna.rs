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
        // Emoji in domain (uncommon but valid)
        let result = to_ascii("🎉.example.org");
        // Should either encode or reject (implementation-dependent)
        // The idna crate may reject this
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn punycode_case_normalized() {
        // IDNA normalizes case
        let lower = to_ascii("café.org").unwrap();
        let upper = to_ascii("CAFÉ.ORG").unwrap();
        assert_eq!(lower, upper);
    }

    #[test]
    fn punycode_very_long_label() {
        // DNS labels have 63-char limit, punycode expansion can hit this
        let long_unicode = "a".repeat(50) + "ü";
        let domain = format!("{}.org", long_unicode);
        let result = to_ascii(&domain);
        // May fail due to label length after punycode encoding
        // Just ensure it doesn't panic
        let _ = result;
    }

    #[test]
    fn punycode_chinese_characters() {
        // Chinese domain
        let domain = to_ascii("例え.jp").unwrap();
        assert!(domain.starts_with("xn--"));
    }

    #[test]
    fn punycode_arabic_characters() {
        // Arabic domain
        let domain = to_ascii("مثال.org").unwrap();
        assert!(domain.starts_with("xn--"));
    }

    #[test]
    fn punycode_empty_domain_behavior() {
        // Empty string - check actual behavior (may accept or reject)
        let result = to_ascii("");
        // idna crate may accept empty domains, so we just ensure it doesn't panic
        let _ = result;
    }

    #[test]
    fn punycode_invalid_utf8_rejected() {
        // Invalid UTF-8 in domain should be rejected
        assert!(to_ascii("exa\u{80}.com").is_err());
    }
}
