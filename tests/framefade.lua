-- pfUI Octo: Frame fade (modules/framefade.lua, framefade-options.lua), run by tests\run.lua.
-- Fades after the wait, comes back for each reason, keeps pfUI's own opacity, peeking, hover, Try it, switching off.
local ok = octo_ok
local FF = pfUI.framefade
ok(FF and FF.Evaluate and FF.Tick and FF.Status, "frame fade loaded (pfUI.framefade)")
if not FF then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.framefade, "options page Frame fade registered")
local S = pfUI_config.framefade
ok(S and S.enable == "0" and S.g_player == "1" and S.g_bars == "0" and S.alpha == "0", "defaults: off, player and pet only, fades to 0")
ok(rawget(_G, "SLASH_PFFRAMEFADE1") == "/framefade", "/framefade")

local names = { "GetTime", "UnitAffectingCombat", "UnitExists", "UnitHealth", "UnitHealthMax", "UnitMana", "UnitManaMax", "UnitPowerType",
  "UnitIsDeadOrGhost", "UnitOnTaxi", "GetNumPartyMembers", "GetNumRaidMembers", "IsResting", "IsAltKeyDown", "MouseIsOver", "GetPetHappiness" }
local keep = {}
for _, k in ipairs(names) do keep[k] = rawget(_G, k) end
local saved = {}
for k, v in pairs(S) do saved[k] = v end

local t, target, hp, alt, over = 1000, false, 100, false, nil
_G.GetTime = function() return t end
_G.UnitAffectingCombat = function() return nil end
_G.UnitExists = function(u) return (u == "target" and target) or u == "player" end
_G.UnitHealth = function(u) return u == "player" and hp or 100 end
_G.UnitHealthMax = function() return 100 end
_G.UnitMana = function() return 100 end
_G.UnitManaMax = function() return 100 end
_G.UnitPowerType = function() return 0 end
_G.UnitIsDeadOrGhost = function() return nil end
_G.UnitOnTaxi = function() return nil end
_G.GetNumPartyMembers = function() return 0 end
_G.GetNumRaidMembers = function() return 0 end
_G.IsResting = function() return nil end
_G.IsAltKeyDown = function() return alt end
_G.MouseIsOver = function(f) return over == f end
_G.GetPetHappiness = function() return nil end
-- pfUI's environment may hold its own copy (feigndeath.lua's UnitHealth): stubbed there too
local env = getfenv(FF.Tick)
local envKeep = {}
for _, k in ipairs(names) do
  if env ~= _G and rawget(env, k) ~= nil then envKeep[k] = rawget(env, k) rawset(env, k, _G[k]) end
end

local hadPlayer, hadBar = rawget(_G, "pfPlayer"), rawget(_G, "pfActionBarMain")
local pl = hadPlayer or CreateFrame("Frame", "pfPlayer", UIParent)
_G.pfPlayer = pl
pl:Show()
pl:SetAlpha(1)
local bar = _G.pfActionBarMain or CreateFrame("Frame", "pfActionBarMain", UIParent)
_G.pfActionBarMain = bar
local function Run(secs)
  local n = math.floor(secs / .05 + .5)
  for i = 1, n do t = t + .05 FF.Tick() end
end
local function Seen(f) return f.ffRawGet and f.ffRawGet(f) or f:GetAlpha() end

local unlock = pfUI.unlock
if unlock and unlock.Hide then unlock:Hide() end
S.enable, S.delay, S.fadeout, S.fadein = "1", "2", "0.8", "0.2"
FF.resolveAt = 0
FF.Wake()
Run(1)
ok((FF.mul.player or 1) == 1 and Seen(pl) == 1, "all quiet: nothing fades before the wait (" .. tostring(FF.mul.player) .. " "
  .. tostring(Seen(pl)) .. " " .. table.concat(FF.reasons or {}, ",") .. ")")
ok(string.find(FF.Status(), "fading in", 1, true), "status: fading in ... (" .. FF.Status() .. ")")
Run(2.5)
ok(FF.mul.player == 0 and Seen(pl) < .01, "after the wait and the fade: the player frame is gone (" .. tostring(Seen(pl)) .. ")")
ok(bar.ffWrap == nil, "a part that is not picked (action bars) is never touched")
pl:SetAlpha(.5)
ok(pl:GetAlpha() == .5 and Seen(pl) < .01, "pfUI's own opacity is kept (range fade) while faded")

target = true
Run(.5)
ok(FF.mul.player == 1 and math.abs(Seen(pl) - .5) < .01, "a target: back at once, at pfUI's own .5")
ok(string.find(FF.Status(), "you have a target", 1, true), "status names the reason")
target = false
hp = 80
Run(4)
ok(FF.mul.player == 1, "health not full: stays shown (" .. tostring(FF.mul.player) .. " " .. table.concat(FF.reasons or {}, ",") .. ")")
S.hpbelow = "50"
Run(4)
ok(FF.mul.player == 0, "health mark 50%: 80% is fine, faded")
hp = 100
S.hpbelow = "100"

alt = true
Run(.5)
ok(FF.mul.player == 1, "holding Alt: peeking")
alt = false
Run(1.5)
ok(FF.mul.player == 0, "key let go: faded again")
over = pl
Run(.5)
ok(FF.mul.player == 1, "hovered: shown")
over = nil
Run(1.5)
ok(FF.mul.player == 0, "mouse gone: faded")

S.alpha = "0.3"
FF.Wake()
Run(4)
ok(math.abs(FF.mul.player - .3) < .001, "faded to 30%: a faint outline stays")
S.alpha = "0"

S.enable = "0"
FF.Switched()
Run(.5)
ok(FF.mul.player == 1 and math.abs(Seen(pl) - .5) < .01, "switched off: back at once, pfUI's opacity as it was")
FF.Try(8)
Run(2)
ok(FF.mul.player == 0 and string.find(FF.Status(), "Trying", 1, true), "Try it works with the switch off")
Run(7)
ok(FF.mul.player == 1, "...and ends by itself")

-- the options page builds (its preview paints every part)
if O and O.BUILD.framefade and pfUI.gui then
  local good, err = pcall(function() pfUI.gui:Show() O:Open("framefade") end)
  ok(good, "Frame fade page opens " .. tostring(err))
end

for k, v in pairs(saved) do S[k] = v end
for _, k in ipairs(names) do _G[k] = keep[k] end
for k, v in pairs(envKeep) do rawset(env, k, v) end
FF.ShowAll()
pl:SetAlpha(1)
-- the test's frames leave as they came: no wrapper, no stand-in globals
for _, f in ipairs({ pl, bar }) do
  f.SetAlpha, f.GetAlpha, f.ffWrap, f.ffGet, f.ffRawSet, f.ffRawGet, f.ffMul, f.ffBase = nil, nil, nil, nil, nil, nil, nil, nil
end
_G.pfPlayer, _G.pfActionBarMain = hadPlayer, hadBar
FF.resolveAt = 0
