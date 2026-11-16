-- pfUI Octo: performance (modules/perf.lua, perf-options.lua), run by tests\run.lua:
-- the clean-up held in fights and run after, raid graphics lowered and put back, the profiler's report.
local ok = octo_ok
local PF = pfUI.perf
ok(PF and PF.Hold and PF.Clean and PF.ApplyFX and PF.Measure, "performance loaded (pfUI.perf)")
if not PF or not PF.Hold then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.stperf, "Settings > Performance registered")
local S = pfUI_config.perf
ok(S and S.gc == "1" and S.gcextra == "150" and S.raidfx == "1" and S.fxfarclip == "0", "defaults (C.perf)")

local keep = {}
for _, k in ipairs({ "collectgarbage", "gcinfo", "GetCVar", "SetCVar", "IsInInstance", "GetTime", "UnitAffectingCombat",
  "GetFrameCPUUsage", "GetAddOnCPUUsage", "UpdateAddOnCPUUsage", "EnumerateFrames", "GetNumAddOns", "GetAddOnInfo", "ResetCPUUsage" }) do
  keep[k] = rawget(_G, k)
end
local now = 100
_G.GetTime = function() return now end
-- Lua memory: 80 MB in use, the next clean-up at 160 MB
local kb, th, collects, limits = 80 * 1024, 160 * 1024, 0, {}
_G.gcinfo = function() return kb, th end
_G.collectgarbage = function(n)
  n = n or 0
  table.insert(limits, n)
  if n <= kb then collects = collects + 1 kb = 60 * 1024 th = 2 * kb else th = n end
end
_G.UnitAffectingCombat = function() return false end

-- a fight: the threshold goes up by "room for it", no clean-up now
local run = PF.frame:GetScript("OnEvent")
local function Fire(e) _G.event = e run() end
Fire("PLAYER_REGEN_DISABLED")
ok(collects == 0 and th == 80 * 1024 + 150 * 1024 and PF.held, "in a fight: no clean-up, its threshold raised by 150 MB")
-- the fight ends: two seconds later, out of combat, one clean-up
Fire("PLAYER_REGEN_ENABLED")
now = now + 1
PF.Tick()
ok(collects == 0, "not at once")
now = now + 1.5
PF.Tick()
ok(collects == 1 and not PF.held and PF.last and PF.last.why == "after the fight" and PF.last.freed == 20 * 1024, "two seconds after the fight: cleaned (20 MB freed)")
-- back in a fight before the two seconds: none
Fire("PLAYER_REGEN_DISABLED")
Fire("PLAYER_REGEN_ENABLED")
Fire("PLAYER_REGEN_DISABLED")
now = now + 5
PF.Tick()
ok(collects == 1, "a new pull before the clean-up: it waits again")
S.gc = "0"
local before = table.getn(limits)
PF.Hold()
ok(table.getn(limits) == before, "switched off: the game's own clean-up")
S.gc = "1"

-- raid graphics: lowered inside a raid, the player's own values back on leaving
local cvars = { ffxGlow = "1", weatherDensity = "3", particleDensity = "1", showfootprintparticles = "1", farclip = "777" }
_G.GetCVar = function(n) if cvars[n] == nil then error("no such cvar") end return cvars[n] end
_G.SetCVar = function(n, v) cvars[n] = tostring(v) end
pfUI_cache.perfsaved = nil
local inside = { true, "raid" }
_G.IsInInstance = function() return inside[1], inside[2] end
S.fxfarclip = "1"
PF.ApplyFX()
ok(cvars.ffxGlow == "0" and cvars.weatherDensity == "0" and cvars.particleDensity == "0.4" and cvars.showfootprintparticles == "0"
  and cvars.farclip == "350", "in a raid: glow, weather, particles, footsteps and view distance lowered")
ok(pfUI_cache.perfsaved.ffxGlow == "1" and pfUI_cache.perfsaved.farclip == "777", "the player's own values kept")
PF.ApplyFX()
ok(pfUI_cache.perfsaved.ffxGlow == "1", "applying twice keeps the player's values, not ours")
inside = { false }
PF.ApplyFX()
ok(cvars.ffxGlow == "1" and cvars.weatherDensity == "3" and cvars.farclip == "777" and next(pfUI_cache.perfsaved) == nil, "outside: all put back")
inside = { true, "party" }
PF.ApplyFX()
ok(cvars.ffxGlow == "1", "a dungeon: left alone (raids only)")
S.raidfxwhere = "group"
PF.ApplyFX()
ok(cvars.ffxGlow == "0", "with raids and dungeons: lowered")
S.raidfxwhere = "off"
PF.ApplyFX()
ok(cvars.ffxGlow == "1" and next(pfUI_cache.perfsaved) == nil, "Nowhere: put back at once, even inside a raid")
S.raidfxwhere, S.fxfarclip = "raid", "0"
inside = { false }
PF.ApplyFX()
cvars.farclip = "200"
inside = { true, "raid" }
S.fxfarclip = "1"
PF.ApplyFX()
ok(cvars.farclip == "200", "view distance is only ever lowered")
inside = { false }
PF.ApplyFX()
S.fxfarclip = "0"

-- measuring: add-ons and frames by CPU time, pfUI's frames by the module that made them
local fa, fb, fc = {}, {}, {}
fa.GetName = function() return "pfTest" end
fb.GetName = function() return nil end
fb.GetParent = function() return nil end
fb.GetObjectType = function() return "Frame" end
fc.GetName = function() return "OtherAddonFrame" end
PF.tags[fb] = "plates"
local order = { fa, fb, fc }
_G.EnumerateFrames = function(f)
  if not f then return order[1] end
  for i = 1, 3 do if order[i] == f then return order[i + 1] end end
end
local cpu = { [fa] = 50, [fb] = 300, [fc] = 120 }
_G.GetFrameCPUUsage = function(f) return cpu[f] or 0 end
_G.GetNumAddOns = function() return 2 end
_G.GetAddOnInfo = function(i) return i == 1 and "pfUI" or "Other" end
_G.GetAddOnCPUUsage = function(i) return i == 1 and 400 or 900 end
_G.UpdateAddOnCPUUsage = function() end
_G.ResetCPUUsage = function() end
PF.Reset()
now = now + 10
local r = PF.Measure()
ok(r and r.pfui == 400 and r.addons[1][1] == "Other" and r.frames[1][1] == "plates" and r.parts[1][1] == "plates", "the report: add-ons, frames, pfUI's parts")
local lines = PF.Lines(r, 5)
ok(string.find(lines[1], "40.00 ms/s", 1, true) ~= nil, "per second (" .. lines[1] .. ")")
PF.tags[fb] = nil

for k, v in pairs(keep) do rawset(_G, k, v) end
pfUI_cache.perfsaved = nil
