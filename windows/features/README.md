# Windows feature adapters

`feature_state.h` assigns stable IPC ids to the nine toggle keys. The shared
catalog still supplies titles, descriptions, ordering and relationships. New Mac
catalog entries appear disabled until Windows provides an adapter for the key.

The Settings page, probe commands and UI-thread timer share requested state.
`features` reports availability and actual application separately. Dependencies
wait for their parent; hiding the toolbar temporarily suppresses its individual
button adapters while retaining their requested states. The UI never labels a
requested but failed change as applied.

`NativeFeatures` discovers exact named controls and known accessibility roles.
Accessible-name matching is restricted to browser chrome and excludes tab-list
content so a user tab named Chats cannot become a selector. No matching Chats or
Recent tabs control has been found in the tested Dia 1.4.0.424 Windows layout;
those switches remain unavailable rather than becoming no-op switches.

`LayoutFeatures` recognizes the ContentGroup/SharedSurface/TabStripContentInset
arrangement and preserves its original outer Margin. The square-corners option
changes only the shared surface and browser frame borders, and restores corners
when the sidebar closes or layout changes. It does not round page controls.

`ToolbarAdapter` keeps Dia's toolbar parented and laid out, sets its opacity and
hit testing, and extends the page/overlay hosts across both rows. Hover reveal
therefore floats over the page without another page resize. An eight-pixel
transparent hotzone triggers reveal; pointer exit delays hiding by 200 ms.
Keyboard focus and active mouse drags keep the bar available.

`LiteralOverride` records each original local value, verifies diagnostics source
metadata, refuses bindings/animations, and clears or restores the property on
disable. It preserves newer app values. Partial transactions roll back. Errors
are reported and retried after a toggle or node recreation, not on every frame.

`WindowAppearance` is a Windows-specific adaptation of Keep windows active. It
copies active caption colors to the inactive caption slots through supported
AppWindowTitleBar APIs, saves nullable original colors, and restores slots only
if they still hold its values. It does not fake focus/activation. DWM shadow and
backdrop policy remain Windows-managed; the Windows Settings description makes
this scope explicit. Visual confirmation is pending.

All changes are session-only. They restore on disable or controller disconnect.
No Dia binary, profile database, preference, or extension is modified. No Dia
files or recordings belong in source control. Probe `--log PATH` records
unwrapped structural diagnostics for review; `layout ID` excludes content text
and URLs. Generated metadata and logs remain under ignored `windows/build`.

Multi-window, split panes, tab-layout changes, maximization, DPI changes, hover
keyboard use and update compatibility still need broader live testing before a
release. The supported source of the caption APIs is Microsoft's
[AppWindowTitleBar documentation](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.windowing.appwindowtitlebar).
