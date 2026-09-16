-- chezmoi-managed. Omarchy assumes 2x HiDPI; older 13"/14" panels want 1.
-- Loaded by ~/.config/hypr/hyprland.lua after Omarchy defaults.
local omarchy_gdk_scale = {{ .gdk_scale }}

o.env("GDK_SCALE", omarchy_gdk_scale)
o.monitor(",preferred,auto,auto")
