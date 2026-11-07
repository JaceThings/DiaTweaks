Removes the selected sidebar tab's glow and glass highlights and gives its existing border one consistent color. The title, favicon and tab behavior stay the same. Horizontal tabs keep their original styling.

| Before | After |
|:---:|:---:|
| ![Selected sidebar tab with its glow and fading border](https://github.com/user-attachments/assets/50e02a6b-f15b-4c67-be88-24166e7097b7) | ![Selected sidebar tab with the glow removed and a uniform border](https://github.com/user-attachments/assets/e2b047dc-3dd5-41f1-bce9-9a5e117b5cb5) |

## Why use it

The glow and fading edge can make the selected tab stand out more than you want. This gives it a flatter look while keeping a clear outline.

## Turn it on

Open **Dia → Settings → Patches** and switch on **Hide Vertical Tab Glow** under **Sidebar & Tab Bar**. Or run:

```sh
diatweaks enable hideVerticalTabGlow
```

The tweak is off by default. To restore Dia's original styling, switch it off or run:

```sh
diatweaks disable hideVerticalTabGlow
```

## Works with

[Window Material](Window-Material) keeps styling the rest of the window. Glass inside the selected sidebar tab is flattened so its edge stays even.

## FAQ

<details>
<summary><strong>What happens to the selected tab's border?</strong></summary>

It keeps its existing shape. The fading colors become one consistent color from Dia's own palette.

</details>

<details>
<summary><strong>What happens when I turn it off?</strong></summary>

Dia's original shadow, border colors and glass highlights return.

</details>
