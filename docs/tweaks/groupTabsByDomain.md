# Group Tabs by Domain

Puts tabs from the same site into a group named after it, like `example.com`. It's a command, not a switch: it groups once, each time you choose it.

<!-- Screenshots: docs/tweaks/images/groupTabsByDomain-before.png and docs/tweaks/images/groupTabsByDomain-after.png.
     In a new window, open two example.com tabs and two iana.org tabs. Crop to just those tabs in the sidebar, before and after the command.
     Once they're in, replace each placeholder below with ![Before](images/groupTabsByDomain-before.png) and ![After](images/groupTabsByDomain-after.png). -->

| Before | After |
|:---:|:---:|
| _Screenshot coming soon._ | _Screenshot coming soon._ |

## Use it

Right-click a tab and choose **Group Tabs by Domain**, or choose **Tabs → Group Tabs by Domain**. It groups the tabs in the front window. There's nothing to turn on.

## FAQ

<details>
<summary><strong>Does it read my pages?</strong></summary>

No. It only looks at each tab's address.

</details>

<details>
<summary><strong>Which tabs does it leave alone?</strong></summary>

Pinned tabs, tabs already in a group, new tab pages, files and Dia's own pages. A site needs at least two tabs to get a group.

</details>

<details>
<summary><strong>What if I already have a group for a site?</strong></summary>

If a group's name is exactly the site, like `example.com`, that site's tabs join it instead of making a new group.

</details>

<details>
<summary><strong>Are www.example.com and example.com the same site?</strong></summary>

Yes, it ignores `www.`. Other subdomains, like `docs.example.com`, get their own group.

</details>
