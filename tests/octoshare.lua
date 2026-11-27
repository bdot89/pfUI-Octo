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

-- Broadcast reaches each channel (realm channel added when one is joined)
OS.q, OS.qn = {}, 0
OS.channelIndex = nil
OS.Broadcast("pfAP", "prices", { "GUILD", "RAID" })
ok(OS.qn == 2, "Broadcast queues one per channel (no realm channel joined)")
OS.q, OS.qn = {}, 0
OS.channelIndex = 7
OS.Broadcast("pfAP", "prices", { "GUILD" })
ok(OS.qn == 2 and OS.q[2][3] == "CHANNEL" and OS.q[2][4] == 7, "Broadcast adds the realm channel when joined")
OS.channelIndex = nil

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
