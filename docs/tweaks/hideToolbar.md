# Hide toolbar

Hides the bar above the page with the address, navigation buttons and extensions, and moves the page up into its place. It's experimental.

<!-- Screenshots: docs/tweaks/images/hideToolbar-before.png and docs/tweaks/images/hideToolbar-after.png.
     Crop to the top of the page, right of the sidebar, with this tweak off, then on.
     Once they're in, replace each placeholder below with ![Before](images/hideToolbar-before.png) and ![After](images/hideToolbar-after.png). -->

| Before | After |
|:---:|:---:|
| _Screenshot coming soon._ | _Screenshot coming soon._ |

## Turn it on

Open **Dia → Settings → Patches** and switch on **Hide toolbar**. Or run:

```sh
diatweaks enable hideToolbar
```

## Works with

- [Reveal toolbar on hover](revealToolbarOnHover.md) shows the toolbar again while the pointer is at the top of the page.
- [Hide sidebar button](hideSidebarButton.md) and [Hide Chat button](hideChatButton.md) are greyed out in Settings while this is on, because their buttons are hidden with the toolbar.
- [Toolbar in sidebar](sidebarToolbar.md) is greyed out in Settings while this is on, and the toolbar stays hidden in the page.

## FAQ

<details>
<summary><strong>Where did the bookmarks bar go?</strong></summary>

Dia puts it right under the toolbar, so it hides too. With Reveal toolbar on hover, it comes back with the toolbar.

</details>

<details>
<summary><strong>Can I still click at the top of the page?</strong></summary>

Yes. The hidden toolbar doesn't take clicks, so the top of the page works as usual.

</details>
