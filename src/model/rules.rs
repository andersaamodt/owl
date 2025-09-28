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
    fn unsupported_rule_fails() {
        assert!(Rule::parse("invalid").is_err());
    }
}
