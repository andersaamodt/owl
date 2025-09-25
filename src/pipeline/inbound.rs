use anyhow::Result;

use crate::{
    envcfg::EnvConfig,
    model::address::Address,
    ruleset::{
        eval::{Route, evaluate},
        loader::LoadedRules,
    },
};

pub fn determine_route(sender: &Address, rules: &LoadedRules, _env: &EnvConfig) -> Result<Route> {
    let route = evaluate(
        sender,
        &rules.accepted.rules,
        &rules.spam.rules,
        &rules.banned.rules,
    );
    let adjusted = match route {
        Route::Accepted => map_status(&rules.accepted.settings.list_status)?,
        Route::Spam => map_status(&rules.spam.settings.list_status)?,
        Route::Banned => map_status(&rules.banned.settings.list_status)?,
        Route::Quarantine => Route::Quarantine,
    };
    Ok(adjusted)
}

fn map_status(status: &str) -> Result<Route> {
    match status {
        "accepted" => Ok(Route::Accepted),
        "rejected" => Ok(Route::Spam),
        "banned" => Ok(Route::Banned),
        other => anyhow::bail!("unknown list_status: {other}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::rules::RuleSet;

    #[test]
    fn banned_wins() {
        let sender = Address::parse("foo@bar.com", false).unwrap();
        let mut rules = LoadedRules::default();
        rules.banned.rules = RuleSet::from_str("@bar.com").unwrap();
        let route = determine_route(&sender, &rules, &EnvConfig::default()).unwrap();
        assert_eq!(route, Route::Banned);
    }

    #[test]
    fn list_status_overrides() {
        let sender = Address::parse("foo@example.com", false).unwrap();
        let mut rules = LoadedRules::default();
        rules.accepted.rules = RuleSet::from_str("@example.com").unwrap();
        rules.accepted.settings.list_status = "banned".into();
        let route = determine_route(&sender, &rules, &EnvConfig::default()).unwrap();
        assert_eq!(route, Route::Banned);
    }

    #[test]
    fn spam_branch_maps_status() {
        let sender = Address::parse("foo@spam.test", false).unwrap();
        let mut rules = LoadedRules::default();
        rules.spam.rules = RuleSet::from_str("@spam.test").unwrap();
        let spam_route = determine_route(&sender, &rules, &EnvConfig::default()).unwrap();
        assert_eq!(spam_route, Route::Spam);
        rules.spam.settings.list_status = "accepted".into();
        let adjusted = determine_route(&sender, &rules, &EnvConfig::default()).unwrap();
        assert_eq!(adjusted, Route::Accepted);
    }

    #[test]
    fn unmatched_is_quarantine() {
        let sender = Address::parse("nobody@unknown.invalid", false).unwrap();
        let rules = LoadedRules::default();
        let route = determine_route(&sender, &rules, &EnvConfig::default()).unwrap();
        assert_eq!(route, Route::Quarantine);
    }

    #[test]
    fn invalid_status_errors() {
        let sender = Address::parse("foo@example.com", false).unwrap();
        let mut rules = LoadedRules::default();
        rules.accepted.rules = RuleSet::from_str("@example.com").unwrap();
        rules.accepted.settings.list_status = "unknown".into();
        let err = determine_route(&sender, &rules, &EnvConfig::default()).unwrap_err();
        assert!(err.to_string().contains("unknown list_status"));
    }
}
