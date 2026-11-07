# Wiki changes for Hide Vertical Tab Glow

The wiki is a separate repository at [JaceThings/DiaTweaks.wiki](https://github.com/JaceThings/DiaTweaks.wiki.git). These files add the tweak page and its link under **Sidebar & Tab Bar**.

A maintainer with wiki write access can apply them from the main repository's root:

```sh
wiki_dir=/path/to/DiaTweaks.wiki
cp docs/wiki/Hide-Vertical-Tab-Glow.md "$wiki_dir/"
git -C "$wiki_dir" apply "$PWD/docs/wiki/sidebar.patch"
git -C "$wiki_dir" add Hide-Vertical-Tab-Glow.md _Sidebar.md
git -C "$wiki_dir" commit -m "docs: add hide vertical tab glow wiki page"
git -C "$wiki_dir" push
```

The page uses the before/after screenshots attached to PR #306. The Settings preview remains separate: record and publish it under `previews/` using the format in `CONTRIBUTING.md`.

The page and sidebar entry pass `scripts/check-tweak-docs` against the prepared wiki checkout. The upstream documentation check will stay red until the files are published to the upstream wiki.
