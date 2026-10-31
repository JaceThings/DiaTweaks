use std::{
    path::{Path, PathBuf},
    process::Command,
};

use anyhow::{bail, Context, Result};
use serde::Deserialize;

use crate::{
    child::{self, Finished, OnInterrupt},
    env::Env,
    signals::{self, Cancelled},
    ui::Spinner,
};

/// The installed diapatch, which does everything that touches Dia's app bundles.
pub struct Diapatch(PathBuf);

/// `diapatch status --json`. Versions look like "1.55.1 (89833)".
#[derive(Deserialize)]
pub struct Status {
    pub official: Option<String>,
    pub installed: Option<String>,
    pub patched: bool,
    pub staged: Option<String>,
    pub feed: Option<String>,
    pub channel: String,
}

impl Diapatch {
    pub fn find(env: &Env) -> Result<Self> {
        let path = env.diapatch();
        if !path.is_file() {
            bail!(
                "DiaTweaks isn't installed: {} is missing. Run install.sh first.",
                path.display()
            );
        }
        Ok(Self(path))
    }

    pub fn run(
        &self,
        args: &[&str],
        on_interrupt: OnInterrupt,
        spinner: &Spinner,
    ) -> Result<Finished> {
        child::run(Command::new(&self.0).args(args), on_interrupt, spinner)
    }

    /// Also asks Dia's update feed, for up to 15 seconds.
    pub fn status(&self, spinner: &Spinner) -> Result<Status> {
        let done = self.run(&["status", "--json"], OnInterrupt::StopDownloads, spinner)?;
        if signals::interrupted() {
            bail!(Cancelled::nothing_changed());
        }
        let json = done.output.lines().rev().find(|line| line.starts_with('{'));
        match (done.status.success(), json) {
            (true, Some(json)) => serde_json::from_str(json)
                .context("diapatch status gave an answer diatweaks can't read"),
            _ => bail!("diapatch status failed:\n{}", done.tail(5)),
        }
    }
}

pub fn is_patched(app: &Path) -> bool {
    plist::Value::from_file(app.join("Contents/Info.plist"))
        .ok()
        .and_then(|info| info.as_dictionary()?.get("DiaPatches")?.as_boolean())
        .unwrap_or(false)
}

/// 0 normally; 1 or 2 after Dia quit unexpectedly right after opening (see SafeMode.m).
pub fn safe_mode(support: &Path) -> i64 {
    plist::Value::from_file(support.join("safe-mode.plist"))
        .ok()
        .and_then(|state| state.as_dictionary()?.get("level")?.as_signed_integer())
        .unwrap_or(0)
}

/// Dia's processes, helpers included: everything running from inside the app bundle.
fn processes(app: &Path) -> Vec<(libc::pid_t, PathBuf)> {
    let Ok(root) = app.canonicalize() else {
        return Vec::new();
    };
    child::all_pids()
        .into_iter()
        .filter_map(|pid| child::pid_path(pid).map(|path| (pid, path)))
        .filter(|(_, path)| path.starts_with(&root))
        .collect()
}

pub fn is_running(app: &Path) -> bool {
    !processes(app).is_empty()
}
