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
S.enable = "1"
OS.q, OS.qn = {}, 0
for k, v in pairs(keep) do _G[k] = v end
