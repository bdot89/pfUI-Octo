-- pfUI Octo: world map party / raid dot names (modules/mapcolors.lua), run by tests\run.lua
local ok = octo_ok
local MC = pfUI.mapcolors
if not MC then
  print("mapcolors did not start in the mock: name test skipped")
  return
end
local keepName, keepClass = _G.UnitName, _G.UnitClass
local who = "Oldmate"
_G.UnitName = function(u) if u == "party1" then return who end end
_G.UnitClass = function(u) if u == "party1" then return "Mage", "MAGE" end end
local dot = { unit = "party1" }
local first = MC.ColoredName(dot)
ok(first and string.find(first, "Oldmate", 1, true), "the dot shows its player (" .. tostring(first) .. ")")
who = "Newmate"
local second = MC.ColoredName(dot)
ok(second and string.find(second, "Newmate", 1, true) and not string.find(second, "Oldmate", 1, true),
  "after a group change the dot shows the new player, not the old one")
local _, n = string.gsub(second, "|c", "")
ok(n == 1, "the colour is put on once, not again every hover")
who = nil
ok(MC.ColoredName(dot) == nil, "an empty slot shows no name")
_G.UnitName, _G.UnitClass = keepName, keepClass
