use std::{fs, path::Path, process::Command, time::Duration};

use anyhow::{bail, Context, Result};

use crate::{
    child::{self, OnInterrupt},
    env::Env,
    lock,
    signals::Cancelled,
    status::{short, COMMIT},
    ui::{Spinner, Ui},
};

const FINISHING: &str = "Finishing the install so Dia isn't left half-patched…";

/// `diatweaks update`: fetch the newest DiaTweaks into a temporary checkout in the support folder,
/// build it, and let its install.sh install it and patch Dia again, even when nothing is new, so
/// it also repairs an install.
pub fn run(env: &Env, ui: &Ui) -> Result<()> {
    if !env.app.exists() {
        bail!(
            "Dia isn't installed at {}. Get it from https://www.diabrowser.com first.",
            env.app.display()
        );
    }
    check_developer_tools()?;
    fs::create_dir_all(&env.support)
        .with_context(|| format!("Couldn't create {}", env.support.display()))?;
    let _lock = lock::acquire(&env.support)?;
    remove_stale_checkouts(&env.support);
    if !ui.proceed(
        "Update DiaTweaks? It downloads and builds the newest version, then reopens Dia.",
    )? {
        return Err(Cancelled::nothing_changed().into());
    }

    let work = tempfile::Builder::new()
        .prefix(".update-")
        .tempdir_in(&env.support)
        .context("Couldn't create a temporary folder")?;
    let source = work.path().join("DiaTweaks");

    let spinner = ui.spinner("Downloading DiaTweaks");
    let (commit, subject) = spinner.check(clone(&env.repo, &source, &spinner))?;
    spinner.stop(format_args!(
        "Downloaded DiaTweaks {}: {subject}",
        short(&commit)
    ));

    let spinner = ui.spinner("Building DiaTweaks. This can take a couple of minutes");
    let has_cargo = spinner.check(build(&source, &spinner))?;
    spinner.stop("Built DiaTweaks");

    let spinner = ui.spinner("Installing DiaTweaks and reopening Dia");
    let done = spinner.check(child::run(
        Command::new("./install.sh")
            .arg("--yes")
            .current_dir(&source),
        OnInterrupt::Finish(FINISHING),
        &spinner,
    ))?;
    match done.status.code() {
        Some(0) => spinner.stop(format_args!("Installed DiaTweaks {}", short(&commit))),
        Some(130) => {
            return Err(spinner.fail(anyhow::anyhow!(
                "The install was interrupted. Run `diatweaks update` again to finish it."
            )))
        }
        _ => return Err(spinner.fail(anyhow::anyhow!("install.sh failed:\n{}", done.tail(12)))),
    }
    if !has_cargo {
        ui.warn("Rust isn't installed, so the diatweaks command wasn't updated. Run install.sh in a terminal to set it up.");
    }
    match commit == COMMIT {
        true => ui.done(format_args!(
            "Reinstalled DiaTweaks {}. Nothing was new.",
            short(&commit)
        )),
        false => ui.done(format_args!(
            "Updated DiaTweaks {} → {}.",
            short(COMMIT),
            short(&commit)
        )),
    }
    Ok(())
}

fn check_developer_tools() -> Result<()> {
    const MISSING: &str =
        "Apple's developer tools are missing. Run `xcode-select --install`, then try again.";
    let developer_dir = child::quick(Command::new("/usr/bin/xcode-select").arg("-p"));
    if !developer_dir.is_some_and(|dir| Path::new(&dir).is_dir()) {
        bail!(MISSING);
    }
    if child::quick(Command::new("git").arg("--version")).is_none() {
        bail!("git isn't working. Run `xcode-select --install`, then try again.");
    }
    Ok(())
}

/// Returns the full commit hash and its subject.
fn clone(repo: &str, into: &Path, spinner: &Spinner) -> Result<(String, String)> {
    let done = child::run(
        Command::new("git")
            .args(["clone", "--depth", "1", "--quiet", "--", repo])
            .arg(into)
            .env("GIT_TERMINAL_PROMPT", "0"),
        OnInterrupt::Stop,
        spinner,
    )?;
    if !done.status.success() {
        bail!(
            "Couldn't download DiaTweaks from {repo}. Check your internet connection, then try again.\n{}",
            done.tail(3)
        );
    }
    let git = |args: &[&str]| {
        child::quick(Command::new("git").arg("-C").arg(into).args(args))
            .context("Couldn't read the downloaded DiaTweaks")
    };
    Ok((
        git(&["rev-parse", "HEAD"])?,
        git(&["log", "-1", "--format=%s"])?,
    ))
}

/// Builds before install.sh runs, so Ctrl-C can still throw the work away; install.sh then
/// finds everything built. Returns whether the command-line tool could be built.
fn build(source: &Path, spinner: &Spinner) -> Result<bool> {
    let done = child::run(
        Command::new("make").arg("-s").current_dir(source),
        OnInterrupt::Stop,
        spinner,
    )?;
    if !done.status.success() {
        bail!("Couldn't build DiaTweaks:\n{}", done.tail(12));
    }
    if !source.join("cli/Cargo.toml").exists() {
        return Ok(true);
    }
    if child::quick(Command::new("cargo").arg("--version")).is_none() {
        return Ok(false);
    }
    let done = child::run(
        Command::new("cargo")
            .args(["build", "--release", "--manifest-path", "cli/Cargo.toml"])
            .current_dir(source),
        OnInterrupt::Stop,
        spinner,
    )?;
    if !done.status.success() {
        bail!("Couldn't build the diatweaks command:\n{}", done.tail(12));
    }
    Ok(true)
}

/// A run that was killed outright can leave its checkout behind. The age check spares one whose
/// install.sh may still be running on its own.
fn remove_stale_checkouts(support: &Path) {
    let Ok(entries) = fs::read_dir(support) else {
        return;
    };
    for entry in entries.flatten() {
        let is_checkout = entry.file_name().to_string_lossy().starts_with(".update-");
        let is_old = entry
            .metadata()
            .and_then(|metadata| metadata.modified())
            .is_ok_and(|modified| {
                modified
                    .elapsed()
                    .is_ok_and(|age| age > Duration::from_secs(60 * 60))
            });
        if is_checkout && is_old {
            let _ = fs::remove_dir_all(entry.path());
        }
    }
}
