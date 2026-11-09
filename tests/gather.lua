-- pfUI Octo: gathering finder (modules/gather.lua, gather-options.lua), run by tests\run.lua.
-- A made-up ClassicAPI object finder: which nodes are asked for, the rules,
-- distances, swapped axes, the arrow's turn and the priority ping.
local ok = octo_ok
local GF = pfUI.gather
ok(GF and GF.Scan and GF.Wanted and GF.State, "gather loaded (pfUI.gather)")
if not GF then return end
local S = pfUI_config.gather
ok(S and S.enable == "0" and S.rows == "3" and S.skill == "1", "gather defaults (off, 3 rows, skill filter on)")
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.gather, "options page Gathering registered")
-- modules run in pfUI.env: a bare SLASH_X = "/x" stays there and the game never sees it
local genv = pfUI.env and rawget(pfUI.env, "_G") or _G
ok(rawget(genv, "SLASH_PFGATHER1") == "/gather" and rawget(genv, "SLASH_PFAUTOLOOT1") == "/autoloot",
  "module slash commands are real globals (/gather, /autoloot)")

local saved = { ClosestGameObjectPosition = rawget(_G, "ClosestGameObjectPosition"), UnitPosition = rawget(_G, "UnitPosition"),
  GetPlayerFacing = rawget(_G, "GetPlayerFacing"), GetNumSkillLines = rawget(_G, "GetNumSkillLines"),
  GetSkillLineInfo = rawget(_G, "GetSkillLineInfo"), PlaySoundFile = rawget(_G, "PlaySoundFile") }
local objects = {}      -- id -> { x, y, z }
local px, py, facing = 100, 200, 0
local skills = { { "Herbalism", 150 } }
local sounds = 0
_G.ClosestGameObjectPosition = function(id) local o = objects[id] if o then return o[1], o[2], o[3] end end
_G.UnitPosition = function() return px, py, 0 end
_G.GetPlayerFacing = function() return facing end
_G.GetNumSkillLines = function() return table.getn(skills) end
_G.GetSkillLineInfo = function(i) return skills[i][1], nil, nil, skills[i][2] end
_G.PlaySoundFile = function() sounds = sounds + 1 end
local function fresh() GF.ResetSkills() GF.seen = {} GF.swap = nil end

S.nodes, S.extra, S.herbs, S.ore, S.skill = "", "", "1", "1", "1"
fresh()
ok(GF.Available(), "the object finder is found")

-- what is asked for
local function asked(name)
  local l = GF.Wanted(1000)
  for i = 1, table.getn(l) do if l[i].name == name then return true end end
  return false
end
ok(asked("Peacebloom") and asked("Liferoot"), "herbs within your skill are asked for")
ok(not asked("Fadeleaf") and not asked("Black Lotus"), "herbs above your skill are not")
ok(not asked("Copper Vein"), "no Mining skill: no ore")
S.skill = "0" GF.ResetSkills()
ok(asked("Black Lotus") and asked("Copper Vein"), "skill filter off: everything")
S.ore = "0"
ok(not asked("Copper Vein"), "ore switched off")
S.ore, S.skill = "1", "1"

-- the rules string
ok(GF.State("Black Lotus") == "prio" and GF.State("Peacebloom") == "show", "default states")
GF.SetState("Peacebloom", "off")
ok(GF.State("Peacebloom") == "off" and S.nodes == "Peacebloom=off;", "a change is saved as Name=state;")
GF.SetState("Silverleaf", "prio")
ok(GF.State("Silverleaf") == "prio" and GF.State("Peacebloom") == "off", "two changes kept")
GF.SetState("Peacebloom", "show")
ok(S.nodes == "Silverleaf=prio;", "back to the default drops it")
GF.ResetSkills()
ok(not asked("Peacebloom") or GF.State("Peacebloom") == "show", "Off nodes are not asked for")
GF.SetState("Silverleaf", "show")

-- extra IDs
S.extra = "999001=Odd Chest, 999002"
local ex = GF.Extra()
ok(table.getn(ex) == 2 and ex[1].id == 999001 and ex[1].name == "Odd Chest" and ex[2].name == nil, "extra IDs read with optional names")
S.extra = ""

