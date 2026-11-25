-- pfUI Octo: OctoRanks (modules/octorank.lua + octorank\ = the OctoRank engine, tools\Sync-OctoRank.ps1), run by
-- tests\run.lua. The engine runs here as pfUI's own copy (no WhoDidIt / OctoRank add-on in the mock).
local ok = octo_ok
local OR = pfUI.octorank
ok(OR and OR.Engine and OR.MergeInto and OR.Open, "OctoRanks loaded (pfUI.octorank)")
if not OR then return end

-- the engine: OctoRank's code under its own names, so the add-on and pfUI share one save
ok(ORANK_PFUI == true and not ORANK_SKIP, "pfUI's copy runs when neither WhoDidIt nor the OctoRank add-on is loaded")
ok(type(OctoRank) == "table" and OctoRank.Runs and OctoRank.Board and OctoRank.Data and OctoRank.UI, "the engine's parts are there")
local kind = OR.Engine()
ok(kind == "pfui", "who runs it: pfUI (" .. tostring(kind) .. ")")
ok(type(OctoRankDB) == "table" and OctoRankDB.opts and OctoRankDB.opts.noMinimap == true,
  "OctoRank's own save, minimap button off by default (the sidebar opens it)")

-- the toc: the same saved variables as the add-on, WhoDidIt / OctoRank load first, the engine's load list
local f = io.open("./pfUI.toc", "r")
local toc = f and f:read("*a") or ""
if f then f:close() end
ok(string.find(toc, "OctoRankDB, OctoRankChronDB", 1, true) and string.find(toc, "OctoRankChronCharDB", 1, true),
  "pfUI.toc keeps OctoRank's saved variables (one save with the add-on)")
ok(string.find(toc, "## OptionalDeps: WhoDidIt, OctoRank", 1, true) and string.find(toc, "octorank\\octorank.xml", 1, true),
  "pfUI.toc loads WhoDidIt / OctoRank first and the engine after pfQuest")
local g = io.open("./octorank/Guard.lua", "r")
local guard = g and g:read("*a") or ""
if g then g:close() end
ok(string.find(guard, 'IsAddOnLoaded("WhoDidIt") or IsAddOnLoaded("OctoRank")', 1, true),
  "never two engines: the copy stands aside for WhoDidIt and the OctoRank add-on")

-- merging the saves (WhoDidIt on): the faster time wins, withdrawn runs stay out, history once, newest group name
local wdi = {
  dungeons = { ["Y'Shaarj"] = { strat = { ["A,B,C"] = { g = "Fast", t = 1300, d = 1790000000 }, ["D,E"] = { g = "Old", t = 2000, d = 1790000000 } } } },
  runsWithdrawn = { ["Y'Shaarj"] = { ["strat~X,Y~900"] = { k = "strat", gk = "X,Y", t = 900 } } },
  myRuns = { { k = "strat", gk = "A,B,C", t = 1300, d = 1790000500 } },
  groupNames = { ["A,B,C"] = { n = "Fast", at = 10 } },
}
local mine = {
  dungeons = { ["Y'Shaarj"] = { strat = { ["A,B,C"] = { g = "Fast", t = 1400, d = 1789000000 }, ["D,E"] = { g = "Old", t = 1500, d = 1791000000 },
    ["X,Y"] = { g = "Wrong", t = 900, d = 1791000000 } } },
    ["N'Zoth"] = { brd = { ["P,Q"] = { g = "Other realm", t = 1700, d = 1791000000 } } } },
  myRuns = { { k = "brd", gk = "P,Q", t = 1700, d = 1791000000 }, { k = "strat", gk = "A,B,C", t = 1300, d = 1790000500 } },
  groupNames = { ["A,B,C"] = { n = "Faster", at = 20 } },
}
local n = OR.MergeInto(wdi, mine)
local s = wdi.dungeons["Y'Shaarj"].strat
ok(s["A,B,C"].t == 1300 and s["D,E"].t == 1500, "the faster run of a group wins, from either save")
ok(s["X,Y"] == nil, "a run withdrawn on one side never comes back from the other")
ok(wdi.dungeons["N'Zoth"] and wdi.dungeons["N'Zoth"].brd["P,Q"].t == 1700, "the other realm's runs come along")
ok(table.getn(wdi.myRuns) == 2 and wdi.myRuns[1].k == "brd", "your run history: every run once, newest first")
ok(wdi.groupNames["A,B,C"].n == "Faster", "the newest group name wins")
ok(n > 0 and OR.MergeInto(wdi, mine) == 0, "merging again changes nothing")
local back = OR.MergeInto(mine, wdi)
ok(mine.runsWithdrawn and mine.runsWithdrawn["Y'Shaarj"]["strat~X,Y~900"] and back > 0, "the withdrawal goes the other way too")

-- the sidebar: the gold OctoRanks entry above Move Frames, its section has no row of its own
local O = pfUI.octoui and pfUI.octoui.Options
if O and O.navFrame then
  local entries = {}
  for _, k in ipairs({ O.navFrame:GetChildren() }) do
    if k.pic and k.text and string.find(k.pic.texture or "", "octo\\icons\\", 1, true) then table.insert(entries, k) end
  end
  table.sort(entries, function(a, b)
    local pa, pb = a.points and a.points[1], b.points and b.points[1]
    return (pa and pa[5] or 0) > (pb and pb[5] or 0)
  end)
  ok(entries[1] and string.find(entries[1].pic.texture, "icons\\rank", 1, true) and entries[2]
    and string.find(entries[2].pic.texture, "icons\\move", 1, true), "OctoRanks is the first big entry, above Move Frames")
  ok(O.TOPENTRY["OctoRanks"] and O.BUILD["orank"], "its page exists and opens from the big entry")
end

-- (25 Nov 2026) the run timer: waiting at the door, running against your best, done with its place
do
  local T = OR.timer
  ok(T and T.State and T.Paint and getglobal("pfOctoRankTimer"), "the run timer is there (pfOctoRankTimer, a layout mode box)")
  if T then
    local was = { IsInInstance = rawget(_G, "IsInInstance"), GetRealZoneText = rawget(_G, "GetRealZoneText"), UnitLevel = rawget(_G, "UnitLevel") }
    local R = OctoRank.Runs
    local cur, best = R.Current, R.MyBest
    _G.IsInInstance = function() return 1, "party" end
    _G.GetRealZoneText = function() return "Stratholme" end
    _G.UnitLevel = function() return 60 end
    R.Current = function() return nil end
    local s = T.State()
    ok(s and s.state == "wait", "inside a 5-man before the pull: waiting (" .. tostring(s and s.state) .. ")")
    local now = time()
    R.Current = function() return { zone = "Stratholme", at = now - 600, k = { ["Stonespine"] = 300, ["Magistrate Barthilas"] = 120 } } end
    R.MyBest = function() return { t = 900 } end
    s = T.State(now)
    ok(s and s.state == "run" and s.secs == 600 and s.n == 2 and s.splits[1][1] == "Magistrate Barthilas", "running: time, bosses down in order")
    local good, err = pcall(T.Paint, s)
    ok(good, "it draws " .. tostring(err or ""))
    R.Current, R.MyBest = cur, best
    for k, v in pairs(was) do rawset(_G, k, v) end
  end
end
