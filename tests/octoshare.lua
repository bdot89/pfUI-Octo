-- pfUI Octo: OctoShare collector + Emit (modules/octoshare.lua, 27 Nov 2026), run by tests\run.lua.
local ok = octo_ok
local OS = pfUI.octoshare
ok(OS and OS.Log and OS.Emit and OS.Clear, "OctoShare loaded (pfUI.octoshare)")
if not OS then return end

pfUI_config.octoshare = pfUI_config.octoshare or {}
local S = pfUI_config.octoshare
local keep = { SendAddonMessage = rawget(_G, "SendAddonMessage"), UnitName = rawget(_G, "UnitName") }
_G.UnitName = function(u) return "Me" end

-- off as it comes: nothing is logged
S.collect, S.enable, S.channel = "0", "0", ""
OS.Clear()
OS.Log("pfAP", "N'Zoth-Alliance^20050^4306:0=1200", "GUILD", "Seller")
ok(table.getn(OS.DB().log) == 0, "collector off: nothing logged")

-- collector on: a known feed is logged, an unknown prefix and our own echo are not
S.collect = "1"
OS.Log("pfAP", "N'Zoth-Alliance^20050^4306:0=1200", "GUILD", "Seller")
OS.Log("pfXX", "not a feed", "GUILD", "Seller")          -- unknown prefix
OS.Log("pfAP", "mine", "GUILD", "Me")                     -- our own name
ok(table.getn(OS.DB().log) == 1, "collector on: only the known feed from someone else is kept")
local line = OS.DB().log[1]
ok(string.find(line, "`pfAP`Seller`GUILD`", 1, true) ~= nil, "the log line has ts`kind`sender`chan`payload")

-- the governor: Send queues, and a "|" (the server bans it) is refused
local sent = {}
_G.SendAddonMessage = function(pfx, msg, chan, idx) table.insert(sent, { pfx, msg, chan, idx }) end
OS.q, OS.qn = {}, 0
OS.Send("pfOS", "hello", "GUILD")
ok(OS.qn == 1, "Send queues a message")
OS.Send("pfOS", "has|pipe", "GUILD")
ok(OS.qn == 1, "a message with a pipe is refused (the server bans it)")

-- the queue is capped: the oldest is dropped, never an unbounded backlog that could later flood
OS.q, OS.qn = {}, 0
local savedCap = OS.QCAP
OS.QCAP = 5
for i = 1, 20 do OS.Send("pfOS", "m" .. i, "GUILD") end
ok(OS.qn == 5 and OS.q[OS.qn][2] == "m20", "queue capped at " .. OS.QCAP .. ", newest kept")
OS.QCAP = savedCap

-- Emit: off until enabled, then it fans out through the governor
S.enable = "0"
OS.q, OS.qn = {}, 0
OS.Emit("bgq", "wsg^alliance^45")
ok(OS.qn == 0, "Emit off: nothing queued")
S.enable = "1"
OS.Emit("bgq", "wsg^alliance^45")
ok(OS.qn >= 1 and OS.q[1][2] == "bgq^wsg^alliance^45", "Emit on: the record is queued through the governor")

-- Broadcast reaches each channel; the realm-wide master is an addon WHISPER (CHANNEL is unsupported on this client)
S.master = ""
OS.q, OS.qn = {}, 0
OS.Broadcast("pfAP", "prices", { "GUILD", "RAID" })
ok(OS.qn == 2, "Broadcast queues one per channel (no master set)")
S.master = "Errorbot"
OS.q, OS.qn = {}, 0
OS.Broadcast("pfAP", "prices", { "GUILD" })
ok(OS.qn == 1, "a typed master is ignored - the masters are hard-set per realm")
S.master = ""

