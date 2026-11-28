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

-- (28 Nov 2026, seen in game) this server refuses ADDON WHISPERS ("Unknown addon chat type"): the bots get none
local realmWas, factionWas, timeWas = rawget(_G, "GetRealmName"), rawget(_G, "UnitFactionGroup"), rawget(_G, "GetTime")
_G.GetRealmName = function() return "Y'Shaarj" end
_G.UnitFactionGroup = function() return "Horde", "Horde" end
ok(OS.noWhisper == true, "addon whispers stay off (refused by this server)")
S.bottest = "0"
OS.masterDownUntil = 0
ok(OS.Master() == "Errorgchat", "1.2.88: the realm bot gets the hidden whisper for everyone - no trial switch")
ok(S.bottest == "0" and OS.ChatWhisperOn() == true, "an old saved trial switch changes nothing")
OS.q, OS.qn = {}, 0
OS.Broadcast("pfAP", "prices", { "GUILD" })
ok(OS.qn == 2 and OS.q[1][3] == "GUILD" and OS.q[2][3] == "WHISPER" and OS.q[2][4] == "Errorgchat",
  "Broadcast: guild + the realm bot")
S.bottest = nil
ok(OS.AddonRefused("Unknown addon chat type (prefix pfLB)") == true, "the server's refusal of our prefix is recognised (and hidden)")
ok(OS.AddonRefused("Unknown addon chat type (prefix BigWigs)") == false, "another add-on's refusal line is left alone")
ok(OS.AddonRefused("Players online: 87") == false, "other system lines are left alone")
_G.GetRealmName, _G.UnitFactionGroup = realmWas, factionWas

-- (28 Nov 2026) the hidden NORMAL whisper: its text, and that every copy of the line is recognised for hiding
ok(OS.WhisperText("pfLB", "A^WARRIOR^60^kl=5") == "~OS~pfLB~A^WARRIOR^60^kl=5", "data whisper text: " .. OS.WhisperText("pfLB", "A^WARRIOR^60^kl=5"))
ok(string.len(OS.WhisperText("pfOS", string.rep("x", 300))) <= 250, "a data whisper fits a chat line")
ok(OS.IsOurWhisper("~OS~pfOS~hb^Durotar") and not OS.IsOurWhisper("hey, ~OS~ inv?") and not OS.IsOurWhisper(nil),
  "only lines that start with the mark are ours")
ok(OS.feeds == nil or OS.IsAfk() == false, "not AFK by default")

-- the realm bot logic itself (hard-set, own faction, offline pause), tested with the trial switched on
local noWhisperWas = OS.noWhisper
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
OS.noWhisper = noWhisperWas
_G.GetRealmName, _G.UnitFactionGroup, _G.GetTime = realmWas, factionWas, timeWas

-- (28 Nov 2026) bundles: waiting lines for the bot share one whisper; a lone line or one with "}" goes the old way
OS.q, OS.qn = {}, 0
OS.Send("pfOS", "hb^Orgrimmar^60", "WHISPER", "Errorgchat")
OS.Send("pfLB", "Q", "WHISPER", "Errorgchat")
OS.Send("pfAP", "prices", "GUILD")
OS.Send("pfOS", "sg^Orgrimmar^^A.1.1.1.0", "WHISPER", "Errorgchat")
local first = table.remove(OS.q, 1) OS.qn = OS.qn - 1
local b = OS.TakeBundle(first)
ok(b == "~O2~pfOS~hb^Orgrimmar^60}pfLB~Q}pfOS~sg^Orgrimmar^^A.1.1.1.0", "three bot lines in one bundle (" .. tostring(b) .. ")")
ok(OS.qn == 1 and OS.q[1][3] == "GUILD", "the guild line stays queued")
ok(OS.IsOurWhisper(b), "a bundle is hidden like the other data whispers")
OS.q, OS.qn = {}, 0
ok(OS.TakeBundle({ "pfOS", "hb^x", "WHISPER", "Errorgchat" }) == nil, "a lone line is not a bundle")
OS.Send("pfOS", "a}b", "WHISPER", "Errorgchat")
ok(OS.TakeBundle({ "pfOS", "hb^x", "WHISPER", "Errorgchat" }) == nil, "a line with } is never bundled")
OS.q, OS.qn = {}, 0
for i = 1, 30 do OS.Send("pfOS", "hb^" .. string.rep("z", 30) .. i, "WHISPER", "Errorgchat") end
first = table.remove(OS.q, 1) OS.qn = OS.qn - 1
b = OS.TakeBundle(first)
ok(b and string.len(b) <= OS.BUNDLEMAX and OS.qn > 0, "a bundle stops at " .. OS.BUNDLEMAX .. " characters (" .. string.len(b or "") .. "), the rest waits")
OS.q, OS.qn = {}, 0

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
