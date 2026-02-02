use crate::model::address::Address;
use anyhow::{Result, bail};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Rule {
    ExactAddress(String),
    DomainSuffix(String),
    DomainExact(String),
    Regex(String),
}

impl Rule {
    pub fn parse(line: &str) -> Result<Self> {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            bail!("empty rule");
        }
        if trimmed.starts_with('/') && trimmed.ends_with('/') {
            let body = &trimmed[1..trimmed.len() - 1];
            Regex::new(body).map_err(|e| anyhow::anyhow!("invalid regex: {e}"))?;
            return Ok(Self::Regex(body.to_string()));
        }
        if let Some(addr) = trimmed.strip_prefix('@') {
            if let Some(domain) = addr.strip_prefix('=') {
                return Ok(Self::DomainExact(domain.to_ascii_lowercase()));
            }
            return Ok(Self::DomainSuffix(addr.to_ascii_lowercase()));
        }
        if trimmed.contains('@') {
            return Ok(Self::ExactAddress(trimmed.to_ascii_lowercase()));
        }
        bail!("unsupported rule: {trimmed}");
    }

    pub fn matches(&self, address: &Address) -> bool {
        match self {
            Rule::ExactAddress(value) => address.canonical() == value,
            Rule::DomainSuffix(value) => address.domain().ends_with(value.trim_start_matches('.')),
            Rule::DomainExact(value) => address.domain() == value,
            Rule::Regex(value) => Regex::new(value)
                .ok()
                .map(|re| re.is_match(address.canonical()))
                .unwrap_or(false),
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct RuleSet {
    rules: Vec<Rule>,
}

impl RuleSet {
    pub fn parse(data: &str) -> Result<Self> {
        let mut rules = Vec::new();
        for line in data.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            rules.push(Rule::parse(trimmed)?);
        }
        Ok(Self { rules })
    }

    pub fn evaluate(&self, address: &Address) -> Option<Rule> {
        for rule in &self.rules {
            if rule.matches(address) {
                return Some(rule.clone());
            }
        }
        None
    }

    pub fn rules(&self) -> &[Rule] {
        &self.rules
    }
}

impl FromStr for RuleSet {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::parse(s)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn parse_suffix() {
        let rule = Rule::parse("@example.org").unwrap();
        assert!(matches!(rule, Rule::DomainSuffix(value) if value == "example.org"));
    }

    #[test]
    fn regex_rule_matches() {
        let rule = Rule::parse("/foo/").unwrap();
        let addr = Address::parse("foo@example.org", false).unwrap();
        assert!(rule.matches(&addr));
    }

    #[test]
    fn domain_suffix_trims_leading_dot() {
        let rule = Rule::parse("@.Example.Org").unwrap();
        let addr = Address::parse("user@example.org", false).unwrap();
        assert!(rule.matches(&addr));
    }

    #[test]
    fn ruleset_evaluates_in_order() {
        let data = "@example.org\ncarol@example.org";
        let set: RuleSet = data.parse().unwrap();
        let addr = Address::parse("carol@example.org", false).unwrap();
        let matched = set.evaluate(&addr).unwrap();
        assert!(matches!(matched, Rule::DomainSuffix(_)));
    }

    #[test]
    fn rejects_empty_rule() {
        assert!(Rule::parse("   ").is_err());
    }

    #[test]
    fn exact_address_rule_matches() {
        let rule = Rule::parse("carol@example.org").unwrap();
        let addr = Address::parse("carol@example.org", false).unwrap();
        assert!(rule.matches(&addr));
    }

    #[test]
    fn domain_exact_rule_matches() {
        let rule = Rule::parse("@=example.org").unwrap();
        let addr = Address::parse("bob@example.org", false).unwrap();
        assert!(rule.matches(&addr));
    }

    #[test]
    fn invalid_regex_is_safe() {
        let rule = Rule::Regex("[".into());
        let addr = Address::parse("carol@example.org", false).unwrap();
        assert!(!rule.matches(&addr));
    }

    #[test]
    fn parse_invalid_regex_errors() {
        let err = Rule::parse("/[/").unwrap_err();
        assert!(err.to_string().contains("invalid regex"));
    }

    #[test]
    fn unsupported_rule_fails() {
        assert!(Rule::parse("invalid").is_err());
    }

    #[test]
    fn domain_suffix_matches_subdomains() {
        // Per spec: @example.org matches subdomains
        let rule = Rule::parse("@example.org").unwrap();
        let addr = Address::parse("user@mail.example.org", false).unwrap();
        assert!(rule.matches(&addr), "Domain suffix should match subdomains");
    }

    #[test]
    fn domain_exact_does_not_match_subdomains() {
        // Per spec: @=example.org matches exact domain only
        let rule = Rule::parse("@=example.org").unwrap();
        let addr = Address::parse("user@mail.example.org", false).unwrap();
        assert!(
            !rule.matches(&addr),
            "Domain exact should not match subdomains"
        );

        let exact_addr = Address::parse("user@example.org", false).unwrap();
        assert!(
            rule.matches(&exact_addr),
            "Domain exact should match exact domain"
        );
    }

    #[test]
    fn regex_rule_with_special_chars() {
        // Test POSIX ERE regex with common patterns
        // Note: addresses are canonicalized (+ stripped by default)
        let rule = Rule::parse(r"/^support.*@example\.org$/").unwrap();
        let addr = Address::parse("support-tickets@example.org", false).unwrap();
        assert!(rule.matches(&addr));

        let non_match = Address::parse("help@example.org", false).unwrap();
        assert!(!rule.matches(&non_match));
    }

    #[test]
    fn parse_comment_line_errors() {
        let err = Rule::parse("# This is a comment").expect_err("expected error");
        assert!(err.to_string().contains("empty rule"));
    }

    #[test]
    fn ruleset_parse_with_blank_lines() {
        let data = "@example.org\n\n@another.org\n\n";
        let set: RuleSet = data.parse().unwrap();
        assert_eq!(set.rules().len(), 2);
    }

    #[test]
    fn ruleset_parse_with_comments() {
        let data = "# Comment line\n@example.org\n# Another comment\nuser@test.org";
        let set: RuleSet = data.parse().unwrap();
        assert_eq!(set.rules().len(), 2);
    }

    #[test]
    fn ruleset_evaluate_returns_none_for_no_match() {
        let data = "@example.org";
        let set: RuleSet = data.parse().unwrap();
        let addr = Address::parse("user@other.org", false).unwrap();
        assert!(set.evaluate(&addr).is_none());
    }

    #[test]
    fn ruleset_empty() {
        let set = RuleSet::default();
        assert!(set.rules().is_empty());

        let addr = Address::parse("any@example.org", false).unwrap();
        assert!(set.evaluate(&addr).is_none());
    }

    #[test]
    fn exact_address_case_insensitive() {
        let rule = Rule::parse("Alice@Example.Org").unwrap();
        let addr = Address::parse("alice@example.org", false).unwrap();
        assert!(rule.matches(&addr));
    }

    #[test]
    fn domain_suffix_case_insensitive() {
        let rule = Rule::parse("@Example.Org").unwrap();
        let addr = Address::parse("user@EXAMPLE.ORG", false).unwrap();
        assert!(rule.matches(&addr));
    }

    #[test]
    fn domain_exact_case_insensitive() {
        let rule = Rule::parse("@=Example.Org").unwrap();
        let addr = Address::parse("user@example.org", false).unwrap();
        assert!(rule.matches(&addr));
    }

    #[test]
    fn regex_rule_with_anchors() {
        let rule = Rule::parse(r"/^admin@/").unwrap();
        let match_addr = Address::parse("admin@example.org", false).unwrap();
        assert!(rule.matches(&match_addr));

        let no_match = Address::parse("user@admin.org", false).unwrap();
        assert!(!rule.matches(&no_match));
    }

    #[test]
    fn regex_rule_case_sensitive() {
        // Regex is case-sensitive unless specified otherwise
        let rule = Rule::parse(r"/ADMIN/").unwrap();
        let lowercase = Address::parse("admin@example.org", false).unwrap();
        // Address is canonicalized to lowercase, so this won't match
        assert!(!rule.matches(&lowercase));
    }

    #[test]
    fn regex_rule_with_alternation() {
        let rule = Rule::parse(r"/^(admin|support)@example\.org$/").unwrap();
        let admin = Address::parse("admin@example.org", false).unwrap();
        let support = Address::parse("support@example.org", false).unwrap();
        let other = Address::parse("user@example.org", false).unwrap();

        assert!(rule.matches(&admin));
        assert!(rule.matches(&support));
        assert!(!rule.matches(&other));
    }

    #[test]
    fn domain_suffix_with_leading_dot() {
        let rule = Rule::parse("@.example.org").unwrap();
        let subdomain = Address::parse("user@mail.example.org", false).unwrap();
        let exact = Address::parse("user@example.org", false).unwrap();

        // Leading dot is trimmed, so it matches both
        assert!(rule.matches(&subdomain));
        assert!(rule.matches(&exact));
    }

    #[test]
    fn multiple_level_subdomain() {
        let rule = Rule::parse("@example.org").unwrap();
        let deep = Address::parse("user@a.b.c.example.org", false).unwrap();
        assert!(rule.matches(&deep));
    }

    #[test]
    fn exact_address_with_plus_tag() {
        // Plus tags are stripped during canonicalization by default
        let rule = Rule::parse("alice@example.org").unwrap();
        let with_tag = Address::parse("alice+tag@example.org", false).unwrap();
        assert!(rule.matches(&with_tag));
    }

    #[test]
    fn ruleset_first_match_wins() {
        let data = "@example.org\nalice@example.org\n/.*@example.org/";
        let set: RuleSet = data.parse().unwrap();
        let addr = Address::parse("alice@example.org", false).unwrap();

        let matched = set.evaluate(&addr).unwrap();
        // First rule (@example.org) should match
        assert!(matches!(matched, Rule::DomainSuffix(_)));
    }

    #[test]
    fn rule_parse_with_whitespace() {
        let rule = Rule::parse("  @example.org  ").unwrap();
        assert!(matches!(rule, Rule::DomainSuffix(_)));
    }

    #[test]
    fn invalid_rule_format() {
        assert!(Rule::parse("not-an-email-or-pattern").is_err());
        assert!(Rule::parse("").is_err());
        assert!(Rule::parse("   ").is_err()); // whitespace only
    }

    proptest! {
        #[test]
        fn domain_suffix_always_matches_subdomain(
            subdomain in "[a-z]{1,10}",
            domain in "[a-z]{2,10}\\.test"
        ) {
            let full_domain = format!("{}.{}", subdomain, domain);
            let rule = Rule::parse(&format!("@{}", domain)).unwrap();
            let addr = Address::parse(&format!("user@{}", full_domain), false).unwrap();
            prop_assert!(rule.matches(&addr));
        }

        #[test]
        fn domain_exact_never_matches_subdomain(
            subdomain in "[a-z]{1,10}",
            domain in "[a-z]{2,10}\\.test"
        ) {
            let full_domain = format!("{}.{}", subdomain, domain);
            let rule = Rule::parse(&format!("@={}", domain)).unwrap();
            let addr = Address::parse(&format!("user@{}", full_domain), false).unwrap();
            prop_assert!(!rule.matches(&addr));
        }

        #[test]
        fn exact_address_match_deterministic(
            local in "[a-z]{1,10}",
            domain in "[a-z]{2,10}\\.org"
        ) {
            let email = format!("{}@{}", local, domain);
            let rule = Rule::parse(&email).unwrap();
            let addr = Address::parse(&email, false).unwrap();
            prop_assert!(rule.matches(&addr));
        }
    }

    #[test]
    fn rule_equality() {
        let rule1 = Rule::parse("@example.org").unwrap();
        let rule2 = Rule::parse("@example.org").unwrap();
        assert_eq!(rule1, rule2);
    }

    #[test]
    fn rule_inequality() {
        let rule1 = Rule::parse("@example.org").unwrap();
        let rule2 = Rule::parse("@test.org").unwrap();
        assert_ne!(rule1, rule2);
    }

    #[test]
    fn rule_clone_equals_original() {
        let rule = Rule::parse("@example.org").unwrap();
        let cloned = rule.clone();
        assert_eq!(rule, cloned);
    }

    #[test]
    fn regex_with_empty_pattern() {
        // Empty regex pattern
        let rule = Rule::parse("//").unwrap();
        // Empty regex matches everything
        let addr = Address::parse("any@example.org", false).unwrap();
        assert!(rule.matches(&addr));
    }

    #[test]
    fn regex_with_dot_metachar() {
        // Dot in regex matches any character
        let rule = Rule::parse(r"/a.b@example\.org/").unwrap();
        let match1 = Address::parse("aXb@example.org", false).unwrap();
        let match2 = Address::parse("a@b@example.org", false).unwrap();

        assert!(rule.matches(&match1));
        // Second @ would fail IDNA, so this won't parse correctly
        assert!(match2.domain().contains("@") || !rule.matches(&match2));
    }

    #[test]
    fn ruleset_with_only_comments() {
        let data = "# comment 1\n# comment 2\n# comment 3";
        let set = RuleSet::parse(data).unwrap();
        assert!(set.rules().is_empty());
    }

    #[test]
    fn ruleset_debug_display() {
        let set = RuleSet::parse("@example.org").unwrap();
        let debug = format!("{:?}", set);
        assert!(debug.contains("RuleSet"));
    }
}
