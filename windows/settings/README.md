# Native Patches panel prototype

The live Settings tree in Dia 1.4.0.424 contains a WinUI NavigationView with
NavigationViewItems named `account`, `tabs`, `privacy`, `profiles`, `chat`,
`skillsV3` and `advanced`. This is a different host from macOS's AppKit sidebar.
The prototype recognizes that host by type and three descendant names rather
than by a hard-coded session handle.

The Settings-enabled TAP wraps Dia's existing PaneFooter and adds a native
Patches button alongside the original footer object.
It does not append an unknown item to Dia's own navigation model or invoke its
selection handlers. Clicking Patches places a native searchable panel into the
NavigationView's content area. Back returns to the original content. Selecting
a regular Dia category can replace the panel normally. On disconnect, the TAP
restores its content/footer changes only if they still contain its own objects.
Bound footer/content properties cause installation to be refused.

The panel lists all nine patch definitions and the tab-grouping command from
`shared/features.json`. Only Hide sidebar button is enabled. All other features
are explicitly unavailable. There are no preview videos or detail pages yet.
No toggle preferences are saved: changes last only while this controller session
is connected. Dia continues using its normal Windows updater.

Live status: the Settings host was found and validated. The first insertion was
refused because Dia already had a footer. The updated build preserves that object
inside a wrapper; this update still needs its live installation test. A compiled
panel is not proof that it is visible or usable in Dia yet.

## Porting status

| Feature | Windows state |
| --- | --- |
| Edge-to-edge web content | Layout adapter not implemented |
| Square corners by the sidebar | Needs edge-to-edge and a corners adapter |
| Hide toolbar | Toolbar layout adapter not implemented |
| Reveal toolbar on hover | Needs toolbar adapter and pointer/reveal handling |
| Hide sidebar button | Session adapter implemented; native Settings wiring needs live verification |
| Hide Chat button | ChatButtonHost observed; visible control mapping not yet verified |
| Hide Chats button | Control selector and adapter not implemented |
| Hide recent tabs button | Control selector and adapter not implemented |
| Keep windows active | Needs a Windows-specific appearance implementation |
| Group Tabs by Domain | Needs access to Dia's tab/group command model |

## Build

```powershell
.\windows\build-settings.ps1
```

This optional build requires the Windows SDK's C++/WinRT generator. It generates
projections from the installed Dia WinUI metadata into the ignored build folder.
It downloads the pinned Microsoft WebView2 SDK metadata (NuGet 1.0.4314.35) only
if the needed reference is absent. The panel creates no WebView and requires no
WebView runtime installation. No Microsoft or Dia binaries/metadata are committed
or should be distributed with the source.

To override package discovery, pass `-DiaPath` with the installed Dia directory.
The ordinary `build.ps1` remains a probe-only build without these dependencies.

## Test in Dia

Fully restart Dia after a previous attached session, open Settings, then run:

```powershell
.\windows\build\settings\Release\diatweaks-probe.exe
```

At the probe prompt:

```text
tree NavigationView
settings ID
```

Use the ID of the Settings NavigationView from the current tree, not a
NavigationViewItem or an ID from an older session. Click the new Patches entry.
Keep the controller open while using the panel. `quit` restores active overrides
and removes the panel/entry. The DLL remains loaded until Dia exits.

The same feature can be exercised through `enable hideSidebarButton` and
`disable hideSidebarButton`. Those commands and the Settings toggle share the
same requested state. The toggle synchronizes with CLI changes on the UI thread.
Settings controls show requested state; they do not yet display
per-window failures if Dia later changes an overridden value.

The adapter keeps an original Visibility value for each matching button, checks
new nodes on their owning UI threads, and restores surviving overrides on disable
or disconnect. It does not continuously overwrite a value Dia changes on an
already tracked node. Multiple windows, layout changes, node recreation, and
native Settings restoration require live verification before a release.
