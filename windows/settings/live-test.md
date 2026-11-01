# Native Settings integration: November 1, 2026

Installed Dia: 1.4.0.424 x64. Build: Settings-enabled Debug TAP.

The first installer refused to overwrite Dia's existing PaneFooter. The revised
installer retained that footer object in a wrapper and added its own button.
Installation into the validated Settings NavigationView returned `S_OK`.

The diagnostics tree reported:

```text
Microsoft.UI.Xaml.Controls.StackPanel   DiaTweaksFooter
Microsoft.UI.Xaml.Controls.Button       DiaTweaksPatchesEntry
```

The user clicked Patches and confirmed that the page opened. The live tree then
reported `DiaTweaksPatchesPage`, `DiaTweaksPatchSearch`, all nine patch rows and
their ToggleSwitch controls, and the `groupTabsByDomain` command row.

The user turned Hide sidebar button on in this Settings page and confirmed that
the browser's sidebar toggle disappeared. `inspect` independently reported:

```text
Visibility=Collapsed; type=Microsoft.UI.Xaml.Visibility; source=local
HRESULT=0x0
```

The user turned it off and confirmed that the button returned. Readback reported:

```text
Visibility=Visible; type=Microsoft.UI.Xaml.Visibility; source=local
HRESULT=0x0
```

This verifies native entry installation, page creation, and the Settings switch
driving the session adapter on and off. It does not verify the other eight patch
implementations, the grouping command, preference persistence, every native
Settings navigation path, search filtering, multiple windows, or both tab layouts.

## Row placement and styling refinement

The user requested that Patches sit directly below Advanced with matching row
styling. The updated Settings-enabled Debug build installed successfully in a
fresh Dia process (22656). Live layout readback reported:

```text
Layout: Patches top=284; Advanced bottom=284; Patches/Advanced font=14/14; palette=navigation
```

These values are in the NavigationView's local coordinate space. They confirm
the row starts immediately after Advanced and uses the same font size. The
NavigationView palette aliases loaded successfully. The row also copies font
family, margins, height and corner radius, and adds an aligned repair icon.

The layout adjustment uses the validated menu/footer arrangement in WinUI's
[NavigationView template](https://github.com/microsoft/microsoft-ui-xaml/blob/main/controls/dev/NavigationView/NavigationView.xaml).
Its original grid-row height is retained for restoration; Dia's menu data and
selection handlers are not replaced. Both CTest checks passed for this build.
The live tree subsequently showed `DiaTweaksPatchesPage` opened through the new
entry, and a second readback still reported top/bottom 284 and fonts 14/14.
Visual comparison of the new styling still needs user confirmation. No screenshot
of the generated panel has been captured yet.
