-- pfUI Octo: OctoDoTs > Target bar (modules/dots-target.lua), run by tests\run.lua:
-- your own debuffs on the target as icons, track / ignore per spell, missing tracked ones greyed, the page first in OctoDoTs.
local ok = octo_ok
local TB = pfUI.dotsTarget
ok(TB and TB.Collect and TB.Layout and TB.Cycle, "target bar loaded (pfUI.dotsTarget)")
if not TB then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.dottarget, "OctoDoTs > Target bar registered")
local tabs = {}
for _, s in ipairs(O and O.octo or {}) do if s[1] == "OctoDoTs" then for i, pg in ipairs(s[2]) do tabs[i] = pg[1] end end end
ok(tabs[1] == "dotgeneral" and tabs[2] == "dottarget", "Target bar is the tab right after General (" .. table.concat(tabs, ", ") .. ")")
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

-- layout mode / the test show the bar with samples even while it is switched off (its box must be there to move)
do
  local drv = _G.pfDotTargetBarDriver
  local bar = TB.frame
  pfUI_config.dots.tb_on = "0"
  TB.testUntil = GetTime() + 20
  TB.dirty = true
  _G.this = drv
  drv:GetScript("OnUpdate")()
  ok(bar:IsShown(), "switched off but testing / in layout mode: the bar (and its box) shows")
  local size, gap = tonumber(pfUI_config.dots.tb_size) or 34, tonumber(pfUI_config.dots.tb_gap) or 3
  ok(math.abs(bar:GetWidth() - (6 * (size + gap) - gap)) < 1, "its box is 6 icons wide (Room for icons)")
  TB.testUntil = 0
  TB.dirty = true
  drv:GetScript("OnUpdate")()
  ok(not bar:IsShown(), "test over and switched off: hidden")
end

-- (18 Nov 2026) Show: both / bars only / target bar only
do
  TB.SetWhich("target")
  ok(pfUI_config.dots.tb_on == "1" and pfUI_config.dots.which == "target" and TB.Which() == "target", "Target bar only: bar on, bars away")
  local D = pfUI.dots
  local frame = D.frame
  if frame and D.Paint and D.Testing and not D.Testing() then
    -- (the mock keeps visibility in .shown, which D.Paint uses for its row count: watch Hide instead)
    local realHide, realShown = frame.Hide, frame.IsShown
    local hidden
    frame.IsShown = function() return true end
    frame.Hide = function() hidden = true end
    D.Paint(GetTime())
    frame.Hide, frame.IsShown = realHide, realShown
    ok(hidden, "Target bar only: the mob bars hide")
  end
  TB.SetWhich("bars")
  ok(pfUI_config.dots.tb_on == "0" and pfUI_config.dots.which == "both" and TB.Which() == "bars", "Bars only: the target bar is off")
  TB.SetWhich("both")
  ok(pfUI_config.dots.tb_on == "1" and TB.Which() == "both", "Both")
  pfUI_config.dots.tb_on, pfUI_config.dots.which = "0", "both"
end

-- per spell glow, numbers and animations (the right-click menu)
do
  local S2 = pfUI_config.dots
  ok(TB.Get("Rip", "glow") == "off" and TB.Get("Rip", "when") == "low" and not TB.Custom("Rip"), "defaults: no glow, nothing saved")
  TB.Set("Rip", "glow", "border")
  TB.Set("Rip", "low", "pulse")
  TB.Set("Rip", "tsize", "big")
  ok(S2.tb_spell.rip.glow == "border" and S2.tb_spell.rip.low == "pulse" and TB.Custom("Rip"), "picks saved for that spell")
  local holder = CreateFrame("Frame", nil, UIParent)
  local t = 5000
  local e = { name = "Rip", icon = "x", ends = t + 2, dur = 12, stacks = 0 }
  TB.Layout(holder, { e }, t)
  local f = holder.icons[1]
  ok(f.glowStyle == "border" and f.lowAnim == "pulse", "running out: its glow and animation on")
  TB.Animate(f, t)
  ok(f.rim:IsShown(), "the bright border shows")
  e.ends = t + 10
  TB.Layout(holder, { e }, t)
  ok(f.glowStyle == "off" and f.lowAnim == "none", "plenty of time: no glow (glow when running out)")
  TB.Set("Rip", "when", "always")
  TB.Layout(holder, { e }, t)
  ok(f.glowStyle == "border", "glow when always")
  TB.Set("Rip", "timer", "0")
  TB.Layout(holder, { e }, t)
  ok(f.time:GetText() == "", "time hidden for this spell only")
  TB.Set("Rip", "glow", "off")
  ok(S2.tb_spell.rip.glow == nil, "back to the usual value: nothing saved for it")
  TB.ResetSpell("Rip")
  ok(not TB.Custom("Rip"), "Back to the usual clears the spell")
  ok(TB.Menu and TB.Menu(holder, "Rip"), "the right-click menu opens")
  if pfUI.octoui and pfUI.octoui.W and pfUI.octoui.W.CloseMenus then pfUI.octoui.W.CloseMenus() end
end
