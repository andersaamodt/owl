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
}
