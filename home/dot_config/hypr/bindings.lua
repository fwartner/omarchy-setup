-- chezmoi-managed personal bindings. Omarchy defaults are loaded first;
-- unbind before rebinding to avoid duplicate bindings after updates.
-- See https://omarchy.org/manual/dotfiles/ for the o.* / hl.* API.

-- Editor: VS Code on Super+E (Omarchy default opens $EDITOR in a terminal)
hl.unbind("SUPER + E")
o.bind("SUPER + E", "VS Code", "code")

-- Project switcher (fzf over ~/Projects) in a terminal
o.bind("SUPER + SHIFT + P", "Projects", "$TERMINAL -e bash -ic proj")

-- Claude Code in current project dir
o.bind("SUPER + SHIFT + C", "Claude Code", "$TERMINAL -e bash -ic 'cd $(proj-path) && claude'")

-- Obsidian vault
o.bind("SUPER + SHIFT + O", "Obsidian", "obsidian")
