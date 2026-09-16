-- chezmoi-managed. Loaded by ~/.config/hypr/hyprland.lua after Omarchy defaults.
--
-- API pinned to Omarchy 4.x (default/hypr/helpers.lua at v4.0.4):
--   o.bind(keys, description, dispatcher, options)
--   hl.unbind(keys)
--   dispatcher may be a command string or a table: { launch = ... },
--   { tui = ... }, { webapp = ... }, { omarchy = ... }
--
-- There is no o.rebind in 4.x -- it exists only on the development branch.
-- Unbind first, then bind, which is what 4.0.4's own config/hypr/bindings.lua
-- template documents. Binding a taken chord without unbinding leaves both
-- dispatchers registered.

-- SUPER + E is unbound in Omarchy's 181 default bindings, so a plain bind is safe.
-- SUPER + SHIFT + N stays Omarchy's generic "Editor".
o.bind("SUPER + E", "VS Code", { launch = "code" })

-- Omarchy binds this to Google Photos. Traded for the project switcher.
hl.unbind("SUPER + SHIFT + P")
o.bind("SUPER + SHIFT + P", "Projects", { tui = "bash -ic 'proj; exec bash -i'" })

-- Omarchy binds this to Calendar. Traded for Claude Code in a chosen project.
hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Claude Code", { tui = "bash -ic 'cd \"$(proj-path)\" && claude'" })

-- SUPER + SHIFT + O is already Obsidian in Omarchy's defaults
-- ({ launch = "obsidian", focus = "^obsidian$" }), which is exactly what we
-- want, so it is deliberately not rebound here.
