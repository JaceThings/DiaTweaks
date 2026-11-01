# First live Windows attachment

Tested November 1, 2026 against installed Dia 1.4.0.424 x64. The controller used
the exact installed FrameworkUdk DLL staged in a temporary directory.

The diagnostics initializer returned success for `WinUIVisualDiagConnection1`.
The TAP completed its handshake and delivered the live native XAML tree. All
listed controls were reported on UI thread 18540 in this session:

| Session ID | XAML type | x:Name |
| --- | --- | --- |
| 145 | Microsoft.UI.Xaml.Controls.ContentControl | ChatButtonHost |
| 155 | Microsoft.UI.Xaml.Controls.Button | SidebarToggleButton |
| 156 | Microsoft.UI.Xaml.Controls.Button | BackButton |
| 157 | Microsoft.UI.Xaml.Controls.Button | ForwardButton |
| 158 | Microsoft.UI.Xaml.Controls.Button | ReloadButton |
| 154 | Microsoft.UI.Xaml.Controls.Button | ChatUsageButton |
| 76 | Microsoft.UI.Xaml.Controls.Button | AppMenuButton |

These are structural observations, not verified feature selectors. IDs and
thread numbers are session-specific. ChatButtonHost has not been visually
confirmed as the control matched by the Mac `hideChatButton` patch.

`inspect 145` and `inspect 155` returned `0x80004001` (unsupported) under the
initial eligibility policy. No pulse was requested and no override was applied.
An inspector diagnostic was subsequently added to expose the Visibility chain's
type, value, source and metadata when the policy rejects it.

On `quit`, the controller reported `Restored (or no active override)` and exited
successfully. The same Dia UI process remained running and responsive afterward.
The TAP stayed resident, as designed, until the host process exits.

Still unverified: real hide/restore, visual proof, both tab layouts, multiple
windows, node recreation, and behavior across Dia updates. The earlier reported
unexpected closure has not been reproduced or explained.

## Second inspection and numeric enum fix

A fresh session also attached successfully. The improved inspector returned:

| Control | Effective Visibility | Type | Metadata | Source |
| --- | --- | --- | --- | --- |
| ChatButtonHost | `1` | Microsoft.UI.Xaml.Visibility | `0x0` | local (4) |
| SidebarToggleButton | `0` | Microsoft.UI.Xaml.Visibility | `0x0` | local (4) |
| MinimizeButton | `0` | Microsoft.UI.Xaml.Visibility | `0x0` | default (1) |

The refusal was caused by numeric enum serialization, not by binding metadata
in these inspected properties. The adapter now normalizes `0` to Visible and `1`
to Collapsed only after verifying the exact Visibility enum type. Its existing
binding/source restrictions remain in effect. Tests cover numeric local and
default restoration as well as numeric readback through the actual TAP DLL and
controller channel. Both CTest checks pass.

No pulse was issued during either inspection. ChatButtonHost was already
Collapsed on New Tab, so it is not a suitable first visible change there. A
fresh process is needed to test the numeric fix against the sidebar toggle.
