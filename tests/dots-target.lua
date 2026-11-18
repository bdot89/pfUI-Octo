-- pfUI Octo: OctoDoTs > Target bar (modules/dots-target.lua), run by tests\run.lua:
-- your own debuffs on the target as icons, track / ignore per spell, missing tracked ones greyed, the page first in OctoDoTs.
local ok = octo_ok
local TB = pfUI.dotsTarget
ok(TB and TB.Collect and TB.Layout and TB.Cycle, "target bar loaded (pfUI.dotsTarget)")
if not TB then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.dottarget, "OctoDoTs > Target bar registered")
local firstTab
for _, s in ipairs(O and O.octo or {}) do if s[1] == "OctoDoTs" then firstTab = s[2][1] and s[2][1][1] end end
ok(firstTab == "dottarget", "Target bar is the first tab of OctoDoTs (" .. tostring(firstTab) .. ")")
local S = pfUI_config.dots
ok(S.tb_on == "0" and S.tb_mode == "all" and S.tb_missing == "1" and type(S.tb_list) == "table", "defaults (off until switched on)")

local keep = {}
for _, k in ipairs({ "UnitExists", "UnitIsDead", "UnitCanAttack", "GetTime" }) do keep[k] = rawget(_G, k) end
local keepRead, keepClassic, keepSW = pfUI.dots.Read, pfUI.dots.Classic, pfUI.dots.SuperWoW
local now = 1000
_G.GetTime = function() return now end
_G.UnitExists = function(u) return u == "target" and 1 or nil end
_G.UnitIsDead = function() return nil end
_G.UnitCanAttack = function() return 1 end
pfUI.dots.Classic = function() return true end
-- on the target: my Rake and Rip, someone else's Moonfire
pfUI.dots.Read = function(u)
  u.auras = {
    { name = "Rake", icon = "Interface\\Icons\\Ability_Druid_Disembowel", ends = now + 6, dur = 9, stacks = 0, kind = "mine" },
    { name = "Rip", icon = "Interface\\Icons\\Ability_GhoulFrenzy", ends = now + 3, dur = 12, stacks = 0, kind = "mine" },
    { name = "Moonfire", icon = "Interface\\Icons\\Spell_Nature_StarFall", ends = now + 9, dur = 12, stacks = 0, kind = "other" },
  }
  u.na = 3
  return true
end
S.tb_list = {}
local function Names(list)
  local out = {}
  for _, e in ipairs(list) do table.insert(out, e.name .. (e.missing and "?" or "")) end
  return table.concat(out, ",")
end
local list = TB.Collect(now)
ok(Names(list) == "Rip,Rake", "all of mine, running out first; others' debuffs left out (" .. Names(list) .. ")")
ok(S.tb_seen.rake == "Interface\\Icons\\Ability_Druid_Disembowel", "icons of debuffs seen are remembered for the picker")
TB.Cycle("Rip")
TB.Cycle("Rip")
ok(TB.State("Rip") == "ignore", "click twice: ignored")
ok(Names(TB.Collect(now)) == "Rake", "ignored Rip is not shown")
TB.Cycle("Rip")
ok(TB.State("Rip") == nil, "third click: neither")
TB.Cycle("Insect Swarm")
ok(Names(TB.Collect(now)) == "Rip,Rake,Insect Swarm?", "a tracked debuff that is missing shows greyed at the end (" .. Names(TB.Collect(now)) .. ")")
S.tb_mode = "list"
ok(Names(TB.Collect(now)) == "Insect Swarm?", "only tracked: just the tracked ones")
S.tb_mode = "all"
S.tb_missing = "0"
ok(Names(TB.Collect(now)) == "Rip,Rake", "missing ones switched off")
S.tb_missing = "1"
-- the icons: time left, red under the warning, the shade drains
local holder = CreateFrame("Frame", nil, UIParent)
TB.Layout(holder, TB.Collect(now), now)
ok(holder.icons[1].time:GetText() == "3" and holder.icons[2].time:GetText() == "6", "time left on the icons")
ok(holder.icons[3]:IsShown() and holder.icons[3].time:GetText() == "", "missing icon: no time")
-- no target / a friendly one: nothing
_G.UnitCanAttack = function() return nil end
ok(table.getn(TB.Collect(now)) == 0, "friendly target: empty bar")
local spells = TB.Spells()
ok(table.getn(spells) > 0, "the picker lists spells (" .. table.getn(spells) .. ")")

S.tb_list = {}
pfUI.dots.Read, pfUI.dots.Classic, pfUI.dots.SuperWoW = keepRead, keepClassic, keepSW
for k, v in pairs(keep) do _G[k] = v end
