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
<summary>Is it safe?</summary>

Everything is built on your Mac from this source. The only download is Dia itself, from The Browser Company's own update feed, and it's only used if it's signed by The Browser Company and passes Gatekeeper. The tweaks only rearrange Dia's own interface: they don't read your pages, history or passwords, and their only network use is checking that update feed.

</details>

<details>
<summary>How does it work?</summary>

DiaTweaks keeps an untouched copy of the official Dia, then makes a patched copy that loads one small add-on when it opens. The add-on moves and hides parts of Dia's interface while it runs. The patched Dia is signed with a certificate made on your Mac ("DiaPatches Local Signing"), never anyone else's.

</details>

<details>
<summary>Why does macOS ask about "Dia Safe Storage"?</summary>

The patched Dia is signed by you, not The Browser Company, so macOS asks once per Dia update before it can read its saved data. Click **Always Allow**.

</details>

<details>
<summary>Does anything run in the background?</summary>

No. Updates are checked when Dia opens and installed when you quit it.

</details>

<details>
<summary>What doesn't work?</summary>

Dia's passkeys, since only The Browser Company can sign for them. Signing in with a password works.

</details>

<details>
<summary>Dia crashed. What happens now?</summary>

If Dia quits unexpectedly twice in a row right after opening, it opens next time with the tweaks off. **Settings → Patches** says so and has a button to turn them back on. Updating DiaTweaks turns them back on too. If Dia keeps crashing even with the tweaks off, DiaTweaks loads nothing at all until you update it.

</details>

<details>
<summary>Does Group Tabs by Domain read my tabs?</summary>

It reads the address of each tab in the current window to know which site it's on. Nothing else, and nothing leaves your Mac.

</details>

## Uninstall

In Dia, open **Settings → Patches** and click **Restore…**. Dia reopens as the original app with its own updates.

To also delete DiaTweaks' files and the `diatweaks` command, run `diatweaks restore --purge` instead.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
