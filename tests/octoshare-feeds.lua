-- pfUI Octo: OctoShare phase-2 producers (modules/octoshare-feeds.lua, 27 Nov 2026), run by tests\run.lua.
local ok = octo_ok
local OS = pfUI.octoshare
local F = OS and OS.feeds
ok(F and F.CheckQueues and F.CheckResult and F.Ping, "OctoShare feeds loaded (pfUI.octoshare.feeds)")
if not F then return end

pfUI_config.octoshare = pfUI_config.octoshare or {}
local S = pfUI_config.octoshare
local keep = {}
for _, k in ipairs({ "GetBattlefieldStatus", "GetBattlefieldTimeWaited", "GetBattlefieldWinner", "GetRealZoneText",
  "UnitFactionGroup", "GetTime" }) do keep[k] = rawget(_G, k) end
local emitted = {}
local realEmit = OS.Emit
OS.Emit = function(kind, payload) table.insert(emitted, kind .. "^" .. (payload or "")) end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetRealZoneText = function() return "Alterac Valley" end

-- off: the producers stay silent even if called
S.enable = "0"
emitted = {}
-- OS.Emit is stubbed so it records regardless, but the producers gate on nothing themselves; the real OS.Emit gates on
-- enable. Restore the real one briefly to prove the gate, then re-stub.
OS.Emit = realEmit
OS.q, OS.qn = {}, 0
F.status = {}
_G.GetBattlefieldStatus = function(i) if i == 1 then return "confirm", "Alterac Valley" end return "none" end
_G.GetBattlefieldTimeWaited = function(i) return 92000 end
F.CheckQueues()
ok(OS.qn == 0, "new feeds off: a queue pop sends nothing")
OS.Emit = function(kind, payload) table.insert(emitted, kind .. "^" .. (payload or "")) end
S.enable = "1"

-- BG queue pop: emitted once, on the change into "confirm"
emitted = {}
F.status = {}
F.CheckQueues()
F.CheckQueues()
ok(table.getn(emitted) == 1 and emitted[1] == "bgq^Alterac Valley^Alliance^92", "a queue pop emits the wait once (" .. tostring(emitted[1]) .. ")")

-- BG result: Alliance winner (1) + Alliance player = a win, once per match
emitted = {}
F.reported = nil
_G.GetBattlefieldWinner = function() return 1 end
F.CheckResult()
F.CheckResult()
ok(table.getn(emitted) == 1 and emitted[1] == "bgr^Alterac Valley^Alliance^1", "a win is reported once (" .. tostring(emitted[1]) .. ")")
emitted = {}
_G.GetBattlefieldWinner = function() return 0 end   -- Horde won
F.reported = nil
F.CheckResult()
ok(emitted[1] == "bgr^Alterac Valley^Alliance^0", "a loss is reported (" .. tostring(emitted[1]) .. ")")

-- population ping
emitted = {}
F.Ping()
ok(emitted[1] == "pop^Alterac Valley^Alliance", "a population ping has the zone and faction (" .. tostring(emitted[1]) .. ")")

OS.Emit = realEmit

-- (28 Nov 2026) players seen nearby: the compact line, one sighting per name per 5 min, only players, never yourself
for _, k in ipairs({ "UnitExists", "UnitIsPlayer", "UnitIsUnit", "UnitName", "UnitLevel", "UnitClass", "UnitRace",
  "GetGuildInfo", "SUPERWOW_VERSION", "GetNampowerVersion", "C_UnitAuras", "C_NamePlate" }) do keep[k] = rawget(_G, k) end
ok(F.SightingsLine("Orgrimmar", { { "Akuula", 60, 5, 8, "HYDRA" }, { "Bob", 12, 1, 2, "" }, { "Cee", 60, 9, 6, "HYDRA" } })
  == "Orgrimmar^HYDRA^Akuula.60.5.8.1,Bob.12.1.2.0,Cee.60.9.6.1", "sightings line: zone, guild table, compact rows")
local clock = 1000
_G.GetTime = function() return clock end
local units = { target = { "Akuula", 60, "PRIEST", "Troll", "HYDRA", true }, mouseover = { "Wolf", 50, "WARRIOR", "Human", "", false },
  party1 = { "Zed", -1, "ROGUE", "Scourge", "", true } }
_G.UnitExists = function(u) return units[u] ~= nil end
_G.UnitIsPlayer = function(u) return units[u] and units[u][6] end
_G.UnitIsUnit = function() return false end
_G.UnitName = function(u) return units[u] and units[u][1], "Y'Shaarj" end   -- ClassicAPI gives the realm as well
_G.UnitLevel = function(u) return units[u] and units[u][2] end
_G.UnitClass = function(u) return "x", units[u] and units[u][3] end
_G.UnitRace = function(u) return "x", units[u] and units[u][4] end
_G.GetGuildInfo = function(u) return units[u] and units[u][5], "Member", 3 end
F.seen, F.sg, F.sgAt = {}, {}, nil
F.Sight("target") F.Sight("mouseover") F.Sight("party1") F.Sight("nobody")
ok(table.getn(F.sg) == 2, "only players are recorded (an NPC under the mouse is not): " .. table.getn(F.sg))
ok(F.sg[1][1] == "Akuula" and F.sg[1][3] == 5 and F.sg[1][4] == 8 and F.sg[1][5] == "HYDRA", "class / race codes and guild")
ok(F.sg[2][2] == 0, "an unknown (skull) level is sent as 0")
F.Sight("target")
ok(table.getn(F.sg) == 2, "the same name is not recorded again within 5 minutes")
clock = clock + F.SEEN_AGAIN + 1
F.Sight("target")
ok(table.getn(F.sg) == 3, "...but is after 5 minutes")
local sent = {}
local realBot = OS.EmitBot
OS.EmitBot = function(kind, payload) table.insert(sent, kind .. "^" .. payload) end
F.FlushSightings()
ok(table.getn(F.sg) == 0 and sent[1] and string.find(sent[1], "^sg%^Alterac Valley%^HYDRA%^Akuula%.60%.5%.8%.1,Zed%.0%.4%.5%.0") ~= nil,
  "the batch goes to the realm bot as one line (" .. tostring(sent[1]) .. ")")

