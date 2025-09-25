use regex::Regex;

pub fn safe_regex(pattern: &str) -> Option<Regex> {
    Regex::new(pattern).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compile_valid() {
        assert!(safe_regex("foo").is_some());
        assert!(safe_regex("(").is_none());
    }
}
