-- pfUI Octo: counting the players who run pfUI Octo (modules/updatenotify.lua pfUI.octoUsers), run by tests\run.lua
local ok = octo_ok
local U = pfUI.octoUsers
ok(U and U.Heard and U.Counts and pfUI.updater, "player count loaded (pfUI.octoUsers)")
if not (U and U.Heard and pfUI.updater) then return end

local keep = {}
for _, k in ipairs({ "time", "GetTime", "UnitName", "IsInGuild", "GetNumGuildMembers", "GetGuildRosterInfo",
  "GetNumRaidMembers", "GetNumPartyMembers", "SendAddonMessage", "GetRealmName", "event", "arg1", "arg2", "arg3", "arg4" }) do
  keep[k] = rawget(_G, k)
end
local clock, now = 1000000, 500
_G.time = function() return clock end
_G.GetTime = function() return now end
_G.GetRealmName = function() return "TestRealm" end
_G.UnitName = function(u) if u == "player" then return "Me" end end
_G.IsInGuild = function() return true end
local roster = { { "Alice", true }, { "Bob", false } }
_G.GetNumGuildMembers = function() return table.getn(roster) end
_G.GetGuildRosterInfo = function(i) local r = roster[i] return r[1], "", 0, 60, "Mage", "", "", "", r[2] end
_G.GetNumRaidMembers = function() return 0 end
_G.GetNumPartyMembers = function() return 0 end
local sent = {}
_G.SendAddonMessage = function(p, m, c) table.insert(sent, { p, m, c }) end
pfUI_cache.octousers = nil

local onEvent = pfUI.updater:GetScript("OnEvent")
local onUpdate = pfUI.updater:GetScript("OnUpdate")
local function Msg(prefix, text, chan, from)
  _G.event, _G.arg1, _G.arg2, _G.arg3, _G.arg4 = "CHAT_MSG_ADDON", prefix, text, chan, from
  _G.this = pfUI.updater
  onEvent()
end

-- an old version's login line, a newer one's, a gathering share (no version), someone else's add-on
Msg("pfUIOcto", "V:1.1.10", "GUILD", "Alice")
Msg("pfUIOcto", "V:1.1.25", "GUILD", "Bob-TestRealm")
Msg("pfGN", "N^1^2^3", "GUILD", "Carol")
Msg("SomethingElse", "V:9.9.9", "GUILD", "Dave")
Msg("pfUIOcto", "V:1.1.25", "GUILD", "Me")
local s = pfUI_cache.octousers.TestRealm
ok(s.Alice and s.Alice.v == "1.1.10" and s.Bob and s.Bob.v == "1.1.25", "versions noted per player (realm cut off the name)")
ok(s.Carol and s.Carol.v == nil, "a gathering share counts as a player, version unknown")
ok(not s.Dave and not s.Me, "other add-ons and your own messages are not counted")

clock = clock + 2 * 86400
now = now + 4000
Msg("pfFT", "x", "GUILD", "Erin")
local c = U.Counts()
-- online: Alice (guild says online), Erin (heard just now, not in the guild list); Bob is offline in the roster
ok(c.ever == 4 and c.week == 4 and c.day == 1, "heard ever / this week / today: " .. c.ever .. " / " .. c.week .. " / " .. c.day)
ok(c.online == 2, "online now from the guild list and fresh messages: " .. c.online)
ok(c.versions["1.1.25"] == 1 and c.versions["1.1.10"] == 1 and c.versions["?"] == 2, "versions this week")
ok(c.list[1].live and c.list[2].live and not c.list[3].live, "online players listed first")

-- "Q" asks: one answer per channel, a moment later, then not again within 30 s
sent = {}
Msg("pfUIOcto", "Q", "GUILD", "Alice")
Msg("pfUIOcto", "Q", "GUILD", "Bob")
ok(table.getn(sent) == 0, "no answer at once")
now = now + 5
onUpdate()
ok(table.getn(sent) == 1 and sent[1][1] == "pfUIOcto" and sent[1][2] == "V:" .. pfUI.version.octo and sent[1][3] == "GUILD",
  "one answer with our version on the asking channel")
Msg("pfUIOcto", "Q", "GUILD", "Erin")
now = now + 5
onUpdate()
ok(table.getn(sent) == 1, "not again within 30 s")

for k, v in pairs(keep) do _G[k] = v end
pfUI_cache.octousers = nil
