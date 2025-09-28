use std::fs;
use std::path::{Path, PathBuf};

use anyhow::Result;

use crate::model::{rules::RuleSet, settings::ListSettings};

#[derive(Debug, Clone)]
pub struct RulesetLoader {
    root: PathBuf,
}

impl RulesetLoader {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    pub fn load(&self) -> Result<LoadedRules> {
        Ok(LoadedRules {
            accepted: self.load_list("accepted")?,
            spam: self.load_list("spam")?,
            banned: self.load_list("banned")?,
        })
    }

    fn load_list(&self, name: &str) -> Result<LoadedList> {
        let dir = self.root.join(name);
        let rules = self.load_rules(&dir)?;
        let settings = self.load_settings(&dir, name)?;
        Ok(LoadedList { rules, settings })
    }

    fn load_rules(&self, dir: &Path) -> Result<RuleSet> {
        let path = dir.join(".rules");
        if path.exists() {
            let data = fs::read_to_string(path)?;
            RuleSet::parse(&data)
        } else {
            Ok(RuleSet::default())
        }
    }

    fn load_settings(&self, dir: &Path, list: &str) -> Result<ListSettings> {
        let path = dir.join(".settings");
        if path.exists() {
            let data = fs::read_to_string(path)?;
            ListSettings::parse(&data)
        } else {
            Ok(default_settings_for(list))
        }
    }
}

fn default_settings_for(list: &str) -> ListSettings {
    let list_status = match list {
        "spam" => "rejected".into(),
        "banned" => "banned".into(),
        _ => "accepted".into(),
    };
    ListSettings {
        list_status,
        ..ListSettings::default()
    }
}

#[derive(Debug, Clone, Default)]
pub struct LoadedList {
    pub rules: RuleSet,
    pub settings: ListSettings,
}

#[derive(Debug, Clone)]
pub struct LoadedRules {
    pub accepted: LoadedList,
    pub spam: LoadedList,
    pub banned: LoadedList,
}

impl Default for LoadedRules {
    fn default() -> Self {
        Self {
            accepted: LoadedList {
                rules: RuleSet::default(),
                settings: default_settings_for("accepted"),
            },
            spam: LoadedList {
                rules: RuleSet::default(),
                settings: default_settings_for("spam"),
            },
            banned: LoadedList {
                rules: RuleSet::default(),
                settings: default_settings_for("banned"),
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn loads_missing_files_as_empty() {
        let dir = tempfile::tempdir().unwrap();
        let loader = RulesetLoader::new(dir.path());
        let rules = loader.load().unwrap();
        assert!(rules.accepted.rules.rules().is_empty());
        assert_eq!(rules.accepted.settings.list_status, "accepted");
    }

    #[test]
    fn loads_present_rules() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("accepted/.rules");
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, "@example.org\n").unwrap();
        std::fs::write(
            dir.path().join("accepted/.settings"),
            "list_status=banned\n",
        )
        .unwrap();
        let loader = RulesetLoader::new(dir.path());
        let rules = loader.load().unwrap();
        assert!(!rules.accepted.rules.rules().is_empty());
        assert_eq!(rules.accepted.settings.list_status, "banned");
    }

    #[test]
    fn missing_settings_use_list_defaults() {
        let dir = tempfile::tempdir().unwrap();
        let loader = RulesetLoader::new(dir.path());
        let rules = loader.load().unwrap();
        assert_eq!(rules.spam.settings.list_status, "rejected");
        assert_eq!(rules.banned.settings.list_status, "banned");
    }
}
