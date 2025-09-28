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

    proptest! {
        #[test]
        fn canonicalization_is_idempotent(local in "[a-z0-9]{1,6}", domain in "[a-z]{1,6}\\.com") {
            let raw = format!("{}@{}", local, domain);
            let addr = Address::parse(&raw, false).unwrap();
            let roundtrip = Address::parse(addr.canonical(), false).unwrap();
            prop_assert_eq!(addr, roundtrip);
        }
    }
}