-- (28 Nov 2026) the scanner's DLLs find players with no addon on their side
units["0xA1"] = { "Plater", 58, "MAGE", "Gnome", "", true }
units["0xA2"] = { "Caster", 60, "SHAMAN", "Orc", "Rift", true }
units["0xB1"] = { "Boar", 10, "WARRIOR", "Human", "", false }
units["nameplate2"] = { "Tokened", 33, "HUNTER", "Dwarf", "", true }
F.seen, F.seenG, F.sg, F.sgAt = {}, {}, {}, nil
_G.SUPERWOW_VERSION = "1.5"
_G.C_NamePlate = { GetNamePlateGUIDs = function() return { "0xA1", "0xB1" } end }
F.ScanPlates()
ok(table.getn(F.sg) == 1 and F.sg[1][1] == "Plater", "SuperWoW + ClassicAPI: every plate GUID is read, NPCs left out")
F.SightGUID("0xA2") F.SightGUID("0xA2") F.SightGUID("0x0000000000000000") F.SightGUID(nil)
ok(table.getn(F.sg) == 2 and F.sg[2][5] == "Rift", "SuperWoW cast event: the caster's GUID is read once")
local calls = 0
local realExists = _G.UnitExists
_G.UnitExists = function(u) calls = calls + 1 return realExists(u) end
F.SightGUID("0xA2")
ok(calls == 0, "a GUID seen lately costs no unit call")
_G.UnitExists = realExists
_G.SUPERWOW_VERSION = nil
F.ScanPlates()
ok(table.getn(F.sg) == 3 and F.sg[3][1] == "Tokened", "ClassicAPI alone: its nameplateN tokens are read")
sent = {}
F.FlushSightings()
ok(sent[1] and string.find(sent[1], "Plater.58.7.7.0", 1, true) and string.find(sent[1], "Tokened.33.3.3.0", 1, true),
  "plate sightings go to the bot (" .. tostring(sent[1]) .. ")")
_G.C_NamePlate = nil

-- a crowded city: a full batch goes at once, the next full one not before SG_GAP; the rest are found again later
_G.SUPERWOW_VERSION = "1.5"
F.seen, F.seenG, F.sg, F.sgAt, F.sgSent = {}, {}, {}, nil, -1000
sent = {}
for i = 1, 30 do units["0xC" .. i] = { "Crowd" .. i, 60, "MAGE", "Human", "", true } end
for i = 1, 30 do F.SightGUID("0xC" .. i) end
ok(table.getn(sent) == 1 and table.getn(F.sg) == F.SG_MAX, "30 players at once: one batch sent, one full batch waiting (" .. table.getn(sent) .. ", " .. table.getn(F.sg) .. ")")
ok(F.seenG["0xC30"] == nil and F.seen["Crowd30"] == nil, "a player left out of a full batch is not marked seen")
clock = clock + F.SG_GAP
for i = 1, 30 do F.SightGUID("0xC" .. i) end
ok(table.getn(sent) == 2 and table.getn(F.sg) == 6, "after the gap the waiting batch goes and the rest are picked up (" .. table.getn(sent) .. ", " .. table.getn(F.sg) .. ")")
_G.SUPERWOW_VERSION = nil

-- emp's ping: only the realm's own bot, only on the guild channel, at most once a minute
local realRealm = OS.RealmBot
OS.RealmBot = function() return "Errorgchat" end
F.hbAt, F.pingDue = 0, nil
F.Pinged("pfOS", "ping^1", "GUILD", "Someone")
ok(F.pingDue == nil, "a ping from anyone but the realm bot is ignored")
F.Pinged("pfOS", "ping^1", "WHISPER", "Errorgchat")
ok(F.pingDue == nil, "a ping outside the guild channel is ignored")
F.Pinged("pfOS", "ping^1", "GUILD", "Errorgchat")
ok(F.pingDue and F.pingDue >= clock + 2 and F.pingDue <= clock + 20, "the realm bot's ping is answered after 2-20 s")
F.pingDue, F.hbAt = nil, clock - 30
F.Pinged("pfOS", "ping^2", "GUILD", "Errorgchat")
ok(F.pingDue == nil, "no answer within a minute of the last heartbeat")
OS.RealmBot = realRealm

-- the DLL letters in the heartbeat
_G.SUPERWOW_VERSION, _G.GetNampowerVersion, _G.C_UnitAuras = "1.5", function() end, nil
local d = F.Dlls()
ok(string.find(d, "S", 1, true) and string.find(d, "N", 1, true) and not string.find(d, "C", 1, true), "DLL letters (" .. d .. ")")
sent = {}
F.Heartbeat("Orgrimmar")
ok(sent[1] and string.find(sent[1], "^hb%^Orgrimmar%^") and string.find(sent[1], "%^S", 1) ~= nil, "the heartbeat ends with the DLL letters (" .. tostring(sent[1]) .. ")")
OS.EmitBot = realBot

S.enable = "1"
OS.q, OS.qn = {}, 0
for k, v in pairs(keep) do _G[k] = v end
