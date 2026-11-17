-- pfUI Octo: world map marks survive a relog (17 Nov 2026, Barbeque_Squirrel: resource icons "dissapear after relog and
-- have to turn them back on"), run by tests\run.lua.
local ok = octo_ok
local L, GF = pfUI.layouts, pfUI.gather
-- UI layouts never carry the map marks
if L and L.CfgCopy and L.ApplyCfg then
  local g = pfUI_config.gather
  local keep = { g.mappins, g.pinherbs, g.pinore }
  g.mappins, g.pinherbs, g.pinore = "1", "1", "0"
  local copy = L.CfgCopy()
  ok(copy.gather and copy.gather.pinherbs == nil and copy.gather.mappins == nil, "a saved layout leaves the map marks out")
  -- an older layout that still holds them: switching to it keeps today's marks
  copy.gather.pinherbs, copy.gather.pinore = "0", "1"
  L.ApplyCfg(copy)
  ok(g.pinherbs == "1" and g.pinore == "0", "switching layout does not put old map marks back")
  g.mappins, g.pinherbs, g.pinore = keep[1], keep[2], keep[3]
else
  ok(false, "layouts / gathering loaded")
end

-- pfQuest tracking lists saved but without marks on the map are tracked again after login
if GF and GF.RestoreTracks then
  local keepDB, keepMap, keepTrack, keepPfDB = rawget(_G, "pfDatabase"), rawget(_G, "pfMap"), rawget(_G, "pfQuest_track"), rawget(_G, "pfDB")
  local calls = {}
  _G.pfDB = { meta = { mines = {}, herbs = {} } }
  _G.pfMap = { nodes = { TRACK_HERBS = { [1] = {} } }, UpdateNodes = function() calls.update = true end }
  _G.pfQuest_track = { mines = { { name = "mines", min = 50 }, { icon = "x" } }, herbs = { { name = "herbs" }, {} } }
  _G.pfDatabase = { TrackMeta = function(_, name, state) table.insert(calls, { name, state }) end }
  local n = GF.RestoreTracks()
  ok(n == 1 and calls[1] and calls[1][1] == "mines" and type(calls[1][2]) == "table" and calls[1][2].min == 50,
    "a saved list with no marks on the map is tracked again, with its own min skill")
  ok(calls.update, "the map is redrawn")
  _G.pfDatabase, _G.pfMap, _G.pfQuest_track, _G.pfDB = keepDB, keepMap, keepTrack, keepPfDB
else
  ok(false, "gathering restore loaded")
end
