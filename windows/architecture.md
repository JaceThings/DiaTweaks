# Cross-platform direction

The feature identity and expected behavior should be shared; native view lookup
and mutation belong to each OS adapter. For example, the existing macOS patch
[`hideChatButton`](../src/dylib/Patches/HideChatButton/HideChatButton.m) matches
the accessible label `Chat with this tab`. Windows should implement that same
feature key after its native control has been identified. It should not copy
the AppKit class names or assume that an English label is a stable XAML name.

```text
Shared feature contract (next step)
  key, settings, dependencies, expected behavior, capability requirements
                 |
        +--------+---------+
        |                  |
  Mac adapter         Windows adapter
  StdPatch/AppKit     WinUI diagnostics TAP
  native hooks       UI-thread property overrides
```

The Windows prototype implements the lower path only. It intentionally leaves
the Mac runtime unchanged until the Windows attachment path is proven. It does
not yet claim to have a shared feature engine.

## Current Windows path

1. The controller enumerates Dia processes, validates package identity and CPU
   architecture, and finds the diagnostics runtime already loaded by the target.
2. It calls `InitializeXamlDiagnosticsEx` using the `WinUIVisualDiagConnectionN`
   endpoint family. WinUI loads `DiaTweaksTap.dll` and creates its `IObjectWithSite`
   COM object. No registry registration is needed.
3. The TAP subscribes to `IVisualTreeService` changes on a worker thread. Native
   callbacks record structural metadata and establish a message-only window on
   each observed UI thread.
4. Controller requests cross a bounded shared-memory channel with a random name
   and a DACL for the current user. Property operations are posted to the owner
   UI thread. A request cannot supply an address, code or arbitrary property.
5. Pulse reads the effective Visibility and source, checks eligibility, saves
   the original, sets Collapsed and verifies readback. A UI-thread timer restores
   the original literal or clears the override to reveal the original source.
6. Shutdown restores overrides and stops callbacks. Failed restores retain a
   timer retry. COM objects and message-window contexts remain alive until Dia
   exits, avoiding forced unload while pointers might still be used.

Shared memory is a temporary transport choice for a local developer probe.
The feature engine should depend on an adapter interface, not this protocol.
A future UI can replace the controller without changing feature semantics.

## Next acceptance gate

Before implementing `hideChatButton` as a persistent toggle:

- Attach to the installed Dia release and capture its native structural tree.
- Verify the intended control and its ancestors in both tab layouts. Reject
  ambiguous or missing selectors; never fall back to clicking screen positions.
- Record visible → collapsed → restored evidence, including a new window and
  node removal/recreation. Confirm the profile and installed package are intact.
- Record tested Dia/WinUI versions and define a capability probe. Unverified
  versions should remain unavailable until their adapter is checked.

Then introduce a shared feature manifest using existing macOS keys. Each adapter
reports `available`, `unsupported` or `unverified`, applies the same requested
state, and verifies the same visible outcome. Keep requested and effective state
separate. Features that need native hooks get OS-specific implementations behind
that contract. A Mac feature becomes a Windows port by implementing its adapter
operation and running the same behavioral checks; there is no promise of copying
native implementation code unchanged.

## References

- [Microsoft: InitializeXamlDiagnosticsEx](https://learn.microsoft.com/en-us/windows/win32/api/xamlom/nf-xamlom-initializexamldiagnosticsex): documented TAP entry point and site contract.
- [Microsoft: IVisualTreeService](https://learn.microsoft.com/en-us/windows/win32/api/xamlom/nn-xamlom-ivisualtreeservice): tree subscriptions and property APIs.
- [UWPSpy](https://github.com/m417z/UWPSpy): reference for locating WinUI's runtime and diagnostics endpoint, and for subscribing away from the UI thread.
- [TranslucentTB ExplorerTAP](https://github.com/TranslucentTB/TranslucentTB/tree/release/ExplorerTAP): an example of a separate controller and in-process XAML customization adapter.
- [Live Visual Tree TAP design](https://github.com/asklar/lvt/blob/main/docs/tap-dll-design.md): reference for owner-thread dispatch and session lifetime.

The prototype uses Windows SDK COM declarations and its own implementation. It
does not bundle those projects or any Dia binaries.
