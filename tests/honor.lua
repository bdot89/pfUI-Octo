-- pfUI Octo: honor records and the Honor page (modules/honor.lua, honor-options.lua), run by tests\run.lua.
local ok = octo_ok
local HN = pfUI.honor
ok(HN and HN.Add and HN.Rate and HN.BuildPage and HN.Import, "honor loaded (pfUI.honor)")
if not HN then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.honor, "options page Honor registered")
local good, err = pcall(function() O:Page("honor") end)
ok(good, "the Honor options page builds" .. (good and "" or (": " .. tostring(err))))
local S = pfUI_config.honor
ok(S and S.page == "1" and S.cap == "20000" and S.barcolor == "faction", "defaults (C.honor)")
ok(rawget(_G, "SLASH_PFHONOR1") == "/honor", "/honor")

-- numbers and the week
ok(HN.Fmt(54013) == "54 013" and HN.Fmt(999) == "999" and HN.Fmt(1234567) == "1 234 567", "numbers grouped as the game does")
-- Wednesday 25 Nov 2026 00:00 UTC = 1795564800 (a week start: 518400 + n * 604800)
ok(math.mod(1795564800 - 518400, 604800) == 0, "test date is a Wednesday")
ok(HN.WeekStart(1795564800 + 3600) == 1795564800 and HN.ResetIn(1795564800 + 3600) == 604800 - 3600, "the week starts Wednesday 00:00 UTC")
ok(HN.Span(2 * 86400 + 5 * 3600 + 60) == "2d 5h" and HN.Span(3700) == "1h 1m" and HN.Span(59) == "0m", "countdown text")

-- the server's lines
local v, r, n = HN.ParseKill("Regalius dies, honorable kill Rank: Knight-Captain  (Estimated Honor Points: 12)")
ok(v == "Regalius" and r == "Knight-Captain" and n == 12, "an honorable kill line")
ok(HN.ParseAward("You have been awarded 25 honor points.") == 25 and HN.ParseAward("You gain 8 honor") == 8, "award lines")
ok(HN.ParseResult("The Horde wins!", "Horde") == 1 and HN.ParseResult("The Alliance wins!", "Horde") == 0, "battleground won / lost")
ok(HN.ParseResult("The Alliance has taken the stables!", "Horde") == nil, "other battleground lines are not results")

-- a made-up character: records, rate, days
local keep = {}
for _, k in ipairs({ "UnitPVPRank", "GetPVPRankProgress", "GetPVPRankInfo", "GetPVPThisWeekStats", "GetPVPSessionStats",
  "GetPVPYesterdayStats", "GetPVPLastWeekStats", "GetPVPLifetimeStats", "time", "UnitName", "GetRealmName", "UnitFactionGroup",
  "HonorSpyDB", "GetRealZoneText", "date" }) do keep[k] = rawget(_G, k) end
_G.date = os.date
local wall, rank, pct = 1795564800 + 2 * 86400 + 12 * 3600, 13, .50
_G.time = function(t) if t then return keep.time(t) end return wall end
_G.UnitPVPRank = function() return rank end
_G.GetPVPRankProgress = function() return pct end
local NAMES = { [12] = "Knight", [13] = "Lieutenant General", [14] = "General" }
_G.GetPVPRankInfo = function(i) if NAMES[i] then return NAMES[i], i - 4 end end
_G.GetPVPThisWeekStats = function() return 30, 4000 end
_G.GetPVPSessionStats = function() return 5, 0 end
_G.GetPVPYesterdayStats = function() return 10, 0, 300 end
_G.GetPVPLastWeekStats = function() return 500, 0, 9576, 0 end
_G.GetPVPLifetimeStats = function() return 6777, 3, 13 end
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "TestRealm" end
_G.UnitFactionGroup = function() return "Horde" end
_G.GetRealZoneText = function() return "Arathi Basin" end
local cacheWas = pfUI_cache.honor
pfUI_cache.honor = nil
local s = HN.Store()
ok(s and s.log and HN.Key() == "TestRealm^Tester", "per character records")
-- 40 honor a step at rank 13: every 40 honor of kills the % moves one step
local p = .50
for i = 1, 12 do
  HN.Add({ k = "kill", h = 20, n = "A" .. i, t = wall - 3600 + i * 10, r = 13, p = p })
  HN.Add({ k = "kill", h = 20, n = "B" .. i, t = wall - 3600 + i * 10 + 1, r = 13, p = p })
  p = p + 1 / 255
  HN.Add({ k = "tick", h = 0, t = wall - 3600 + i * 10 + 2, r = 13, p = p })
