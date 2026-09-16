-- Stub of the Omarchy `o`/`hl` API, so bindings.lua can be checked without
-- Hyprland: that the dispatchers are well formed, and that chords Omarchy
-- already owns go through rebind (binding a taken chord twice leaves both
-- dispatchers registered).
--   lua tests/bindings-test.lua
local calls, unbound = {}, {}
hl = { unbind = function(k) unbound[#unbound+1] = k end }
o = {}
function o.bind(keys, desc, disp, opts)
  assert(type(keys)=="string", "keys must be a string")
  assert(type(desc)=="string", "description must be a string")
  assert(disp ~= nil, "dispatcher required")
  calls[#calls+1] = { keys=keys, desc=desc, disp=disp, bound_via="bind" }
end
function o.rebind(keys, desc, disp, opts)
  hl.unbind(keys)
  o.bind(keys, desc, disp, opts); calls[#calls].bound_via = "rebind"
end
dofile("home/dot_config/hypr/bindings.lua")
print(("registered %d bindings, %d unbinds"):format(#calls, #unbound))
for _, c in ipairs(calls) do
  local kind = next(c.disp)
  print(("  %-22s %-14s via %-7s dispatcher.%s = %s"):format(c.keys, c.desc, c.bound_via, kind, c.disp[kind]))
end
-- the three chords Omarchy already owns must go through rebind
local must_rebind = { ["SUPER + SHIFT + P"]=true, ["SUPER + SHIFT + C"]=true }
for _, c in ipairs(calls) do
  if must_rebind[c.keys] then assert(c.bound_via=="rebind", c.keys.." must use rebind") end
  if c.keys == "SUPER + E" then assert(c.bound_via=="bind", "SUPER + E is free; plain bind") end
end
assert(#unbound == 2, "expected exactly 2 unbinds, got "..#unbound)
print("all assertions passed")
