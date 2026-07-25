use crate::model::{address::Address, rules::RuleSet};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Route {
    Banned,
    Spam,
    Accepted,
    Quarantine,
}

pub fn evaluate(address: &Address, rules: &RuleSet, spam: &RuleSet, banned: &RuleSet) -> Route {
    if banned.evaluate(address).is_some() {
        Route::Banned
    } else if spam.evaluate(address).is_some() {
        Route::Spam
    } else if rules.evaluate(address).is_some() {
        Route::Accepted
    } else {
        Route::Quarantine
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn precedence_applies() {
        let addr = Address::parse("foo@bar.com", false).unwrap();
        let banned = RuleSet::parse("@bar.com").unwrap();
        let spam = RuleSet::default();
        let accepted = RuleSet::default();
        assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Banned);
    }

    #[test]
    fn accepted_route() {
        let addr = Address::parse("foo@example.com", false).unwrap();
        let banned = RuleSet::default();
        let spam = RuleSet::default();
        let accepted = RuleSet::parse("@example.com").unwrap();
        assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Accepted);
    }

    #[test]
    fn spam_route() {
        let addr = Address::parse("foo@spam.org", false).unwrap();
        let banned = RuleSet::default();
        let spam = RuleSet::parse("@spam.org").unwrap();
        let accepted = RuleSet::default();
        assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Spam);
    }

    #[test]
    fn quarantine_route() {
        let addr = Address::parse("foo@none.org", false).unwrap();
        let banned = RuleSet::default();
        let spam = RuleSet::default();
        let accepted = RuleSet::default();
        assert_eq!(
            evaluate(&addr, &accepted, &spam, &banned),
            Route::Quarantine
        );
    }

    proptest! {
        #[test]
        fn banned_always_wins(local in "[a-z]{1,8}", domain in "[a-z]{1,10}\\.test") {
            let raw = format!("{}@{}", local, domain);
            let addr = Address::parse(&raw, false).unwrap();
            let accepted = RuleSet::parse(&format!("@{}", domain)).unwrap();
            let spam = RuleSet::parse(&format!("{}@{}", local, domain)).unwrap();
            let banned = RuleSet::parse(&format!("@{}", domain)).unwrap();
            prop_assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Banned);
        }

        #[test]
        fn spam_beats_accepted(local in "[a-z]{1,8}", domain in "[a-z]{1,10}\\.example") {
            let raw = format!("{}@{}", local, domain);
            let addr = Address::parse(&raw, false).unwrap();
            let accepted = RuleSet::parse(&format!("@{}", domain)).unwrap();
            let spam = RuleSet::parse(&format!("{}@{}", local, domain)).unwrap();
            let banned = RuleSet::default();
            prop_assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Spam);
        }
    }

    #[test]
    fn banned_precedence_over_all() {
        // Per spec: banned → spam → accepted → quarantine
        let addr = Address::parse("user@example.org", false).unwrap();

        // Address matches all three lists, banned wins
        let accepted = RuleSet::parse("@example.org").unwrap();
        let spam = RuleSet::parse("user@example.org").unwrap();
        let banned = RuleSet::parse("/user/").unwrap();

        assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Banned);
    }

    #[test]
    fn spam_precedence_over_accepted() {
        // spam beats accepted when both match
        let addr = Address::parse("user@spam.org", false).unwrap();

        let accepted = RuleSet::parse("@spam.org").unwrap();
        let spam = RuleSet::parse("user@spam.org").unwrap();
        let banned = RuleSet::default();

        assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Spam);
    }

    #[test]
    fn quarantine_is_default() {
        // Per spec: unmatched goes to quarantine
        let addr = Address::parse("unknown@nowhere.org", false).unwrap();

        let accepted = RuleSet::parse("@example.org").unwrap();
        let spam = RuleSet::parse("@spam.org").unwrap();
        let banned = RuleSet::parse("@banned.org").unwrap();

        assert_eq!(
            evaluate(&addr, &accepted, &spam, &banned),
            Route::Quarantine
        );
    }

    #[test]
    fn empty_rulesets_route_to_quarantine() {
        // All empty rulesets should route to quarantine
        let addr = Address::parse("any@example.org", false).unwrap();

        let accepted = RuleSet::default();
        let spam = RuleSet::default();
        let banned = RuleSet::default();

        assert_eq!(
            evaluate(&addr, &accepted, &spam, &banned),
            Route::Quarantine
        );
    }

    #[test]
    fn regex_rule_in_banned_list() {
        let addr = Address::parse("admin@example.org", false).unwrap();

        let accepted = RuleSet::parse("@example.org").unwrap();
        let spam = RuleSet::default();
        let banned = RuleSet::parse("/^admin@/").unwrap();

        assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Banned);
    }

    #[test]
    fn subdomain_matching_in_precedence() {
        // Test subdomain matching with precedence
        let addr = Address::parse("user@mail.example.org", false).unwrap();

        // Domain suffix @example.org matches mail.example.org
        let accepted = RuleSet::parse("@example.org").unwrap();
        let spam = RuleSet::default();
        let banned = RuleSet::default();

        assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Accepted);
    }

    #[test]
    fn exact_domain_does_not_match_subdomain() {
        let addr = Address::parse("user@mail.example.org", false).unwrap();

        // @=example.org should NOT match mail.example.org
        let accepted = RuleSet::parse("@=example.org").unwrap();
        let spam = RuleSet::default();
        let banned = RuleSet::default();

        assert_eq!(
            evaluate(&addr, &accepted, &spam, &banned),
            Route::Quarantine
        );
    }

    #[test]
    fn multiple_rules_first_match_wins() {
        // Within a list, first matching rule wins
        let addr = Address::parse("user@example.org", false).unwrap();

        let accepted = RuleSet::parse("@example.org\nuser@example.org").unwrap();
        let spam = RuleSet::default();
        let banned = RuleSet::default();

        assert_eq!(evaluate(&addr, &accepted, &spam, &banned), Route::Accepted);
    }
}
