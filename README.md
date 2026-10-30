# DiaTweaks

Small tweaks for the [Dia](https://www.diabrowser.com) browser, kept in place when Dia updates. Turn them on and off in **Dia → Settings → Patches**:

- Edge-to-edge web content
- Square corners by the sidebar
- Hide toolbar
- Hide sidebar button
- Hide Chat button

Unofficial and not affiliated with The Browser Company. Apple Silicon, macOS 14 or later.

## Install

1. Install Dia into Applications, if it isn't there already.
2. Install Apple's developer tools: `xcode-select --install`
3. Run:

   ```sh
   git clone https://github.com/JaceThings/DiaTweaks.git
   cd DiaTweaks
   ./install.sh
   ```

Dia quits and reopens. When macOS asks to access "Dia Safe Storage", enter your password and click **Always Allow**.

## Uninstall

In Dia, open **Settings → Patches** and click **Restore…**. Dia reopens as the original app with its own updates.

Or from Terminal:

```sh
~/Library/Application\ Support/DiaPatches/bin/diapatch uninstall --relaunch --purge
```
