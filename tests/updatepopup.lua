-- pfUI Octo: the "new version is out" window (modules/updatenotify.lua pfUI.octoUpdate), run by tests\run.lua
local ok = octo_ok
local UP = pfUI.octoUpdate
ok(UP and UP.Build and UP.NotesSince and UP.NoteMessages and UP.ReadNotes, "update window loaded (pfUI.octoUpdate)")
if not (UP and UP.Build and pfUI.updater) then return end

ok(pfUI.octoNotes and pfUI.octoNotes[1] and pfUI.octoNotes[1][1] == pfUI.version.octo,
  "updatenotes.lua is made for this version (run tools\\Make-UpdateNotes.ps1): " .. tostring(pfUI.octoNotes and pfUI.octoNotes[1] and pfUI.octoNotes[1][1]))
ok(UP.url == "https://github.com/bdot89/pfUI", "the link is the OctoLauncher one")
for _, e in ipairs(pfUI.octoNotes or {}) do
  for _, it in ipairs(e[2]) do
    if string.find(it[1] .. (it[2] or ""), "[^\32-\126]") then ok(false, "plain text only in the notes: " .. e[1]) end
  end
end

local keep = {}
for _, k in ipairs({ "GetTime", "UnitName", "SendAddonMessage", "UnitAffectingCombat", "event", "arg1", "arg2", "arg3", "arg4" }) do
  keep[k] = rawget(_G, k)
end
local keepVersion, keepSeen, keepSkip, keepPop = pfUI.version.octo, pfUI_init.octoupdate, pfUI_init.octoupdateskip, pfUI_config.global.updatepopup
local now = 9000
_G.GetTime = function() return now end
_G.UnitName = function(u) if u == "player" then return "Me" end end
local fighting
_G.UnitAffectingCombat = function() return fighting end
local sent = {}
_G.SendAddonMessage = function(p, m, c) table.insert(sent, { p, m, c }) end

local onEvent = pfUI.updater:GetScript("OnEvent")
local onUpdate = pfUI.updater:GetScript("OnUpdate")
local function Msg(text, chan, from)
  _G.event, _G.arg1, _G.arg2, _G.arg3, _G.arg4 = "CHAT_MSG_ADDON", "pfUIOcto", text, chan, from
  _G.this = pfUI.updater
  onEvent()
end
local function Tick(dt) now = now + (dt or 0) _G.this = pfUI.updater onUpdate() end

-- the newer side: someone on 1.1.20 asks what came after it
local mine = pfUI.version.octo
local msgs = UP.NoteMessages("1.1.20")
ok(msgs[1] and string.find(msgs[1], "^W%^" .. string.gsub(mine, "%.", "%%.") .. "%^"), "answer starts with the newest version")
for _, m in ipairs(msgs) do
  if string.len(m) > 240 or string.find(m, "|") then ok(false, "answer too long or has a |: " .. m) end
end
ok(table.getn(UP.NoteMessages(mine)) == 0, "nothing to tell someone on our own version")

sent = {}
Msg("N:1.1.20", "GUILD", "Oldie")
Msg("N:1.1.20", "GUILD", "Oldie2")
ok(table.getn(sent) == 0, "no answer at once")
Tick(5)
Tick(0)
for i = 1, 40 do Tick(.31) end
local answers = 0
for _, s in ipairs(sent) do if string.sub(s[2], 1, 2) == "W^" and s[3] == "GUILD" then answers = answers + 1 end end
ok(answers == table.getn(msgs), "one set of answers on the asking channel: " .. answers .. " of " .. table.getn(msgs))
sent = {}
Msg("N:1.1.21", "GUILD", "Oldie3")
Tick(5) Tick(.31)
ok(table.getn(sent) == 0, "not again on that channel within a minute")
-- another newer client answered first: we stay quiet
Msg("N:1.1.21", "RAID", "Oldie4")
Msg("W^" .. mine .. "^Something", "RAID", "Other")
Tick(5) Tick(.31) Tick(.31)
ok(table.getn(sent) == 0, "someone else answered first: no second answer")

-- the older side: pretend we run 1.1.30 and hear 1.9.40
pfUI.version.octo = "1.1.30"
pfUI_init.octoupdate, pfUI_init.octoupdateskip = nil, nil
pfUI_config.global.updatepopup = "1"
UP.shownThis = nil
UP.heard = {}
if UP.frame then UP.frame:Hide() end
_G.event, _G.this = "PLAYER_ENTERING_WORLD", pfUI.updater
onEvent()
sent = {}
Msg("V:1.9.40", "GUILD", "Newbie")
ok(pfUI_init.octoupdate == "1.9.40", "newer version noted")
local asked
for _, s in ipairs(sent) do if s[2] == "N:1.1.30" and s[3] == "GUILD" then asked = true end end
ok(asked, "asks for the notes where it heard the newer version")
Msg("W^1.9.40^Mail sends everything^Update window", "GUILD", "Newbie")
Msg("W^1.9.40^Update window^Third thing", "GUILD", "Newbie")
ok(UP.heard["1.9.40"] and table.getn(UP.heard["1.9.40"]) == 3, "heard titles kept once each")
local list = UP.NotesSince("1.1.30")
ok(list[1] and list[1].v == "1.9.40" and list[1].items[1][1] == "Mail sends everything", "newest heard version first")
local has39
for _, e in ipairs(list) do if e.v == "1.1.39" then has39 = true end end
ok(has39, "our own notes for versions after ours come in too")

-- in combat it waits; afterwards it opens once
fighting = true
Tick(20)
ok(not (UP.frame and UP.frame:IsShown()), "no window in combat")
fighting = nil
_G.event, _G.this = "PLAYER_REGEN_ENABLED", pfUI.updater
onEvent()
Tick(3)
ok(UP.frame and UP.frame:IsShown(), "window opens after the fight")
ok(UP.frame.box:GetText() == UP.url, "link box holds the launcher link")
ok(string.find(UP.frame.versions:GetText() or "", "1.9.40") and string.find(UP.frame.versions:GetText() or "", "1.1.30"), "both versions shown")
local lines = 0
for _, l in ipairs(UP.frame.lines) do if l:IsShown() then lines = lines + 1 end end
ok(lines >= 4, "what's new lines shown: " .. lines)
ok((UP.frame:GetHeight() or 0) > 200 and (UP.frame:GetHeight() or 0) < 600, "window height " .. tostring(UP.frame:GetHeight()))
-- Don't show for this version
UP.frame.skip:GetScript("OnClick")()
ok(pfUI_init.octoupdateskip == "1.9.40" and not UP.frame:IsShown(), "skip hides it for this version")
UP.shownThis = nil
ok(not UP.Wanted(), "skipped version stays quiet")
pfUI_init.octoupdate = "1.9.41"
ok(UP.Wanted(), "an even newer version shows again")
pfUI_config.global.updatepopup = "0"
ok(not UP.Wanted(), "switched off in the options")

pfUI.version.octo, pfUI_init.octoupdate, pfUI_init.octoupdateskip, pfUI_config.global.updatepopup = keepVersion, keepSeen, keepSkip, keepPop
UP.heard = {}
UP.shownThis = nil
if UP.frame then UP.frame:Hide() end
for k, v in pairs(keep) do _G[k] = v end
