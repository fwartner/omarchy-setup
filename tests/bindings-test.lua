-- Checks home/dot_config/hypr/bindings.lua against the Omarchy 4.x Lua API
-- without Hyprland:  lua tests/bindings-test.lua
--
-- The stub is STRICT. Any field bindings.lua reaches for that Omarchy 4.x does
-- not define is an error here, the same as it is on the laptop. An earlier
-- version of this file defined o.rebind itself, so it happily confirmed a
-- helper that does not exist before 5.x -- the laptop answered with
--   bindings.lua:18: attempt to call a nil value (field 'rebind')
-- which is the failure this stub now reproduces.
--
-- The surfaces below are transcribed from tag v4.0.4:
--   default/hypr/helpers.lua   (the `o` helpers)
--   config/hypr/bindings.lua   (the `hl` calls a user config is shown)
-- Add a name here only after checking it against the version the fleet runs.

local calls, unbound = {}, {}

local function strict(namespace, surface)
  return setmetatable(surface, {
    __index = function(_, key)
      error(("%s.%s does not exist in the Omarchy 4.x API"):format(namespace, key), 2)
    end,
  })
end

hl = strict("hl", {
  unbind = function(keys) unbound[#unbound + 1] = keys end,
  bind = function() end,
  env = function() end,
  monitor = function() end,
  window_rule = function() end,
  on = function() end,
  exec_cmd = function() end,
  dsp = { exec_cmd = function(c) return c end },
})

o = strict("o", {
  bind = function(keys, description, dispatcher, _)
    assert(type(keys) == "string", "keys must be a string")
    assert(description == nil or type(description) == "string", "description must be a string or nil")
    assert(dispatcher ~= nil, "dispatcher required")
    calls[#calls + 1] = { keys = keys, desc = description, disp = dispatcher }
  end,
  -- The rest of v4.0.4 helpers.lua, so reaching for one of these is not an
  -- error, but reaching for anything absent from this list is.
  shell_quote = function(v) return v end,
  shell_succeeds = function() return true end,
  cmd_present = function() return true end,
  cmd_missing = function() return false end,
  preinstalled_bindings_enabled = function() return true end,
  launch = function(c) return c end,
  exec_on_start = function() end,
  launch_on_start = function() end,
  launch_webapp = function(u) return u end,
  launch_webapp_sole = function(_, u) return u end,
  launch_sole = function(_, c) return c end,
  bind_toggle = function() end,
  notify = function(m) return m end,
  window = function() end,
})

dofile("home/dot_config/hypr/bindings.lua")

local was_unbound = {}
for _, k in ipairs(unbound) do was_unbound[k] = true end

print(("registered %d bindings, %d unbinds"):format(#calls, #unbound))
for _, c in ipairs(calls) do
  local kind = next(c.disp)
  print(("  %-22s %-14s %-9s dispatcher.%s = %s"):format(
    c.keys, c.desc, was_unbound[c.keys] and "unbound" or "free", kind, c.disp[kind]))
end

-- Chords Omarchy already owns must be unbound before they are bound, or both
-- dispatchers stay registered and the chord fires two things.
local owned = { ["SUPER + SHIFT + P"] = true, ["SUPER + SHIFT + C"] = true }
local seen = {}
for _, c in ipairs(calls) do
  seen[c.keys] = true
  if owned[c.keys] then
    assert(was_unbound[c.keys], c.keys .. " is an Omarchy default: hl.unbind it before binding")
  end
  if c.keys == "SUPER + E" then
    assert(not was_unbound[c.keys], "SUPER + E is free in Omarchy defaults; no unbind needed")
  end
end
for _, k in ipairs(unbound) do
  assert(seen[k], k .. " was unbound but never bound; use hl.unbind alone only to disable a chord")
end
assert(#unbound == 2, "expected exactly 2 unbinds, got " .. #unbound)

print("all assertions passed")
