---
name: Feature / tool request
about: Add a package, plugin, or behaviour to the setup
labels: enhancement
assignees: ''
---

**What tool or behaviour would you add?**

**Why does it belong in the base fleet config?**
<!-- This repo aims to stay lean. Tools that are project-specific belong in mise.toml or a project devcontainer. -->

**Package source** (pacman / AUR / mise / Omarchy plugin)

**Conflict risk checked?**
- [ ] Not in `omarchy-base.packages` (check with `comm -12 <(pkglist.sh pacman|sort) <(pacman -Slq omarchy|sort)`)
- [ ] No `-bin` / `-git` variant with a `conflicts` entry against this name
- [ ] AUR package does not pull Electron
