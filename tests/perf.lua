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

-- (18 Nov 2026) the memory ceiling: out-of-memory crashes (#132 in d3d9.dll) when Lua's garbage doubled the 290 MB
ok(S.gccap == "1" and S.gcroom == "64" and S.gcmax == "600", "ceiling defaults: on, 64 MB room, 600 MB")
PF.held, PF.live, PF.lastKb = false, nil, nil
kb, th = 290 * 1024, 580 * 1024
PF.Steer()
ok(th == 290 * 1024 + 64 * 1024, "out of a fight: garbage may grow 64 MB, not double (threshold " .. math.floor(th / 1024) .. " MB)")
PF.held = true
PF.Steer()
ok(th == 290 * 1024 + 150 * 1024, "in a fight: the fight's room (150 MB)")
S.gcmax = "400"
PF.Steer()
ok(th == 400 * 1024, "never past the ceiling (" .. math.floor(th / 1024) .. " MB)")
local c0 = collects
kb = 410 * 1024
PF.Steer()
ok(collects == c0 + 1 and not PF.held, "past the ceiling: cleaned at once, even in a fight")
S.gcmax = "600"
kb, th = 300 * 1024, 600 * 1024
PF.live, PF.lastKb = nil, nil
S.gccap = "0"
local n0 = table.getn(limits)
PF.Steer()
ok(table.getn(limits) == n0, "ceiling off: Lua's own clean-up")
S.gccap = "1"
PF.held, PF.live, PF.lastKb = false, nil, nil

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

-- the live window (perf-window.lua, 17 Nov 2026): scripts found through EnumerateFrames, never by walking tables
local PW = PF.win
ok(PW and PW.Scan and PW.Unhook and PW.Rows and PW.Toggle, "live window loaded (pfUI.perf.win)")
if PW then
  local keep2 = { debugprofilestop = rawget(_G, "debugprofilestop"), GetAddOnMemoryUsage = rawget(_G, "GetAddOnMemoryUsage"),
    UpdateAddOnMemoryUsage = rawget(_G, "UpdateAddOnMemoryUsage"), IsAddOnLoaded = rawget(_G, "IsAddOnLoaded") }
  local clock = 0
  _G.debugprofilestop = function() return clock end
  local function Frame(name)
    local fr = { s = {} }
    fr.GetName = function() return name end
    fr.GetParent = function() return nil end
    fr.GetObjectType = function() return "Frame" end
    fr.GetScript = function(self, s) return self.s[s] end
    fr.SetScript = function(self, s, fn) self.s[s] = fn end
    return fr
  end
  local f1, f2 = Frame("BusyFrame"), Frame("QuietFrame")
  local ran, got = 0, nil
  local up = function(a) ran = ran + 1 got = a clock = clock + 4 kb = kb + 10 end
  local ev = function() end
  f1.s.OnUpdate = up
  f2.s.OnEvent = ev
  local frames = { f1, f2 }
  _G.EnumerateFrames = function(f)
    if not f then return frames[1] end
    for i = 1, 2 do if frames[i] == f then return frames[i + 1] end end
  end
  PW.Reset()
  local seen, added = PW.Scan()
  ok(seen == 2 and added == 2 and f1.s.OnUpdate ~= up and PW.Hooked() == 2, "Scan wraps every frame's OnUpdate / OnEvent (" .. tostring(seen) .. ", " .. tostring(added) .. ")")
  local s2, a2 = PW.Scan()
  ok(a2 == 0, "scanning again wraps nothing twice")
  f1.s.OnUpdate("x") f1.s.OnUpdate("x")
  local rec = PW.data["BusyFrame:OnUpdate()"]
  ok(ran == 2 and got == "x" and rec and rec.calls == 2 and rec.ms == 8 and rec.kb == 20, "a wrapped script still runs (arguments kept) and is counted: calls, ms, KB")
  PW.Step(2)
  ok(rec.nc == 1 and rec.nm == 4, "now = per second since the last refresh")
  PW.sort = "ms"
  local rows = PW.Rows()
  ok(rows[1] and rows[1].label == "BusyFrame:OnUpdate()" and table.getn(rows) == 1, "list sorted by time, scripts that never ran left out")
  PW.on = false
  f1.s.OnUpdate()
  ok(rec.calls == 2 and ran == 3, "paused: runs, not counted")
  PW.on = true
  -- an add-on swapped its script after the scan: scanned again, the new one is wrapped
  local newup = function() end
  f1.s.OnUpdate = newup
  local _, a3 = PW.Scan()
  ok(a3 == 1 and f1.s.OnUpdate ~= newup, "a script swapped since the scan is wrapped again")
  local n = PW.Unhook()
  ok(n == 2 and f1.s.OnUpdate == newup and f2.s.OnEvent == ev and PW.Hooked() == 0, "Stop puts every script back")
  -- add-ons tab
  _G.IsAddOnLoaded = function() return true end
  local mem = { 2048, 300 }
  _G.GetAddOnMemoryUsage = function(i) return mem[i] end
  _G.UpdateAddOnMemoryUsage = function() end
  PW.addons = {}
  PW.StepAddons(1)
  mem[1] = 2148
  PW.StepAddons(2)
  PW.mode, PW.sort = "addons", "mem"
  rows = PW.Rows()
  ok(rows[1] and rows[1].label == "pfUI" and rows[1].cols[4] == "2.1 MB" and rows[1].v.grow == 50, "add-ons: memory and KB/s per add-on (" .. tostring(rows[1] and rows[1].cols[4]) .. ")")
  PW.mode, PW.sort = "scripts", "now"
  PW.Toggle(true)
  ok(PW.frame and PW.frame:IsShown(), "the window opens")
  PW.Refresh()
  -- many rows: the scroll bar and the "x-y of n" count follow the wheel
  PW.data = {}
  for i = 1, 45 do local r = PW.Rec("Row" .. i .. ":OnUpdate()") r.calls, r.ms = i, i end
  PW.offset = 0
  PW.Refresh()
  local lo, hi = PW.frame.bar:GetMinMaxValues()
  ok(PW.frame.bar:IsShown() and hi == 25 and PW.frame.count:GetText() == "1-20 of 45", "scroll bar: 45 rows, 20 shown (" .. tostring(hi) .. ", " .. tostring(PW.frame.count:GetText()) .. ")")
  _G.arg1 = -1
  PW.frame:GetScript("OnMouseWheel")()
  ok(PW.frame.bar:GetValue() == 3 and PW.frame.count:GetText() == "4-23 of 45", "the wheel moves the list and the bar")
  -- Copy all: one plain text with every script by time, then the add-ons
  local text, lines = PW.Text()
  ok(type(text) == "string" and string.find(text, "SCRIPTS", 1, true) and string.find(text, "Row45:OnUpdate()", 1, true)
    and string.find(text, "ADD-ONS", 1, true) and not string.find(text, "|c", 1, true), "Copy all: plain text, scripts and add-ons")
  ok(string.find(text, "Row45", 1, true) < string.find(text, "Row1:", 1, true), "Copy all: costliest script first")
  -- every script goes in, also ones that never ran (17 Nov 2026: "over 2500 scripts ... get all of them")
  PW.data = {}
  for i = 1, 950 do local r = PW.Rec("S" .. i .. ":OnEvent()") r.calls, r.ms = (i > 900) and 0 or i, (i > 900) and 0 or i end
  local all = PW.Lines()
  local listed = 0
  for _, l in ipairs(all) do if string.find(l, ":OnEvent()", 1, true) then listed = listed + 1 end end
  ok(listed == 950, "Copy all: every script listed, also the 50 that never ran (" .. listed .. ")")
  -- frozen into parts of 400 lines; the box steps through them and marks the copied ones
  local copied
  local lcl = pfUI.api.libclient
  local oldCopy = lcl.Copy
  lcl.Copy = function(t) copied = t return true end
  PW.snap = nil
  PW.CopyAll()
  local snap = PW.snap
  local parts = snap and table.getn(snap.parts) or 0
  ok(parts == math.ceil(table.getn(snap.lines) / 400) and parts >= 3 and PW.copybox:IsShown() and snap.at == 1, "Copy all: frozen, cut into " .. parts .. " parts, part 1 shown")
  ok(string.find(PW.PartText(2), "part 2 of " .. parts, 1, true) ~= nil, "each part says which it is")
  PW.CopyPart()
  ok(snap.done[1] and copied and string.find(copied, "part 1 of", 1, true), "Copy this part: on the clipboard, marked copied")
  -- new numbers after the snapshot do not change it
  PW.Rec("Late:OnUpdate()").calls = 5
  PW.copybox.next:Click()
  ok(snap.at == 2 and not string.find(PW.PartText(2) .. PW.PartText(3), "Late:", 1, true), "Next: part 2, the numbers stay frozen")
  -- Ctrl+C in the box marks the shown part
  local ctrl = rawget(_G, "IsControlKeyDown")
  _G.IsControlKeyDown = function() return true end
  _G.arg1 = "C"
  PW.copybox.edit:GetScript("OnKeyDown")()
  _G.IsControlKeyDown = ctrl
  ok(snap.done[2], "Ctrl+C in the box: that part marked copied")
  PW.copybox:Hide()
  PW.CopyAll()
  ok(PW.snap == snap and snap.at == 2, "Copy all again before the end: carries on where you were")
  PW.copybox.all:Click()
  local alldone = true
  for k = 1, parts do if not snap.done[k] then alldone = false end end
  ok(alldone and string.find(copied, "Late:", 1, true) == nil, "Copy all at once: every part marked")
  lcl.Copy = oldCopy
  PW.copybox:Hide()
  -- the HUD: top 5 by ms a second now, short names, on / off kept in C.perf.hud
  PW.data = {}
  local vals = { 0.3, 4.2, 0, 1.5, 0.9, 7.1, 0.05, 2.2 }
  for i, v in ipairs(vals) do local r = PW.Rec("S" .. i .. ":OnUpdate()") r.calls, r.nm = 10, v end
  PW.Rec("unnamed Frame (other add-ons / game):OnUpdate()").nm = 0.5
  local t5, n5 = PW.Top(5)
  ok(n5 == 5 and t5[1].nm == 7.1 and t5[2].nm == 4.2 and t5[3].nm == 2.2 and t5[4].nm == 1.5 and t5[5].nm == 0.9,
    "HUD: the five busiest now, in order (" .. n5 .. ")")
  local txt = PW.HUDText()
  ok(string.find(txt, "fps", 1, true) and string.find(txt, "7.10", 1, true) and string.find(txt, "S6", 1, true)
    and not string.find(txt, ":OnUpdate()", 1, true) and not string.find(txt, "S3", 1, true), "HUD text: fps line + top 5, short names")
  PW.data = {}
  PW.Rec("unnamed Frame (other add-ons / game):OnUpdate()").nm = 3
  ok(string.find(PW.HUDText(), "other Frame", 1, true) ~= nil, "HUD: other add-ons' frames named shortly")
  PW.SetHUD(true)
  ok(pfUI_config.perf.hud == "1" and PW.hudFrame:IsShown() and not PW.hudFrame:IsMouseEnabled(), "HUD on: shown, click-through")
  PW.SetHUD(false)
  ok(pfUI_config.perf.hud == "0" and not PW.hudFrame:IsShown(), "HUD off: hidden")
  PW.Unhook()
  -- text fits its column: long names are cut with "..."
  local fsx = PW.frame.rows[1].cols[1]
  local oldW = fsx.GetStringWidth
  fsx.GetStringWidth = function(self) return string.len(self:GetText() or "") * 6 end
  PW.Fit(fsx, string.rep("x", 100), 270)
  local cut = fsx:GetText()
  fsx.GetStringWidth = oldW
  ok(string.len(cut) * 6 <= 270 and string.sub(cut, -3) == "...", "a long name is cut to fit its column (" .. string.len(cut) .. ")")
  PW.Toggle(false)
  PW.Reset()
  for k, v in pairs(keep2) do rawset(_G, k, v) end
end

-- (17 Nov 2026) the game's own UI ticker 30 times a second, given all the time since its last run
if PF.WrapUIParent and UIParent and UIParent.SetScript then
  local runs, seen = 0, {}
  UIParent:SetScript("OnUpdate", function() runs = runs + 1 table.insert(seen, _G.arg1) end)
  PF.uiWrapped = nil
  PF.WrapUIParent()
  local tick = UIParent:GetScript("OnUpdate")
  S.uitick = "1"
  for _ = 1, 10 do _G.arg1 = 1 / 120 tick() end
  ok(runs == 2 and math.abs(seen[1] - 4 / 120) < 1e-6, "UI ticker: 10 frames at 120 fps = 2 runs, each given its 1/30 s (" .. runs .. ")")
  S.uitick = "0"
  runs = 0
  for _ = 1, 3 do _G.arg1 = 1 / 120 tick() end
  ok(runs == 3, "UI ticker off: every frame, as the game does")
  S.uitick = "1"
end

-- the swing timer rests at four draws a second when nothing happens (its clock is the mock's Mock.now)
local SW = pfUI.swing
if SW and SW.ticker and Mock then
  local tk = SW.ticker:GetScript("OnUpdate")
  local paints, rawPaint = 0, SW.Paint
  SW.Paint = function(a, b, c, d) paints = paints + 1 return rawPaint(a, b, c, d) end
  SW.testUntil = 0
  local keepNow, keepCombat = Mock.now, rawget(_G, "UnitAffectingCombat")
  _G.UnitAffectingCombat = function() return false end
  Mock.now = Mock.now + 1000
  _G.this = SW.ticker
  SW.ticker.calmAt = 0
  for _ = 1, 30 do Mock.now = Mock.now + 1 / 120 tk() end
  ok(paints >= 1 and paints <= 8, "swing: nothing happening, a quarter second = a few draws, not 30 a bar (" .. paints .. ")")
  Mock.now = keepNow
  _G.UnitAffectingCombat = keepCombat
  SW.Paint = rawPaint
end

-- the swing timer's test ticker only runs during a test
local ST = pfUI.swing
if ST and ST.testFrame then
  ST.testUntil = 0
  local tick = ST.testFrame:GetScript("OnUpdate")
  if tick then _G.this = ST.testFrame tick() end
  ok(ST.testFrame:GetScript("OnUpdate") == nil, "swing: no test running, its ticker sleeps")
  ST.Test(1)
  ok(ST.testFrame:GetScript("OnUpdate") ~= nil, "swing: a test wakes it")
  ST.testUntil = 0
end

-- (20 Nov 2026) monitor Hz, Linux mode, PerfBoost
if PF.SetDisplay then
  local cv = { gxRefresh = "60", gxVSync = "1", gxTripleBuffer = "0", gxWindow = "0", gxFixLag = "1", gxCursor = "0",
    PB_Enabled = "0", PB_PlayerRenderDist = "-1", PB_PlayerRenderDistInCombat = "-1", PB_PlayerRenderDistInCities = "-1",
    PB_PetRenderDistInCombat = "-1", PB_TrashUnitRenderDistInCombat = "-1" }
  local restarts, anim = 0, nil
  local keepRG, keepRR, keepAnim = rawget(_G, "RestartGx"), rawget(_G, "GetRefreshRates"), rawget(_G, "SetMaxAnimFramerate")
  _G.GetCVar = function(n) if cv[n] == nil then error("no such cvar") end return cv[n] end
  _G.SetCVar = function(n, v) if cv[n] == nil then error("no such cvar") end cv[n] = tostring(v) end
  _G.RestartGx = function() restarts = restarts + 1 end
  _G.SetMaxAnimFramerate = function(n) anim = n end
  _G.UnitAffectingCombat = function() return false end
  -- the game lists rates as strings
  _G.GetRefreshRates = function() return "60", "120", "144" end
  local r = PF.Rates()
  ok(table.getn(r) == 3 and r[3] == 144 and PF.ratesFromGame, "refresh rates read from the game (60, 120, 144)")
  _G.GetRefreshRates = function() return nil end
  r = PF.Rates()
  ok(not PF.ratesFromGame and table.getn(r) >= 10, "no list from the game: the usual rates")
  -- apply 144 Hz with vsync off: set, one graphics restart, the keep box up
  ok(PF.SetDisplay(144, false, false) and cv.gxRefresh == "144" and cv.gxVSync == "0" and restarts == 1, "Apply: 144 Hz, vsync off, graphics restarted once")
  ok(PF.keepBox and PF.keepBox:IsShown() and PF.keepOld, "the keep-it box is up")
  ok(anim == 144, "ClassicAPI animations follow the Hz (" .. tostring(anim) .. ")")
  -- not kept: 15 s later it goes back by itself
  now = now + PF.KEEPSECS + 1
  _G.this = PF.keepBox
  PF.keepBox:GetScript("OnUpdate")()
  ok(cv.gxRefresh == "60" and cv.gxVSync == "1" and restarts == 2 and not PF.keepOld, "not kept in 15 s: 60 Hz and vsync back")
  -- kept
  PF.SetDisplay(120, true, false)
  PF.KeepGx()
  now = now + 30
  ok(cv.gxRefresh == "120" and not PF.keepOld, "kept: stays at 120 Hz")
  ok(PF.SetDisplay(120, true, false) == false, "the same again: nothing done")
  -- not in a fight
  _G.UnitAffectingCombat = function() return true end
  ok(not PF.SetDisplay(60, true, false) and cv.gxRefresh == "120", "in a fight: graphics left alone")
  _G.UnitAffectingCombat = function() return false end
  -- the frame cap DXVK gets
  S.vrr = "0"
  ok(PF.CapLines(144).steam == "DXVK_FRAME_RATE=144 %command%", "frame cap = the Hz")
  S.vrr = "1"
  ok(PF.CapLines(144).conf == "d3d9.maxFrameRate = 141", "G-Sync / FreeSync: 3 under")
  S.vrr = "0"

  -- Linux on: its CVars set (own values kept), effects in dungeons too; off: all back
  pfUI_cache.perflinux = nil
  S.raidfx, S.raidfxwhere, S.linux = "1", "raid", "1"
  PF.ApplyLinux()
  ok(cv.gxFixLag == "0" and cv.gxCursor == "1" and S.raidfxwhere == "group" and S.gccap == "1", "Linux on: gxFixLag 0, hardware pointer, dungeons too")
  PF.KeepGx()
  S.linux = "0"
  PF.ApplyLinux()
  PF.KeepGx()
  ok(cv.gxFixLag == "1" and cv.gxCursor == "0" and S.raidfxwhere == "raid", "Linux off: your own values back")
  -- an unticked part is left alone
  S.linux, S.lxcursor = "1", "0"
  PF.ApplyLinux()
  PF.KeepGx()
  ok(cv.gxFixLag == "0" and cv.gxCursor == "0", "Linux on without the pointer part: pointer left alone")
  S.linux, S.lxcursor = "0", "1"
  PF.ApplyLinux()
  PF.KeepGx()

  -- PerfBoost looks
  ok(PF.HasPB(), "PerfBoost seen from its CVars")
  PF.SetPBLook("raid")
  ok(cv.PB_Enabled == "1" and cv.PB_PlayerRenderDistInCombat == "30" and PF.PBLook() == "raid", "PerfBoost: Most FPS in raids set and recognised")
  PF.SetPBLook("all")
  ok(cv.PB_PlayerRenderDist == "-1" and PF.PBLook() == "all", "PerfBoost: Show everything")
  cv.PB_Enabled = nil
  ok(not PF.HasPB(), "no PerfBoost CVars: not installed")
  local dl = PF.DLLs()
  ok(table.getn(dl) == 5, "the DLL list has 5 entries")

  -- the page builds with and without PerfBoost
  if O and O.BUILD and O.BUILD.stperf then
    local okb, err = pcall(function() O:Page("stperf") O:Rebuild("stperf") end)
    ok(okb, "Performance page builds without PerfBoost: " .. tostring(err))
    cv.PB_Enabled = "1"
    okb, err = pcall(function() O:Rebuild("stperf") end)
    ok(okb, "Performance page builds with PerfBoost: " .. tostring(err))
  end
  if PF.keepBox then PF.keepBox:Hide() end
  PF.keepOld = nil
  pfUI_cache.perflinux = nil
  _G.RestartGx, _G.GetRefreshRates, _G.SetMaxAnimFramerate = keepRG, keepRR, keepAnim
end

-- (20 Nov 2026) nampower's settings page
local NP = pfUI.nampowerOptions
ok(NP and O and O.BUILD and O.BUILD.stnampower, "Settings > nampower registered")
if NP then
  local cv = {}
  _G.GetCVar = function(n) if cv[n] == nil then error("no such cvar") end return cv[n] end
  _G.SetCVar = function(n, v) if cv[n] == nil then error("no such cvar") end cv[n] = tostring(v) end
  ok(not NP.Loaded(), "no NP_ CVars: nampower not loaded")
  local okb, err = pcall(function() O:Page("stnampower") O:Rebuild("stnampower") end)
  ok(okb, "nampower page builds without nampower: " .. tostring(err))
  -- every setting on the page is one the DLL has, at its default
  local n = 0
  for _, c in ipairs(NP.CARDS) do for _, s in ipairs(c[4]) do cv["NP_" .. s[1]] = s[4] n = n + 1 end end
  ok(n >= 30 and NP.Loaded() and NP.Changed() == 0, "nampower loaded, " .. n .. " settings at their defaults")
  okb, err = pcall(function() O:Rebuild("stnampower") end)
  ok(okb, "nampower page builds with nampower: " .. tostring(err))
  NP.Set("SpellQueueWindowMs", 300)
  NP.Set("QueueOnSwingSpells", "1")
  ok(cv.NP_SpellQueueWindowMs == "300" and NP.Changed() == 2, "two changed (queue window 300 ms, on-swing queue on)")
  NP.Defaults()
  ok(cv.NP_SpellQueueWindowMs == "500" and cv.NP_QueueOnSwingSpells == "0" and NP.Changed() == 0, "back to nampower's defaults")
  -- the names are real: every one is in the DLL's strings (checked 20 Nov 2026 against nampower.dll)
  local real = { QueueCastTimeSpells = 1, QueueInstantSpells = 1, QueueChannelingSpells = 1, QueueTargetingSpells = 1, QueueOnSwingSpells = 1,
    QueueSpellsOnCooldown = 1, SpellQueueWindowMs = 1, CooldownQueueWindowMs = 1, TargetingQueueWindowMs = 1, OnSwingBufferCooldownMs = 1,
    ChannelQueueWindowMs = 1, ChannelLatencyReductionPercentage = 1, InterruptChannelsOutsideQueueWindow = 1, DoubleCastToEndChannelEarly = 1,
    QuickcastTargetingSpells = 1, QuickcastOnDoubleCast = 1, PreventRightClickTargetChange = 1, PreventRightClickPvPAttack = 1,
    PreventMountingWhenBuffCapped = 1, SpamProtectionEnabled = 1, RetryServerRejectedSpells = 1, ChatBubbleDistance = 1, ChatBubblesWhisper = 1,
    ChatBubblesRaid = 1, ChatBubblesBattleground = 1, EnableEnhancedTooltips = 1, EnableLocalSetRaidTarget = 1, PreserveGreaterDemonAutocast = 1,
    MinBufferTimeMs = 1, NonGcdBufferTimeMs = 1, MaxBufferIncreaseMs = 1, OptimizeBufferUsingPacketTimings = 1, ReplaceMatchingNonGcdCategory = 1,
    EnableUnitEventsGuid = 1, EnableUnitEventsGuidFiltering = 1 }
  local bad = {}
  for _, c in ipairs(NP.CARDS) do for _, s in ipairs(c[4]) do if not real[s[1]] then table.insert(bad, s[1]) end end end
  ok(table.getn(bad) == 0, "every nampower setting name is one the DLL has (" .. table.concat(bad, ", ") .. ")")
end

for k, v in pairs(keep) do rawset(_G, k, v) end
pfUI_cache.perfsaved = nil
