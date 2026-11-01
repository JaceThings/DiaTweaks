# Native Patches panel prototype

The live Settings tree in Dia 1.4.0.424 contains a WinUI NavigationView with
NavigationViewItems named `account`, `tabs`, `privacy`, `profiles`, `chat`,
`skillsV3` and `advanced`. This is a different host from macOS's AppKit sidebar.
The prototype recognizes that host by type and three descendant names rather
than by a hard-coded session handle.

The Settings-enabled TAP wraps Dia's existing PaneFooter and adds a native
Patches button alongside the original footer object. The button is placed first
in that wrapper, and the template's menu row is sized to its content so Patches
sits directly below Advanced. The original menu-row height is saved and restored
on removal. An unfamiliar menu/footer template is refused.
It does not append an unknown item to Dia's own navigation model or invoke its
selection handlers. Clicking Patches shows a native searchable panel over the
template's content cell. Dia's original content object remains attached, so its
category navigation continues updating the same host. ItemInvoked and
SelectionChanged return to native content, including when the user clicks the
already-selected category. The original presenter Visibility is restored on
exit; a bound Visibility is refused. On disconnect, the TAP removes its overlay
and restores its footer/layout changes. A bound footer is also refused.

The row copies Advanced's live font, row height, margins and corner radius. It
aligns its wand icon and label against the native item and uses NavigationView
hover/pressed resources when available (otherwise native Button colors). It
remains an independent button so Dia's own navigation handlers do not receive an
unrecognized menu key. The wand uses the complete 20-unit viewport inside a
Viewbox, mirrored to point upper-left. The source asset is from Microsoft's
[Fluent System Icons](https://github.com/microsoft/fluentui-system-icons), with
its MIT license in `assets/LICENSE.fluent-icons`.

The selection bridge copies the native blue marker's size, brush and radius,
then animates it to Patches in 200 ms. While Patches is active, the native marker
is temporarily collapsed and its selected row uses the unselected visual state;
Dia's SelectedItem, IsSelected and route keys remain untouched. Returning to a
native category restores these visuals. The cached page also replays a 180 ms
fade/slide on entry. Both animations respect Windows' animation setting.
The bridge refuses unfamiliar template parts and reports the failure through
the probe instead of changing the navigation model. The user confirmed the wand
and transition appearance. The native-marker suppression correction and compact
pane behavior still require live confirmation.

Patches follows IsPaneOpen so its label disappears in the native icon-only pane.
Double-tapping its row toggles that same pane property. The button retains an
accessible name in compact mode. Both hooks are removed on disconnect.

The panel lists all nine patch definitions and the tab-grouping command from
`shared/features.json`. Only Hide sidebar button is enabled. All other features
are explicitly unavailable. There are no preview videos or detail pages yet.
No toggle preferences are saved: changes last only while this controller session
is connected. Dia continues using its normal Windows updater.

Live status: the native entry and page opened in Dia 1.4.0.424. The user confirmed
the sidebar button disappeared and returned through the Settings toggle, and
property readback confirmed both states. See [live-test.md](live-test.md).

## Porting status

| Feature | Windows state |
| --- | --- |
| Edge-to-edge web content | Layout adapter not implemented |
| Square corners by the sidebar | Needs edge-to-edge and a corners adapter |
| Hide toolbar | Toolbar layout adapter not implemented |
| Reveal toolbar on hover | Needs toolbar adapter and pointer/reveal handling |
| Hide sidebar button | Native Settings on/off verified live; session-scoped |
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
