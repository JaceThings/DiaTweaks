use anyhow::Result;

use crate::{
    env::Env,
    signals::{self, Cancelled},
    status, tweaks,
    ui::{self, Ui},
};

#[derive(Clone, Copy, PartialEq, Eq)]
enum Action {
    Tweaks,
    Status,
    Quit,
}

/// `diatweaks` in a terminal. Esc in a screen goes back here; Esc here, or a signal anywhere, ends
/// the session.
pub fn run(env: &Env, ui: &Ui) -> Result<()> {
    ui.intro();
    ui.enter_menu(true);
    let mut action = Action::Tweaks;
    loop {
        action = ui::prompt(
            cliclack::select("What do you want to do?")
                .item(Action::Tweaks, "Tweaks", "turn tweaks on or off")
                .item(Action::Status, "Status", "")
                .item(Action::Quit, "Quit", "")
                .initial_value(action)
                .interact(),
        )?;
        let result = match action {
            Action::Tweaks => tweaks::menu(env, ui),
            Action::Status => status::show(env, ui),
            Action::Quit => break,
        };
        match result {
            Ok(()) => {}
            Err(err) => match err.downcast_ref::<Cancelled>() {
                Some(_) if signals::interrupted() => return Err(err),
                Some(cancelled) => ui.remark(cancelled),
                None => ui.error(&err),
            },
        }
    }
    ui.enter_menu(false);
    ui.done("Bye.");
    Ok(())
}
