# Reveal toolbar on hover

With [Hide toolbar](hideToolbar.md) on, move the pointer to the very top of the page and the toolbar fades in over it. It hides again when the pointer moves away.

<!-- Screenshots: docs/tweaks/images/revealToolbarOnHover-before.png (pointer away) and docs/tweaks/images/revealToolbarOnHover-after.png (pointer at the top).
     Crop like Hide toolbar: the top of the page, right of the sidebar.
     Once they're in, replace each placeholder below with ![Pointer away](images/revealToolbarOnHover-before.png) and ![Pointer at the top](images/revealToolbarOnHover-after.png). -->

| Pointer away | Pointer at the top |
|:---:|:---:|
| _Screenshot coming soon._ | _Screenshot coming soon._ |

## Turn it on

Open **Dia → Settings → Patches** and switch on **Reveal toolbar on hover**. Or run:

```sh
diatweaks enable revealToolbarOnHover
```

## Needs

[Hide toolbar](hideToolbar.md). Settings only shows this switch while that's on, and `diatweaks enable revealToolbarOnHover` offers to turn it on too.

## FAQ

<details>
<summary><strong>Does the page jump when the toolbar shows?</strong></summary>

No. The toolbar shows on top of the page, so the page stays where it is.

</details>

<details>
<summary><strong>When does it hide again?</strong></summary>

A moment after the pointer leaves it. It stays while you type in the address bar or hold the mouse button down, and hides at once when you switch to another window or app.

</details>

<details>
<summary><strong>Why doesn't it show in some windows?</strong></summary>

It only works in the window you're using, while Dia is the active app.

</details>
