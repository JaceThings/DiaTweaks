# DiaTweaks

Small tweaks for the [Dia](https://www.diabrowser.com) browser that stay in place when Dia updates.

Unofficial and not affiliated with The Browser Company. Apple Silicon, macOS 14 or later.

## Tweaks

Turn them on and off in **Dia → Settings → Patches**, or with the `diatweaks` command.

| Tweak | What it does |
|---|---|
| Edge-to-edge web content | Removes the padding between pages and the window edge |
| Square corners by the sidebar | Pages meet the sidebar with straight edges |
| Hide toolbar | Hides the address bar, navigation buttons and extensions |
| Reveal toolbar on hover | Shows the hidden toolbar when the pointer is at the top of the page |
| Hide sidebar button | Hides the sidebar toggle |
| Hide Chat button | Hides the Chat button in the toolbar |
| Hide Chats button | Hides the Chats button in the tab bar or sidebar |
| Hide recent tabs button | Hides the recent tabs button in the tab bar or sidebar |

Plus **Group Tabs by Domain**: right-click a tab, or use the Tabs menu.

## Install

1. Put Dia in your Applications folder.
2. Install Apple's developer tools: `xcode-select --install`
3. Paste this into Terminal:

   ```sh
   git clone https://github.com/JaceThings/DiaTweaks.git ~/DiaTweaks && ~/DiaTweaks/install.sh
   ```

Dia quits and reopens. If macOS asks about "Dia Safe Storage", enter your password and click **Always Allow**.

## The `diatweaks` command

Run `diatweaks` on its own for a menu, or:

| Command | Does |
|---|---|
| `diatweaks list` | Shows every tweak and whether it's on |
| `diatweaks enable hideToolbar` | Turns a tweak on; Dia changes straight away |
| `diatweaks disable hideToolbar` | Turns a tweak off |
| `diatweaks status` | Shows Dia's version, safe mode and which tweaks are on |
| `diatweaks update` | Gets the latest DiaTweaks and patches Dia again |
| `diatweaks update-dia` | Downloads a newer Dia and patches it |
| `diatweaks restore` | Puts the original Dia back |

Tweak names work as keys or titles, like `hideToolbar` or `"Hide toolbar"`. Add `-y` to skip the questions.

## Updating

- **Dia:** Dia's own updater is switched off. DiaTweaks checks for new Dia versions when Dia opens and installs them, patched, when you quit it. `diatweaks update-dia` does it right away.
- **DiaTweaks:** run `diatweaks update`.

<details>
<summary>Installed before <code>diatweaks</code> existed?</summary>

Update once by hand, then use `diatweaks update` from then on:

```sh
rm -rf /tmp/DiaTweaks && git clone --depth 1 https://github.com/JaceThings/DiaTweaks.git /tmp/DiaTweaks && /tmp/DiaTweaks/install.sh
```

</details>

## FAQ

<details>
<summary><strong>Is it safe?</strong></summary>

Yes. It's built on your Mac from this code. It only changes how Dia looks, and never reads your pages, history or passwords.

</details>

<details>
<summary><strong>How does it work?</strong></summary>

It keeps an untouched copy of Dia and makes a second copy that loads a small add-on. The add-on moves and hides parts of Dia while it runs.

</details>

<details>
<summary><strong>Why does my Mac ask about "Dia Safe Storage"?</strong></summary>

The tweaked Dia is signed by you instead of The Browser Company, so macOS checks once per Dia update. Click **Always Allow**.

</details>

<details>
<summary><strong>Does it run in the background?</strong></summary>

No. It only does anything while Dia is open.

</details>

<details>
<summary><strong>Does anything stop working?</strong></summary>

Passkeys. Signing in with a password still works.

</details>

<details>
<summary><strong>What if Dia keeps crashing?</strong></summary>

After two crashes in a row, Dia opens with the tweaks off. **Settings → Patches** has a button to turn them back on.

</details>

## Uninstall

In Dia, open **Settings → Patches** and click **Restore…**. Dia reopens as the original app with its own updates.

To also delete DiaTweaks' files and the `diatweaks` command, run `diatweaks restore --purge` instead.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