-- distances and the sort: Peacebloom 30 yd north, Liferoot (priority) 60 yd, a node far out of view
fresh()
GF.SetState("Liferoot", "prio")
objects = { [1618] = { 130, 200, 0 }, [2041] = { 100, 260, 0 }, [1619] = { 900, 900, 0 } }
sounds = 0
S.alert, S.sound = "1", "1"
local f = GF.Scan(1000)
ok(table.getn(f) == 2, "two nodes in sight, the far one left out")
ok(f[1].name == "Liferoot" and f[2].name == "Peacebloom", "priority first, then nearest")
ok(math.abs(f[2].dist - 30) < .01, "distance in yards")
ok(sounds == 1 and GF.lastAlert == "Liferoot", "a priority node coming into sight pings once")
GF.Scan(1001)
ok(sounds == 1, "...and not again while it stays")
objects[2041] = nil GF.Scan(1002) objects[2041] = { 100, 260, 0 } GF.Scan(1003)
ok(sounds == 2, "gone and back: it pings again")
GF.SetState("Liferoot", "show")

-- the arrow: facing north (0), a node straight north turns 0; facing west (pi/2) it turns -pi/2
GF.axis = 1
fresh()
objects = { [1618] = { 130, 200, 0 } }
facing = 0
f = GF.Scan(1100)
ok(f[1] and math.abs(f[1].turn) < .01, "node ahead: no turn")
facing = math.pi / 2
f = GF.Scan(1101)
ok(f[1] and math.abs(f[1].turn + math.pi / 2) < .01, "facing west, node north: turn right a quarter")

-- swapped axes: the finder answers y, x
fresh()
_G.ClosestGameObjectPosition = function(id) local o = objects[id] if o then return o[2], o[1], o[3] end end
objects = { [1618] = { 4130, 200, 0 } }
px, py = 4100, 200
f = GF.Scan(1200)
ok(GF.swap == true and f[1] and math.abs(f[1].dist - 30) < .01, "x / y given the other way round are swapped")
_G.ClosestGameObjectPosition = function(id) local o = objects[id] if o then return o[1], o[2], o[3] end end

-- the real client (/gather probe, 9 Nov 2026): you at -4204.57, 1080.39, z 10.22;
-- Peacebloom answered 1080.12, -4207.17, 16.17 - y, x and a DISTANCE, not a height
fresh()
local realUP = _G.UnitPosition
_G.UnitPosition = function() return -4204.57, 1080.39, 10.22 end
_G.ClosestGameObjectPosition = function(id) if id == 1618 then return 1080.12, -4207.17, 16.17 end end
f = GF.Scan(1250)
ok(GF.swap == true and f[1] and math.abs(f[1].dist - 2.61) < .05, "probe numbers: the Peacebloom at your feet is 3 yd, not 13+")
_G.UnitPosition = realUP
_G.ClosestGameObjectPosition = function(id) local o = objects[id] if o then return o[1], o[2], o[3] end end

-- learning north from walking: positions laid out (y, x) -> axis 2
GF.votes, GF.axis = { 0, 0, 0, 0 }, 1
facing = 0
local x, y = 0, 0
GF.Learn(x, y, facing)
for i = 1, 6 do y = y + 3 GF.Learn(x, y, facing) end
ok(GF.axis == 2, "walking north along y teaches the axis order")
GF.votes, GF.axis = { 0, 0, 0, 0 }, 1

-- learning a zone's own copy of a node from the tooltip
S.learned = ""
ok(GF.IdFrom(3726) == 3726 and GF.IdFrom("0xF1100E8C0000A1B2") == 0x0E8C00 and GF.IdFrom("abc") == nil, "IDs read from a number or a GUID")
ok(GF.Teach("Earthroot", 1619) == nil and S.learned == "", "a known ID is not saved again")
ok(GF.Teach("Not A Herb", 555555) == nil, "only node names are learned")
ok(GF.Teach("Earthroot", nil, 555555) == 555555 and S.learned == "555555=Earthroot;", "a new ID for a node is saved")
S.skill = "0" GF.ResetSkills()
ok(asked("Earthroot") and (function()
  local l = GF.Wanted(1000)
  for i = 1, table.getn(l) do if l[i].id == 555555 then return true end end
end)(), "a learned ID is looked for")
S.skill, S.learned = "1", ""

