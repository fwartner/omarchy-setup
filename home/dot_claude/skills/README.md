Per-machine Claude Code skills, rendered by chezmoi. Each subfolder is a skill
(`SKILL.md` + files) and lands in `~/.claude/skills` on every laptop.

Use this folder only for skills that need templating or live nowhere else.
Skills that come from a repo or a plugin marketplace belong in
`packages/skills.txt`, which `scripts/skills-setup.sh` clones and symlinks in
alongside these — it never touches a directory it did not create.
