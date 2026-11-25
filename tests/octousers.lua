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


-- (23 Nov 2026) the whole realm, through pfUI Octo's hidden channel (updatenotify.lua pfUI.realmChannel)
do
  local RC = pfUI.realmChannel
  ok(RC and RC.Join and RC.List and RC.Read and RC.Tick, "realm channel loaded")
  local keep2 = {}
  for _, k in ipairs({ "JoinChannelByName", "GetChannelName", "SendChatMessage", "ListChannelByName", "arg9" }) do keep2[k] = rawget(_G, k) end
  local chanId, said, listed = 0, {}, 0
  _G.JoinChannelByName = function(n) if n == "OctoArcade" then chanId = 7 end end
  _G.GetChannelName = function(n) if n == "OctoArcade" then return chanId end return 0 end
  _G.SendChatMessage = function(msg, kind, lang, id) table.insert(said, { msg, kind, id }) end
  _G.ListChannelByName = function(n) if n == "OctoArcade" then listed = listed + 1 end end
  local envSend = pfUI.env and rawget(pfUI.env, "SendChatMessage")
  if pfUI.env then pfUI.env.SendChatMessage = _G.SendChatMessage end
  local function Chan(text, from, ev)
    _G.event, _G.arg1, _G.arg2, _G.arg4, _G.arg9 = ev or "CHAT_MSG_CHANNEL", text, from, "7. OctoArcade", "OctoArcade"
    _G.this = pfUI.updater
    onEvent()
  end
  local function Run(secs)
    for _ = 1, secs * 4 do
      now = now + .25
      _G.this = pfUI.updater
      onUpdate()
    end
  end
  -- login: joined after 20 s, "OV1 <version> ?" said, the member list asked
  pfUI.updater.rcAt, pfUI.updater.rcStep = now + 20, nil
  Run(32)
  ok(chanId == 7 and said[1] and said[1][1] == "OV1 " .. pfUI.version.octo .. " ?" and said[1][2] == "CHANNEL" and said[1][3] == 7
    and listed == 1, "at login: joined, version said on the channel, member list asked (" .. tostring(said[1] and said[1][1]) .. ")")
  -- the member list: everyone in the channel is online now, any version
  Chan("*Owner, Fiona, Gus-NZ, Hal", nil, "CHAT_MSG_CHANNEL_LIST")
  local c = U.Counts()
  local live = {}
  for _, e in ipairs(c.list) do if e.live then live[e.name] = true end end
  ok(live.Owner and live.Fiona and live.Gus and live.Hal, "everyone in the channel counts as online (any version)")
  -- versions said on the channel; older score lines count as pfUI Octo with no version
  Chan("OV1 1.2.12", "Fiona")
  Chan("OA1 @NZ ? gridshot:100:50", "Hal")
  local s2 = U.Store()
  ok(s2.Fiona.v == "1.2.12" and s2.Hal and s2.Hal.v == nil, "versions from the channel; an older score line counts too")
  -- someone older asks: one answer from us, unless someone at least as new answers first
  said = {}
  RC.answered = nil
  Chan("OV1 1.0.1 ?", "Oldie")
  ok(RC.answerAt, "an older player asking: an answer is planned")
  Run(12)
  ok(said[1] and said[1][1] == "OV1 " .. pfUI.version.octo, "we answer with our version: " .. tostring(said[1] and said[1][1]))
  said = {}
  RC.answered = nil
  Chan("OV1 1.0.2 ?", "Oldie2")
  Chan("OV1 " .. pfUI.version.octo, "Quicker")
  Run(12)
  ok(table.getn(said) == 0, "someone just as new answered first: we stay quiet")
  -- a newer version on the channel: the update window is wanted
  local keepSeen, keepSkip = pfUI_init.octoupdate, pfUI_init.octoupdateskip
  pfUI_init.octoupdate, pfUI_init.octoupdateskip = nil, nil
  -- (25 Nov 2026, code review: anyone on the realm could type "OV1 99.0.0") a made-up jump is never believed; the
  -- next minor version is, once three players said it
  Chan("OV1 99.0.0 ?", "Future")
  Chan("OV1 99.0.0", "Future2")
  Chan("OV1 99.0.0", "Future3")
  ok(pfUI_init.octoupdate == nil and not pfUI.updater.popAt, "a made-up 99.0.0 on the channel opens nothing")
  local _, _, ma, mi = string.find(pfUI.version.octo, "^(%d+)%.(%d+)")
  local nextv = ma .. "." .. (tonumber(mi) + 1) .. ".0"
  Chan("OV1 " .. nextv, "Next1")
  Chan("OV1 " .. nextv, "Next2")
  ok(pfUI_init.octoupdate == nil, "two players are not enough")
  Chan("OV1 " .. nextv, "Next3")
  ok(pfUI_init.octoupdate == nextv and pfUI.updater.popAt, "three players saying the next version: the update window opens")
  pfUI.updater.popAt = nil
  pfUI_init.octoupdate, pfUI_init.octoupdateskip = keepSeen, keepSkip
  -- never in chat
  ok(RC.IsOurs("OctoArcade", "7. OctoArcade") and not RC.IsOurs("General", "1. General"), "the channel is known (kept out of chat)")
  for k, v in pairs(keep2) do _G[k] = v end
  if pfUI.env then pfUI.env.SendChatMessage = envSend end
end

for k, v in pairs(keep) do _G[k] = v end
pfUI_cache.octousers = nil