-- following: the distance and arrow move every frame between looks
fresh()
S.enable = "1"
objects = { [1618] = { 130, 200, 0 } }
px, py, facing = 100, 200, 0
GF.Scan(1400) GF.Draw()
ok(GF.frame.rows[1]:IsShown() and math.abs(GF.found[1].dist - 30) < .01, "drawn at 30 yd")
px = 120 GF.Follow()
ok(math.abs(GF.found[1].dist - 10) < .01 and GF.frame.rows[1].dist:GetText() == "10 yd", "walking closer updates the yards at once")
facing = math.pi / 2 GF.Follow()
ok(math.abs(GF.found[1].turn + math.pi / 2) < .01, "turning updates the arrow at once")
S.enable = "0"

-- without ClassicAPI: nothing, no error
_G.ClosestGameObjectPosition = nil
ok(not GF.Available() and table.getn(GF.Scan(1300)) == 0, "no ClassicAPI: finds nothing, no error")

-- the box draws a sample
S.enable = "1"
GF.Preview(true)
ok(GF.frame and GF.frame:IsShown() and GF.frame.rows[1]:IsShown() and not GF.frame.rows[4]:IsShown(), "sample: three rows shown")
GF.Preview(false)
S.enable = "0"
GF.Tick(5000)
ok(not GF.frame:IsShown(), "switched off: the box hides")

-- pfQuest's lists (with the Turtle / OctoWoW add-on merged in)
_G.ClosestGameObjectPosition = function(id) local o = objects[id] if o then return o[1], o[2], o[3] end end
local savedDB = rawget(_G, "pfDB")
_G.pfDB = { meta = { herbs = { [-3726] = 15, [-990001] = 40 }, mines = { [-3000500] = 90 }, fish = { [-180750] = "AH" }, chests = { [-3000248] = 0 } },
  objects = { loc = { [3726] = "Earthroot", [990001] = "Odd Herb", [180750] = "Oily School" }, ["enUS-turtle"] = { [3000500] = "Octo Vein", [3000248] = "Octo Chest" } } }
GF.dbLoaded = nil
local before = table.getn(GF.BYNAME["Earthroot"][4])
GF.LoadDB()
ok(GF.BYNAME["Odd Herb"] and GF.BYNAME["Odd Herb"][2] == GF.HERB and GF.BYNAME["Odd Herb"][3] == 40, "a pfQuest herb is added with its skill")
ok(table.getn(GF.BYNAME["Earthroot"][4]) == before, "an ID already in the list is not added twice")
ok(GF.BYNAME["Octo Vein"] and GF.BYNAME["Octo Vein"][2] == GF.ORE, "OctoWoW's own veins come from the Turtle add-on's names")
ok(GF.BYNAME["Oily School"] and GF.BYNAME["Oily School"][2] == GF.FISH and GF.BYNAME["Octo Chest"][2] == GF.CHEST, "fishing pools and chests too")
_G.pfDB = savedDB

-- batches: 3 nodes, 2 calls a look
fresh()
S.skill, S.chests = "0", "0"
GF.BATCH = 2
GF.wantKey = nil
objects = { [1618] = { 110, 200, 0 }, [1617] = { 120, 200, 0 }, [1619] = { 130, 200, 0 } }
px, py = 100, 200
local list = GF.WantedCached(2000)
local calls = 0
_G.ClosestGameObjectPosition = function(id) calls = calls + 1 local o = objects[id] if o then return o[1], o[2], o[3] end end
GF.Scan(2000)
ok(calls == 2, "one look asks only a batch")
for i = 1, math.ceil(table.getn(list) / 2) do GF.Scan(2000 + i) end
ok(table.getn(GF.found) == 3, "after a full round every node is found")
GF.BATCH = 80
S.skill = "1"

for k, v in pairs(saved) do _G[k] = v end
S.nodes, S.extra = "", ""
