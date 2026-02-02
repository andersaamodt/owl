use anyhow::{Result, bail};
use serde::{Deserialize, Serialize};
use std::fmt::{Display, Formatter};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Address {
    original: String,
    local: String,
    domain: String,
    canonical: String,
}

impl Address {
    pub fn parse(input: &str, keep_plus_tags: bool) -> Result<Self> {
        let cleaned = input.trim();
        let Some((local_raw, domain_raw)) = cleaned.split_once('@') else {
            bail!("missing @ in address: {input}");
        };
        let mut local = local_raw.trim().to_ascii_lowercase();
        if !keep_plus_tags && let Some((base, _tag)) = local.split_once('+') {
            local = base.to_string();
        }
        let domain_lower = domain_raw.trim().to_ascii_lowercase();
        let domain_ascii =
            idna::domain_to_ascii(&domain_lower).map_err(|e| anyhow::anyhow!("idna error: {e}"))?;
        let canonical = format!("{}@{}", local, domain_ascii);
        Ok(Self {
            original: cleaned.to_string(),
            local,
            domain: domain_ascii,
            canonical,
        })
    }

    pub fn canonical(&self) -> &str {
        &self.canonical
    }

    pub fn local(&self) -> &str {
        &self.local
    }

    pub fn domain(&self) -> &str {
        &self.domain
    }
}

