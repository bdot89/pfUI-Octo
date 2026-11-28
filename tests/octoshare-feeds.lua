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

-- (28 Nov 2026) players seen nearby: the compact line, one sighting per name per 10 min, only players, never yourself
for _, k in ipairs({ "UnitExists", "UnitIsPlayer", "UnitIsUnit", "UnitName", "UnitLevel", "UnitClass", "UnitRace",
  "GetGuildInfo", "SUPERWOW_VERSION", "GetNampowerVersion", "C_UnitAuras" }) do keep[k] = rawget(_G, k) end
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
ok(table.getn(F.sg) == 2, "the same name is not recorded again within 10 minutes")
clock = clock + F.SEEN_AGAIN + 1
F.Sight("target")
ok(table.getn(F.sg) == 3, "...but is after 10 minutes")
local sent = {}
local realBot = OS.EmitBot
OS.EmitBot = function(kind, payload) table.insert(sent, kind .. "^" .. payload) end
F.FlushSightings()
ok(table.getn(F.sg) == 0 and sent[1] and string.find(sent[1], "^sg%^Alterac Valley%^HYDRA%^Akuula%.60%.5%.8%.1,Zed%.0%.4%.5%.0") ~= nil,
  "the batch goes to the realm bot as one line (" .. tostring(sent[1]) .. ")")

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
