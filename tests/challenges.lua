-- pfUI Octo: the game's target frame challenges cache (modules/escapefix.lua E.ChallengesCache), run by tests\run.lua
-- (20 Nov 2026, Iso: TargetFrame.lua:291 "attempt to index global `Turtle_ChallengesCache' (a nil value)")
local ok = octo_ok
local E = pfUI.escapefix
ok(E and E.ChallengesCache, "challenges cache guard loaded")
if not (E and E.ChallengesCache) then return end
local keep = rawget(_G, "Turtle_ChallengesCache")
local keepRealm = rawget(_G, "GetRealmName")
_G.GetRealmName = function() return "TestRealm" end
_G.Turtle_ChallengesCache = nil
E.ChallengesCache()
ok(type(Turtle_ChallengesCache) == "table" and type(Turtle_ChallengesCache.TestRealm) == "table", "missing table made, with this realm's part")
Turtle_ChallengesCache.TestRealm["0x1"] = 5
E.ChallengesCache()
ok(Turtle_ChallengesCache.TestRealm["0x1"] == 5, "an existing table is kept as it is")
-- the game's function, wrapped the way the module does it: no error without the saved table
local function GameCheck(unit) return Turtle_ChallengesCache[GetRealmName()][unit] end
_G.Turtle_ChallengesCache = nil
local wrapped = function(a) E.ChallengesCache() return GameCheck(a) end
ok(pcall(wrapped, "0x2"), "the game's challenge lookup runs without the saved table")
_G.Turtle_ChallengesCache = keep
_G.GetRealmName = keepRealm
