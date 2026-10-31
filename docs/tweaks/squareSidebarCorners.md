# Square corners by the sidebar

Dia rounds all four corners of the page, even the two next to the sidebar. This tweak makes those two square, so the page meets the sidebar in a straight line.

<!-- Screenshots: docs/tweaks/images/squareSidebarCorners-before.png and docs/tweaks/images/squareSidebarCorners-after.png.
     Crop to the bottom-left corner of the page, where it meets the sidebar, with this tweak off, then on. Edge-to-edge stays on.
     Once they're in, replace each placeholder below with ![Before](images/squareSidebarCorners-before.png) and ![After](images/squareSidebarCorners-after.png). -->

| Before | After |
|:---:|:---:|
| _Screenshot coming soon._ | _Screenshot coming soon._ |

## Turn it on

It's on by default. Open **Dia → Settings → Patches** and switch on **Square corners by the sidebar**. Or run:

```sh
diatweaks enable squareSidebarCorners
```

## Needs

[Edge-to-edge web content](edgeToEdge.md). Settings only shows this switch while that's on, and `diatweaks enable squareSidebarCorners` offers to turn it on too.

## FAQ

<details>
<summary><strong>Why don't I see a difference?</strong></summary>

It only changes the corners next to the sidebar. With tabs at the top, the sidebar hidden or Chat open, it leaves the corners alone.

</details>
