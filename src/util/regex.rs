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

    #[test]
    fn compile_common_patterns() {
        // Common email regex patterns
        assert!(safe_regex("^[a-z]+@example\\.org$").is_some());
        assert!(safe_regex(".*@spam\\..*").is_some());
        assert!(safe_regex("support\\+.*").is_some());
    }

    #[test]
    fn compile_invalid_patterns() {
        // Various invalid regex patterns
        assert!(safe_regex("[").is_none());
        assert!(safe_regex("*").is_none());
        assert!(safe_regex("(?P<invalid").is_none());
        assert!(safe_regex("(unclosed").is_none());
    }

    #[test]
    fn compile_empty_pattern() {
        // Empty pattern should compile (matches empty string)
        assert!(safe_regex("").is_some());
    }

    #[test]
    fn compile_unicode_pattern() {
        // Unicode in patterns should work
        assert!(safe_regex("café").is_some());
        assert!(safe_regex("[а-я]").is_some()); // Cyrillic range
    }

    #[test]
    fn compile_case_insensitive_flag() {
        // Note: safe_regex doesn't add flags, but the pattern should compile
        // Case-insensitive would be done via regex::RegexBuilder
        assert!(safe_regex("(?i)test").is_some());
    }

    #[test]
    fn compile_anchors() {
        assert!(safe_regex("^start").is_some());
        assert!(safe_regex("end$").is_some());
        assert!(safe_regex("^exact$").is_some());
    }

    #[test]
    fn compile_character_classes() {
        assert!(safe_regex("[a-z]").is_some());
        assert!(safe_regex("[0-9]").is_some());
        assert!(safe_regex("[^a-z]").is_some()); // negated class
        assert!(safe_regex("\\d+").is_some()); // digit shorthand
        assert!(safe_regex("\\w+").is_some()); // word shorthand
    }

    #[test]
    fn compile_quantifiers() {
        assert!(safe_regex("a?").is_some()); // 0 or 1
        assert!(safe_regex("a*").is_some()); // 0 or more
        assert!(safe_regex("a+").is_some()); // 1 or more
        assert!(safe_regex("a{2,5}").is_some()); // range
    }

    #[test]
    fn compile_alternation() {
        assert!(safe_regex("cat|dog").is_some());
        assert!(safe_regex("(alice|bob)@example\\.org").is_some());
    }
}
