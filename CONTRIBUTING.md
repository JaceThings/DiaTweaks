# Contributing

Keep it small, test it hard, show it working.

## Pull requests

- One change per PR.
- Fill in the template: What, Why, Proof, Tested on, Checklist. Short sentences.
- Never leave a section empty or delete it. If one doesn't apply, write `N/A` in it, and tick a checklist item that doesn't apply with `(N/A)` after it. Proof is never N/A for a change you can see in Dia.
- Proof is required for anything visible in Dia: a screenshot for static changes, a screen recording for anything that animates. Show before and after when you change existing behaviour.
- Try to break what you made before you open the PR, and fix what you find. Every change has to work with tabs in the sidebar and tabs at the top, and with each tweak on and off.
- Build with `make` and run it on your own Dia with `./install.sh`. Then run `make test`.

## Adding a patch

Each patch is one folder in `src/dylib/Patches/`, built on StdPatch: `src/dylib/StdPatch/StdPatch.h` is the whole API. Nothing outside the folder changes.

- `make patch NAME=HideFooButton` creates `Patches/HideFooButton/HideFooButton.m` with a `DP_PATCH` in it. That registers it: its row in Settings, its saved switch, its place in `make test` and its entry in `build/patches.json`, the list `diatweaks` shows, come from the fields, and `.order` sets where it's listed.
- Find what to change with the developer tools. Turn them on with `defaults write com.diapatches devTools -bool YES`, relaunch Dia, and use **Help → DiaPatches: Copy View Tree** for the front window's views with their classes, frames and accessibility labels.
- Hiding a button only takes a `.hides` function, such as `DPHasLabel(view, @"Recent tabs")` or `DPIsKind(view, DPDiaLibraryButton)`. StdPatch hides it wherever Dia shows it, and checks it in `make test`.
- Anything else hooks Dia in `.install` with `DPHook`, and calls through with `DPCallOriginal`. Dia's class names go in `StdPatch/Dia.h`.
- `.apply` applies a toggle at once. Without it the patch animates: `progress` eases between 0 and 1 while `.relayout` runs each frame.
- `.requires` and `.disabledBy` take another patch's key.
- List the Dia classes it relies on in `.classes`. On a Dia version without one of them, the patch stays off and Settings shows it as unavailable.
- Give it a `.verify` that looks at Dia's views and returns `nil` when they match `on`, or a few words saying what's wrong. Find the views with `DPFindViews`, not through your own hooks, so a hook that never ran shows up as a failure.
- Keep files to about 100 lines. Split a big patch into several files in its folder.

With the developer tools on, a script can also drive Dia: post the distributed notification `com.diapatches.dev.set` with the object `hideToolbar=1` to flip a switch, or `com.diapatches.dev.dump` to write every window's view tree to `~/Library/Application Support/DiaPatches/views.txt`.

## Testing

`make test` installs your build's dylib and reopens Dia in test mode. Dia tries the patches all off, all on, each on its own and in pairwise combinations without saving any of it, runs every patch's `verify` after each, then goes back to your settings. The script prints what failed and exits non-zero if anything did. It can't move the tabs between the sidebar and the top, so run it once in each layout. Square corners only get tested with the sidebar open.

To try `install.sh`, `diapatch` or `diatweaks` without touching your own Dia, point `DIAPATCH_APP` at a copy of Dia, `DIAPATCH_HOME`, `DIAPATCH_CACHE` and `DIATWEAKS_LINK_DIR` at scratch folders and `DIATWEAKS_DOMAIN` at a settings domain of its own, and set `DIAPATCH_NO_RELAUNCH=1` so nothing quits or opens Dia. `DIATWEAKS_REPO=file://$PWD` makes `diatweaks update` clone your checkout's committed work instead of GitHub.

## Commits

- [Conventional Commits](https://www.conventionalcommits.org): `fix(dylib): keep the top padding under horizontal tabs`.
- Imperative, lowercase, under 72 characters. Add a body only if the diff would mislead without it.
- No tool or AI attribution trailers (`Co-authored-by: Claude`, `Generated with …`).

## AI tools

Use whatever tools you like. You're responsible for what you submit: it has to work, and you have to have tested it yourself.

No slop: no padded descriptions, generated summaries or filler ("comprehensive", "robust", "seamless", "this PR introduces…"). PRs that read like unchecked AI output are closed without review.

## Never

- Commit Dia itself or anything from its bundle.
- Sign with, or ship, anyone else's certificate.
