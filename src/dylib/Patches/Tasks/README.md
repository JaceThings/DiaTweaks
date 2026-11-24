# Tasks

Optional native Library section, enabled by default. A single local list is
shared across normal spaces; private windows do not show or change it.
Search and All / Incomplete / Completed filters operate locally. Incomplete is
the initial filter. Enter or Add submits the bottom input; the header plus
focuses that input. Checking saves immediately, shows a brief strikethrough,
then dismisses from Incomplete. Completed and All allow unchecking.

Clear All moves tasks into recoverable local storage. Task actions → Restore
Cleared Tasks restores them, including their completion states. Nothing is
permanently deleted by the current UI. Disabling Tasks leaves all data intact.

Data lives in `DiaPatches/Tasks/tasks.json` under application support. The store
loads asynchronously, captures immutable snapshots on main, and writes atomic
JSON on one utility queue. There is no network access, periodic polling, or
per-keystroke disk write. A malformed existing file is preserved and blocks
mutation instead of being overwritten with an empty list.

Rows use NSTableView reuse. Completion/deletion snapshots share Library's dust
setting, particle budget, display clock and Reduce Motion behavior. Persistence
does not wait for particles. Reused cells regain their alpha immediately.

Run `scripts/check-tasks` for isolated native behavior and persistence tests.
Keep native WindowServer access available for AppKit rendering fixtures.

Tasks are stored by Dia browser profile. Spaces using the same profile share a list; other profiles have independent lists. The existing legacy list belongs to the original profile (Profile 1) and stays in place. New profiles begin empty.