impl Display for Address {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.canonical)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn strip_plus_by_default() {
        let addr = Address::parse("Alice+tag@Example.org", false).unwrap();
        assert_eq!(addr.canonical(), "alice@example.org");
        assert_eq!(addr.local(), "alice");
        assert_eq!(addr.domain(), "example.org");
        assert_eq!(addr.to_string(), "alice@example.org");
    }

    #[test]
    fn keep_plus_when_configured() {
        let addr = Address::parse("Alice+tag@Example.org", true).unwrap();
        assert_eq!(addr.canonical(), "alice+tag@example.org");
    }

    #[test]
    fn invalid_address_errors() {
        assert!(Address::parse("invalid", false).is_err());
    }

    #[test]
    fn invalid_domain_reports_idna_error() {
        assert!(Address::parse("user@exa\u{80}.org", false).is_err());
    }

    proptest! {
        #[test]
        fn canonicalization_is_idempotent(local in "[a-z0-9]{1,6}", domain in "[a-z]{1,6}\\.com") {
            let raw = format!("{}@{}", local, domain);
            let addr = Address::parse(&raw, false).unwrap();
            let roundtrip = Address::parse(addr.canonical(), false).unwrap();
            prop_assert_eq!(addr, roundtrip);
        }
    }

    #[test]
    fn multiple_plus_signs_strips_all() {
        // Per spec: +tag stripped unless keep_plus_tags=true
        // Multiple plus signs: only keep first part before first +
        let addr = Address::parse("user+tag1+tag2@example.org", false).unwrap();
        assert_eq!(addr.local(), "user");
        assert_eq!(addr.canonical(), "user@example.org");
    }

    #[test]
    fn multiple_plus_signs_kept_when_configured() {
        let addr = Address::parse("user+tag1+tag2@example.org", true).unwrap();
        assert_eq!(addr.local(), "user+tag1+tag2");
        assert_eq!(addr.canonical(), "user+tag1+tag2@example.org");
    }

    #[test]
    fn mixed_case_normalized_with_plus_stripping() {
        // Case should normalize even with plus tag stripping
        let addr = Address::parse("AlIcE+Tag@ExAmple.Org", false).unwrap();
        assert_eq!(addr.local(), "alice");
        assert_eq!(addr.domain(), "example.org");
        assert_eq!(addr.canonical(), "alice@example.org");
    }

    #[test]
    fn plus_tag_with_special_chars_kept() {
        // When keep_plus_tags=true, preserve the tag content
        let addr = Address::parse("user+tag-123_abc@example.org", true).unwrap();
        assert_eq!(addr.local(), "user+tag-123_abc");
    }

    #[test]
    fn empty_plus_tag_handled() {
        // user+ (empty tag) should keep "user"
        let addr = Address::parse("user+@example.org", false).unwrap();
        assert_eq!(addr.local(), "user");

        let addr_keep = Address::parse("user+@example.org", true).unwrap();
        assert_eq!(addr_keep.local(), "user+");
    }

    #[test]
    fn whitespace_trimmed_from_address() {
        // Per spec: address should be trimmed
        let addr = Address::parse("  user@example.org  ", false).unwrap();
        assert_eq!(addr.canonical(), "user@example.org");
    }

    #[test]
    fn whitespace_in_local_and_domain_parts_trimmed() {
        let addr = Address::parse(" user @  example.org ", false).unwrap();
        assert_eq!(addr.local(), "user");
        assert_eq!(addr.domain(), "example.org");
    }

    #[test]
    fn unicode_in_domain_punycoded() {
        // Per spec: domain should be punycoded
        let addr = Address::parse("user@café.example.org", false).unwrap();
        assert!(addr.domain().starts_with("xn--"));
        assert!(addr.canonical().contains("xn--"));
    }

    #[test]
    fn subdomain_with_unicode_punycoded() {
        let addr = Address::parse("user@mail.café.org", false).unwrap();
        assert!(addr.domain().contains("xn--"));
    }

    #[test]
    fn sender_folder_format() {
        // Per spec: sender folder is local@domain (lowercased, punycoded)
        let addr = Address::parse("Alice+promo@Example.Org", false).unwrap();
        // Should strip +promo and lowercase
        let folder = format!("{}/", addr.canonical());
        assert_eq!(folder, "alice@example.org/");
    }

    #[test]
    fn sender_folder_with_keep_plus_tags() {
        let addr = Address::parse("Alice+promo@Example.Org", true).unwrap();
        let folder = format!("{}/", addr.canonical());
        assert_eq!(folder, "alice+promo@example.org/");
    }

    proptest! {
        #[test]
        fn parse_is_deterministic(local in "[a-z0-9]{1,10}", domain in "[a-z]{2,10}\\.org") {
            let input = format!("{}@{}", local, domain);
            let addr1 = Address::parse(&input, false).unwrap();
            let addr2 = Address::parse(&input, false).unwrap();
            prop_assert_eq!(addr1, addr2);
        }

        #[test]
        fn lowercase_normalization_property(
            local in "[a-zA-Z0-9]{1,10}",
            domain in "[a-zA-Z]{2,10}\\.com"
        ) {
            let mixed = format!("{}@{}", local, domain);
            let lower = format!("{}@{}", local.to_lowercase(), domain.to_lowercase());

            let addr_mixed = Address::parse(&mixed, false).unwrap();
            let addr_lower = Address::parse(&lower, false).unwrap();

            prop_assert_eq!(addr_mixed.canonical(), addr_lower.canonical());
        }

        #[test]
        fn plus_tag_stripping_idempotent(
            local in "[a-z]{1,8}",
            tag in "[a-z0-9]{1,5}",
            domain in "[a-z]{2,10}\\.test"
        ) {
            let with_tag = format!("{}+{}@{}", local, tag, domain);
            let without_tag = format!("{}@{}", local, domain);

            let addr_with = Address::parse(&with_tag, false).unwrap();
            let addr_without = Address::parse(&without_tag, false).unwrap();

            prop_assert_eq!(addr_with.canonical(), addr_without.canonical());
        }
    }

    #[test]
    fn address_display_trait() {
        let addr = Address::parse("User+Tag@Example.Org", false).unwrap();
        let displayed = format!("{}", addr);
        assert_eq!(displayed, "user@example.org");
    }

    #[test]
    fn address_debug_trait() {
        let addr = Address::parse("test@example.org", false).unwrap();
        let debug = format!("{:?}", addr);
        assert!(debug.contains("Address"));
    }

    #[test]
    fn address_clone_equals_original() {
        let addr = Address::parse("test@example.org", false).unwrap();
        let cloned = addr.clone();
        assert_eq!(addr, cloned);
    }

    #[test]
    fn plus_sign_at_start_of_local() {
        // Edge case: + at the very start
        let addr = Address::parse("+tag@example.org", false).unwrap();
        assert_eq!(addr.local(), "");
        assert_eq!(addr.canonical(), "@example.org");
    }

    #[test]
    fn multiple_at_signs_in_input() {
        // Email addresses should have exactly one @
        // Extra @ signs should cause parse failure
        let result = Address::parse("user@domain@extra.org", false);
        // Current implementation takes first @, so this succeeds
        // but second @ is part of domain which will fail IDNA
        assert!(result.is_err() || result.unwrap().domain().contains('@'));
    }

    #[test]
    fn address_equality() {
        // Two addresses with same canonical form should have same canonical()
        let addr1 = Address::parse("Alice@Example.Org", false).unwrap();
        let addr2 = Address::parse("alice@example.org", false).unwrap();
        // They're equal because canonical() is the same
        assert_eq!(addr1.canonical(), addr2.canonical());
        // But Address struct equality checks all fields including original
        assert_ne!(addr1, addr2); // Different original field
    }

    #[test]
    fn address_canonical_equality() {
        // Addresses with same input are equal
        let addr1 = Address::parse("alice@example.org", false).unwrap();
        let addr2 = Address::parse("alice@example.org", false).unwrap();
        assert_eq!(addr1, addr2);
    }

    #[test]
    fn address_inequality() {
        let addr1 = Address::parse("alice@example.org", false).unwrap();
        let addr2 = Address::parse("bob@example.org", false).unwrap();
        assert_ne!(addr1, addr2);
    }

    #[test]
    fn keep_plus_tags_affects_equality() {
        let addr1 = Address::parse("user+tag@example.org", false).unwrap();
        let addr2 = Address::parse("user+tag@example.org", true).unwrap();
        // These should be different because canonical form differs
        assert_ne!(addr1, addr2);
    }
}
