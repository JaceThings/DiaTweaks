# Windows prototype

This branch adds an x64 developer probe alongside the existing macOS implementation.
It builds a controller and a COM TAP DLL for WinUI XAML diagnostics. It is **not a
working Windows release of the macOS tweaks yet**. No Windows selector for the
Chat button has been verified in a live Dia session.

## Build

Requires Windows 11 x64, Visual Studio 2022 or later C++ Build Tools, the Windows
SDK, and Visual Studio's CMake component. From the repository root:

```powershell
.\windows\build.ps1
```

The script builds Release and runs CTest. `-Configuration Debug` builds Debug.
It uses a single MSBuild worker with node reuse disabled. No NuGet packages or
other source downloads are required.

## Run

Open Dia normally, then run from a terminal at the repository root:

```powershell
.\windows\build\Release\diatweaks-probe.exe --check
.\windows\build\Release\diatweaks-probe.exe
```

`--check` validates the target without attaching. The controller requires the
installed `TheBrowserCompany.Dia_ttt1ap7aakyb4` package, an x64 `Dia.exe` with a
visible top-level window, and its
loaded `Microsoft.Internal.FrameworkUdk.dll`. If several candidates exist, use
`--pid PID` to select one. It rejects an already loaded `DiaTweaksTap.dll`.

After attachment, the following commands are available:

| Command | Behavior |
| --- | --- |
| `tree` | Print native XAML node IDs, owner thread, hierarchy, type and `x:Name` |
| `tree Button` | Filter the structural snapshot by text |
| `inspect 123` | Inspect node 123's Visibility and whether it has a local value |
| `pulse 123 5` | Collapse that node for five seconds, then restore it |
| `restore` | Restore active overrides immediately |
| `quit` | Restore and end the controller session |

`123` is an example: use an actual node ID from the current `tree` output. IDs
are session-scoped and deliberately distinct from addresses. Inspect and visually
identify the intended native control before pulsing it. Pulse accepts 1–30
seconds and at most one active override per UI thread. It has no saved settings.

The probe does not patch, re-sign, replace or update the installed Dia package.
If Windows denies loading its diagnostics runtime from WindowsApps, the controller
copies that one DLL into a unique temporary directory and loads those exact bytes
locally. It attempts cleanup on exit; a file still in use may remain in the temp
directory. Do not distribute this runtime DLL. The TAP changes an in-memory
property only. The TAP DLL remains resident but inert
after the session ends. **Restart Dia before attaching again or rebuilding a
loaded DLL.** Keep other XAML diagnostic tools detached during this experiment.

## What has been verified

The controller and DLL build with MSVC 19.51 and Windows SDK 10.0.26100.0.
Automated tests load the actual TAP DLL into a local fixture that implements the
diagnostics interfaces and owns a real Windows message loop. Tests cover COM
activation, shared-memory requests, UI-thread dispatch, readback, time-limited
restoration, disconnect restoration, local/default value restoration, stale IDs,
duplicate controllers, and refusal of bindings and animations.

These tests do **not** prove attachment to Dia or the correctness of a real
WinUI selector. Live attachment, native toolbar discovery, before/after/restored
screenshots, both tab layouts, and multiple Dia windows remain to be tested.
Computer Use rejected access to Dia during development, so no live proof is
included. Test shared-memory access also requires running outside Codex's
restricted sandbox; normal same-user terminal execution is the intended mode.

The installed 1.4.0.424 diagnostics DLL was also checked separately: loading
directly from WindowsApps returns Access denied, while loading the exact staged
bytes succeeds and exposes `InitializeXamlDiagnosticsEx`. This check does not
attach to Dia. To repeat it:

```powershell
.\windows\build\Release\prototype-tests.exe --runtime 'C:\Program Files\WindowsApps\TheBrowserCompany.Dia_1.4.0.424_x64__ttt1ap7aakyb4\Microsoft.Internal.FrameworkUdk.dll'
```

Probe failures now name their stage. Only enter commands such as `tree Button`
after the probe prints `Attached` and its `>` prompt. At a PowerShell `PS ...>`
prompt, `tree` is Windows' folder-listing command.

## Limits

- The adapter depends on an internal WinUI diagnostics export. Dia or WinUI
  updates can break attachment. Missing capabilities return errors.
- Tree output is limited to 8,192 live nodes and a 256K-character response.
  Truncation is reported. It omits text content, URLs, accessible labels and
  arbitrary properties; structural names can still be app supplied.
- Only literal `Visibility` values from local, default, built-in style or style
  sources are eligible. Bindings, expressions, handles, animation and unfamiliar
  enum representations are refused.
- Restoration runs on the owning UI thread. A hung UI delays it. A changed app
  value is preserved when detectable; an app writing the same `Collapsed` value
  cannot be distinguished from the probe's override.
- The prototype does not reapply a feature to newly created controls, reconnect
  after restart, implement preferences, or port Mac hooks. Those follow the live
  attachment experiment, as described in [architecture.md](architecture.md).

For `0x80070005`, use a normal terminal under the same user and integrity level
as Dia. Do not change the process security policy. For `0x800700b7`, close the
existing controller and restart Dia. On an unconfirmed restore, let the UI
resume or restart Dia to remove all in-memory overrides.