-- (28 Nov 2026) the realm's built-in data bot: own faction only, a typed master wins, offline = hidden line + pause
local realmWas, factionWas, timeWas = rawget(_G, "GetRealmName"), rawget(_G, "UnitFactionGroup"), rawget(_G, "GetTime")
local clock = 1000
_G.GetTime = function() return clock end
_G.GetRealmName = function() return "Y'Shaarj" end
_G.UnitFactionGroup = function() return "Horde", "Horde" end
S.realmbots = "1"
OS.masterDownUntil = 0
ok(OS.Master() == "Errorgchat", "Y'Shaarj Horde whispers the realm bot (" .. tostring(OS.Master()) .. ")")
_G.UnitFactionGroup = function() return "Alliance", "Alliance" end
ok(OS.Master() == "Octopfui", "Y'Shaarj Alliance whispers its own bot, never the Horde one")
_G.GetRealmName = function() return "C'Thun" end
ok(OS.Master() == nil, "a realm with no bot yet sends nothing")
_G.GetRealmName = function() return "N'Zoth" end
ok(OS.Master() == "Pfuiocto", "N'Zoth (cross-faction): Alliance whispers its one bot")
_G.UnitFactionGroup = function() return "Horde", "Horde" end
ok(OS.Master() == "Pfuiocto", "N'Zoth (cross-faction): Horde whispers the same bot")
_G.UnitFactionGroup = function() return "Alliance", "Alliance" end
_G.GetRealmName = function() return "Y'Shaarj" end
_G.UnitFactionGroup = function() return "Horde", "Horde" end
_G.GetRealmName = function() return "Somewhere Else" end
ok(OS.Master() == nil, "an unknown realm has no bot")
_G.GetRealmName = function() return "Y'Shaarj" end
S.realmbots = "0"
ok(OS.Master() == "Errorgchat", "the old realmbots switch can't turn the bot off (hard-set)")
S.realmbots = nil
S.master = "Mycollector"
ok(OS.Master() == "Errorgchat", "a master typed in by hand can't redirect it (hard-set)")
S.master = ""
OS.BOTS["Y'Shaarj"].Horde = "Hijacker"
ok(OS.Master() == "Errorgchat", "changing OS.BOTS from outside changes nothing (it is only a copy)")
OS.BOTS["Y'Shaarj"].Horde = "Errorgchat"ok(OS.MasterNotFound("No player named 'Errorgchat' is currently playing.") and true or false, "the bot's not-found line is recognised")
ok(not OS.MasterNotFound("No player named 'Someone' is currently playing."), "someone else's not-found line is left alone")
ok(not OS.MasterNotFound("Errorgchat has come online."), "other lines with the bot's name are left alone")
OS.q, OS.qn = {}, 0
OS.Broadcast("pfAP", "prices", { "GUILD" })
ok(OS.qn == 2, "guild + the bot are queued")
local shown = 0
local chatWas = OS.chatWrapped
_G.event, _G.arg1 = "CHAT_MSG_SYSTEM", "No player named 'Errorgchat' is currently playing."
OS.MasterDown()
ok(OS.qn == 1 and OS.q[1][3] == "GUILD", "bot offline: its waiting whispers are dropped, guild stays")
ok(OS.Master() == nil, "bot offline: paused")
clock = clock + OS.DOWNFOR + 1
ok(OS.Master() == "Errorgchat", "after the pause it tries the bot again")
OS.q, OS.qn = {}, 0
OS.EmitBot("hb", "Durotar^41^WARRIOR^87^1.2.84^")
ok(OS.qn == 1 and OS.q[1][3] == "WHISPER" and OS.q[1][4] == "Errorgchat" and OS.q[1][2] == "hb^Durotar^41^WARRIOR^87^1.2.84^",
  "EmitBot whispers the realm bot only, no guild copy")
_G.GetRealmName = function() return "C'Thun" end
OS.q, OS.qn = {}, 0
OS.EmitBot("hb", "x")
ok(OS.qn == 0, "EmitBot sends nothing on a realm with no bot")
_G.GetRealmName = function() return "Y'Shaarj" end
_G.event, _G.arg1 = nil, nil
OS.q, OS.qn = {}, 0
OS.masterDownUntil = 0
_G.GetRealmName, _G.UnitFactionGroup, _G.GetTime = realmWas, factionWas, timeWas

-- the trim keeps the log under the cap
S.collect = "1"
local savedMax = OS.MAXLOG
OS.MAXLOG = 20
OS.Clear()
for i = 1, 60 do OS.Log("pfLB", "A^WARRIOR^60^kl=" .. i, "GUILD", "P" .. i) end
ok(table.getn(OS.DB().log) <= OS.MAXLOG, "the collector log stays under its cap (" .. table.getn(OS.DB().log) .. ")")
OS.MAXLOG = savedMax
OS.Clear()

S.collect, S.enable = "0", "0"
for k, v in pairs(keep) do _G[k] = v end