end
local rate, steps = HN.Rate(13)
ok(rate and math.abs(rate - 40) < .01 and steps == 12, "honor a step learnt from the records (" .. tostring(rate) .. ")")
ok(HN.Rate(14) == nil, "no rate for a rank with no records")
pct = .5
local need, nextName = HN.ToNext()
ok(need and math.abs(need - .5 * 255 * 40) < .5 and nextName == "General", "honor to the next rank (" .. tostring(need) .. ")")
HN.Add({ k = "bg", w = 1, h = 0, t = wall - 100, r = 13, p = p })
HN.Add({ k = "award", h = 50, bg = 1, t = wall - 90, r = 13, p = p })
HN.Add({ k = "kill", h = 7, t = wall - 86400, r = 13, p = .45 })
local days = HN.Days(7)
local d1 = days[1] or {}
ok(table.getn(days) == 2 and d1.honor == 480 + 50 and d1.kills == 24 and d1.won == 1 and d1.bgh == 50,
  "today's line: honor, kills, battleground won, honor from battlegrounds (" .. table.getn(days) .. " days, "
  .. tostring(d1.d) .. " " .. tostring(d1.honor) .. " " .. tostring(d1.kills) .. " " .. tostring(d1.won) .. " " .. tostring(d1.bgh) .. ")")
ok(days[2] and days[2].honor == 7, "yesterday's line")
ok(math.abs(days[1].gain - 12 / 255 * 100) < .01, "rank % gained that day")
-- old records go
HN.Add({ k = "kill", h = 1, t = wall - 200 * 86400 })
local before = table.getn(s.log)
HN.Prune(s)
ok(table.getn(HN.Store().log) <= before and HN.Store().log[1].t > wall - 61 * 86400, "records older than 60 days are dropped")

-- HonorSpy's records come over once
_G.HonorSpyDB = { realms = { ["TestRealm - Horde"] = { hs = {
  honorHistory = {
    { type = "kill", t = wall - 5000, amount = 3, victim = "Old", victimRank = "Knight", zone = "Arathi Basin", rankNum = 13, rankPct = .4 },
    { type = "bgresult", t = wall - 4000, result = "loss", zone = "Warsong Gulch", amount = 0 },
    { type = "bgexit", t = wall - 3990, amount = 0 },
  },
  weekApiHonor = { ["1794960000"] = 20000 },
} } } }
local got = HN.Import()
ok(got == 2 and HN.Store().imported, "HonorSpy's kills and results copied (not its exits)")
ok(HN.Import() == 0, "only once")
ok(HN.Store().weeks[1794960000] == 20000, "its weekly honor too")
local sorted = true
for i = 2, table.getn(HN.Store().log) do if HN.Store().log[i].t < HN.Store().log[i - 1].t then sorted = false end end
ok(sorted, "records stay in time order")

-- the page, on a stand-in Honor tab
local hf = CreateFrame("Frame", nil, UIParent)
hf:SetWidth(384) hf:SetHeight(512)
local built, berr = pcall(HN.BuildPage, hf)
ok(built and HN.page, "the Honor page builds" .. (built and "" or (": " .. tostring(berr))))
if built then
  HN.page:Show()
  local painted, perr = pcall(HN.Paint)
  ok(painted, "the Honor page paints" .. (painted and "" or (": " .. tostring(perr))))
  ok(HN.page.rank:GetText() == "Lieutenant General", "rank name on the page")
  ok(HN.page.pct:GetText() == "50.00%", "rank % on the bar's heading line")
  ok(string.find(HN.page.week.text:GetText() or "", "4 000 / 20 000", 1, true), "the week against the cap")
  local tn = HN.page.toNext:GetText() or ""
  ok(string.find(tn, "honor to", 1, true) and string.find(tn, "General", 1, true), "honor to the next rank under the bar (" .. tn .. ")")
  ok(table.getn(HN.page.bar.marks) == 7, "the 0-100 bar has its eighth marks")
  S.art = "0"
  HN.Look()
  ok(not HN.page.scene:IsShown(), "battle art can be switched off")
  S.art = "1"
  HN.page:Hide()
end
HN.page = nil

-- the page measures itself by its edges (in game GetWidth of an anchored frame came back too small)
do
  local f = CreateFrame("Frame", nil, UIParent)
  f.GetLeft = function() return 100 end
  f.GetRight = function() return 428 end
  f.GetWidth = function() return 220 end
  ok(HN.Wid(f, 1) == 328, "width read from the frame's edges, not GetWidth")
  f.GetLeft = function() return nil end
  ok(HN.Wid(f, 1) == 220, "GetWidth when the edges are not known yet")
end

-- the character window in the same look (modules/charframe.lua)
local CF = pfUI.charframe
ok(CF and CF.Dress and CF.Paint and CF.Glows, "character window look loaded (pfUI.charframe)")
ok(pfUI_config.charframe and pfUI_config.charframe.enable == "1" and pfUI_config.charframe.glow == "1", "defaults (C.charframe)")
if CF and _G.CharacterFrame then
  if not CharacterFrame.backdrop then CreateBackdrop(CharacterFrame) end
  local dressed, derr = pcall(CF.Dress)
  ok(dressed and CF.worn and CF.worn.grime, "the character window gets its worn look" .. (dressed and "" or (": " .. tostring(derr))))
  local painted, perr = pcall(CF.Paint)
  ok(painted, "and paints" .. (painted and "" or (": " .. tostring(perr))))
  pfUI_config.charframe.enable = "0"
  pcall(CF.Paint)
  ok(CF.worn and not CF.worn.grime:IsShown(), "switched off: the plain window")
  pfUI_config.charframe.enable = "1"
end

for k, v in pairs(keep) do rawset(_G, k, v) end
pfUI_cache.honor = cacheWas
