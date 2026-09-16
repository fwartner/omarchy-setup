-- chezmoi-managed. Loaded by ~/.config/hypr/hyprland.lua after Omarchy defaults.
--
-- API verified against omacom/omarchy default/hypr/helpers.lua and
-- default/hypr/bindings/applications.lua:
--   o.bind(keys, description, dispatcher, options)
--   o.rebind(keys, ...)  = hl.unbind(keys) followed by o.bind
--   dispatcher may be a command string or a table: { launch = ... },
--   { tui = ... }, { webapp = ... }, { omarchy = ... }
--
-- Use rebind, not bind, for anything Omarchy already owns: binding a taken chord
-- twice leaves both dispatchers registered.

-- SUPER + E is unbound in Omarchy's 181 default bindings, so a plain bind is safe.
-- SUPER + SHIFT + N stays Omarchy's generic "Editor".
o.bind("SUPER + E", "VS Code", { launch = "code" })

-- Omarchy binds this to Google Photos. Traded for the project switcher.
o.rebind("SUPER + SHIFT + P", "Projects", { tui = "bash -ic 'proj; exec bash -i'" })

-- Omarchy binds this to Calendar. Traded for Claude Code in a chosen project.
o.rebind("SUPER + SHIFT + C", "Claude Code", { tui = "bash -ic 'cd \"$(proj-path)\" && claude'" })

-- SUPER + SHIFT + O is already Obsidian in Omarchy's defaults
-- ({ launch = "obsidian", focus = "^obsidian$" }), which is exactly what we
-- want, so it is deliberately not rebound here.
