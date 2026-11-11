-- pfUI Octo: pfQuest built in (pfquest\, made by tools\Sync-pfQuest.ps1), run by tests\run.lua.
-- The load list, the guard on every file, hiding pfUI while pfQuest's files
-- run, and stepping aside for the standalone pfQuest.
local ok, DIR = octo_ok, octo_dir

local function lines(path)
  local t = {}
  local h = io.open(path, "rb")
  if not h then return nil end
  for l in h:lines() do table.insert(t, (string.gsub(l, "\r$", ""))) end
  h:close()
  return t
end

local toc = lines(DIR .. "/pfUI.toc") or {}
local listed, svAcc, svChar
for i = 1, table.getn(toc) do
  local l = toc[i]
  if l == "pfquest\\pfquest.xml" then listed = i end
  if string.find(l, "^## SavedVariables:") then svAcc = l end
  if string.find(l, "^## SavedVariablesPerCharacter:") then svChar = l end
end
ok(listed and listed == table.getn(toc) or (listed and toc[listed + 1] == nil), "the toc loads pfquest\\pfquest.xml last")
ok(svAcc and string.find(svAcc, "pfQuest_questcache", 1, true) and string.find(svAcc, "pfQuest_turtlecount", 1, true), "pfQuest's account settings are saved by pfUI")
local allChar = true
for _, v in ipairs({ "pfQuest_config", "pfBrowser_fav", "pfQuest_history", "pfQuest_colors", "pfQuest_server", "pfQuest_track" }) do
  if not (svChar and string.find(svChar, v, 1, true)) then allChar = false end
end
ok(allChar, "pfQuest's character settings (history, tracking...) are saved by pfUI")

-- every file in the load list exists and starts with the guard
local xml = lines(DIR .. "/pfquest/pfquest.xml") or {}
local files = {}
for i = 1, table.getn(xml) do
  local _, _, f = string.find(xml[i], '<Script%s+file="([^"]+)"')
  if f then table.insert(files, (string.gsub(f, "\\", "/"))) end
end
ok(files[1] == "guard.lua" and files[table.getn(files)] == "restore.lua", "guard.lua first, restore.lua last")
ok(table.getn(files) > 40, "pfQuest's files are listed (" .. table.getn(files) .. ")")
local missing, unguarded = {}, {}
for i = 2, table.getn(files) - 1 do
  local h = io.open(DIR .. "/pfquest/" .. files[i], "rb")
  if not h then table.insert(missing, files[i]) else
    local first = h:read("*l") or ""
    h:close()
    if not string.find(first, "^if pfQuestOctoSkip then return end") then table.insert(unguarded, files[i]) end
  end
end
ok(table.getn(missing) == 0, "every listed file is there " .. table.concat(missing, ", "))
ok(table.getn(unguarded) == 0, "every pfQuest file starts with the guard " .. table.concat(unguarded, ", "))
local want = { "db/meta.lua", "db/meta-turtle.lua", "db/objects.lua", "db/enUS/objects-turtle.lua", "slashcmd.lua", "database.lua", "turtle-patchtable.lua" }
local have = {}
for i = 1, table.getn(files) do have[files[i]] = true end
local all = true
for i = 1, table.getn(want) do if not have[want[i]] then all = false end end
ok(all, "the vanilla and OctoWoW/Turtle data and /db are in the list")

-- the patched starts: ADDON_LOADED "pfUI", and the folder inside pfUI
local function has(file, text)
  local h = io.open(DIR .. "/pfquest/" .. file, "rb")
  if not h then return false end
  local s = h:read("*a")
  h:close()
  return string.find(s, text, 1, true) and true or false
end
ok(has("config.lua", 'arg1 == "pfUI"') and has("quest.lua", 'arg1 == "pfUI"'), "pfQuest starts on pfUI's ADDON_LOADED")
ok(has("config.lua", 'pfQuestConfig.path = "Interface\\\\AddOns\\\\pfUI\\\\pfquest"'), "pfQuest's art is found in pfUI\\pfquest")
-- (11 Nov 2026) lightblade's pfQuest-turtle as the launcher installs it: its pictures, its version
ok(has("turtle-pfQuest-nameplates.lua", '"Interface\\\\AddOns\\\\pfUI\\\\pfquest\\\\turtle-img\\\\slay"')
  and not has("turtle-pfQuest-nameplates.lua", "AddOns\\\\pfQuest-turtle"), "pfQuest-turtle's pictures are found in pfUI\\pfquest\\turtle-img")
local th = io.open(DIR .. "/pfquest/turtle-img/slay.blp", "rb")
ok(th ~= nil, "pfQuest-turtle's images are copied") if th then th:close() end
ok(has("turtle-pfQuest-updater.lua", 'pfQuestOctoMeta("pfQuest-turtle", "Version")')
  and not has("turtle-pfQuest-updater.lua", "GetAddOnMetadata("), "pfQuest-turtle asks pfUI's toc for its version")
ok(has("updatenotify.lua", 'pfQuestOctoMeta("pfQuest", "Version")') and has("config.lua", "local tocs = {}"),
  "pfQuest's version and folder come from pfUI, not an old pfQuest folder")
ok(has("compat/client.lua", "pfQuestOctoParse = ParseQuestLevels") and not has("compat/client.lua", ".pfQuestHookAddMessage"),
  "pfQuest's chat hook uses its own names")
ok(has("pfquest.xml", 'turtle-pfQuest-worldmap.lua') and has("pfquest.xml", 'turtle-pfQuest-lootpanel.lua'),
  "the world map pins and loot panel load")
local h = io.open(DIR .. "/pfquest/img/available.tga", "rb")
ok(h ~= nil, "pfQuest's images are copied") if h then h:close() end

-- guard + restore: pfUI is hidden while pfQuest runs and put back after
local function run(file)
  local fn = loadfile(DIR .. "/pfquest/" .. file)
  return fn and pcall(fn)
end
local realPfUI, realConfig, realDB = pfUI, pfUI_config, rawget(_G, "pfDB")
_G.pfDB = nil
run("guard.lua")
ok(pfQuestOctoSkip == false and pfUI == nil and pfUI_config == nil, "no standalone pfQuest: pfUI hidden while pfQuest's files run")
do
  local realMeta = rawget(_G, "GetAddOnMetadata")
  _G.GetAddOnMetadata = function(a, f)
    if a == "pfUI" and f == "X-pfQuest-Version" then return "8.0.51" end
    if a == "pfUI" and f == "X-pfQuest-Turtle-Version" then return "1.0.39" end
    if a == "pfQuest" then return "7.0.1" end -- an old copy left in AddOns
  end
  ok(pfQuestOctoMeta and pfQuestOctoMeta("pfQuest", "Version") == "8.0.51" and pfQuestOctoMeta("pfQuest-turtle", "Version") == "1.0.39",
    "built in, pfQuest's versions come from pfUI's toc, not an old pfQuest folder")
  _G.GetAddOnMetadata = realMeta
end
pfUI = { stand = "in" }
run("restore.lua")
ok(pfUI == realPfUI and pfUI_config == realConfig and pfQuestOctoHidden == nil, "restore.lua puts pfUI and its settings back")

-- the off switch (9 Nov 2026): guard / restore note what pfQuest's files change,
-- modules\questing.lua puts it back
do
  local realCF, realAbandon, realAdd = CreateFrame, _G.AbandonQuest, ChatFrame1 and rawget(ChatFrame1, "AddMessage")
  local gameAbandon = function() end
  _G.AbandonQuest = gameAbandon
  _G.pfDB = nil
  run("guard.lua")
  ok(pfQuestOcto and CreateFrame ~= realCF, "guard.lua notes the frames pfQuest's files make")
  -- what pfQuest's files do: replace a game function, make frames, add /db, hook chat
  _G.AbandonQuest = function() end
  local f = CreateFrame("Frame", "pfQuestOctoTestFrame", UIParent)
  local f2 = CreateFrame("Frame")
  f:SetScript("OnEvent", function() end)
  f:Show()
  SlashCmdList.PFQUESTOCTOTEST = function() end
  ChatFrame1.pfQuestOctoHookAddMessage = ChatFrame1.AddMessage
  local pq = function() end
  ChatFrame1.AddMessage = pq
  ChatFrame1.pfQuestOctoParse = pq
  -- (11 Nov 2026) pfUI's chat sits on top of pfQuest's hook in ChatFrame2
  local cf2, game2 = ChatFrame2, function() end
  local pq2, pfchat2 = function() end, function() end
  local keep2 = { cf2.AddMessage, cf2.HookAddMessage }
  cf2.pfQuestOctoHookAddMessage, cf2.pfQuestOctoParse = game2, pq2
  cf2.HookAddMessage, cf2.AddMessage = pq2, pfchat2
  _G.pfMap = { tooltips = {} }
  pfUI = nil
  run("restore.lua")
  ok(CreateFrame == realCF, "restore.lua gives CreateFrame back")
  ok(pfQuestOcto.changed.AbandonQuest == gameAbandon, "a replaced game function is noted with the game's own")
  ok(table.getn(pfQuestOcto.frames) == 2 and pfQuestOcto.frames[1] == f and pfQuestOcto.frames[2] == f2, "both frames noted")
  ok(pfQuestOcto.slash.PFQUESTOCTOTEST, "the new slash command noted")
  ok(pfQuestOcto.changed.CreateFrame == nil and pfQuestOcto.before == nil, "nothing else noted, the snapshot freed")

  local Q = pfUI.questing
  ok(Q and Q.State() == "builtin", "Questing: the built-in pfQuest is on (" .. tostring(Q and Q.State()) .. ")")

  -- (11 Nov 2026) pfQuest-turtle's nameplate icons off once while our nameplates mark quests, with a notice
  if Q and Q.PlateIconsOnce then
    local cfg = pfUI_config
    local keep = { _G.pfQuest_config, _G.pfUI_cache, cfg.questing.turtleplates, cfg.plates.questmark, (cfg.disabled or {}).nameplates }
    cfg.disabled = cfg.disabled or {}
    _G.pfUI_cache = {}
    _G.pfQuest_config = nil
    cfg.questing.turtleplates, cfg.plates.questmark, cfg.disabled.nameplates = "0", "1", "0"
    Q.noticeDue = nil
    Q.PlateIconsOnce()
    ok(_G.pfQuest_config and _G.pfQuest_config.nameplatesEnabled == "0" and cfg.questing.turtleplates == "1" and Q.noticeDue,
      "pfQuest's nameplate icons off once, notice due")
    _G.pfQuest_config.nameplatesEnabled = "1"
    Q.noticeDue = nil
    Q.PlateIconsOnce()
    ok(_G.pfQuest_config.nameplatesEnabled == "1" and not Q.noticeDue, "...only once: turned back on, it stays on")
    local shown, buttons
    local realQ = pfUI.env.CreateQuestionDialog
    pfUI.env.CreateQuestionDialog = function(text, a, b) shown, buttons = text, { a, b } end
    Q.Notice()
    pfUI.env.CreateQuestionDialog = realQ
    ok(shown and string.find(shown, "pfQuest", 1, true) and _G.pfUI_cache.questplatesnotice, "the notice is shown and remembered")
    _G.pfQuest_config.nameplatesEnabled = "0"
    if buttons and buttons[2] then buttons[2][2]() end
    ok(_G.pfQuest_config.nameplatesEnabled == "1", "the notice's second button puts pfQuest's icons back")
    _G.pfQuest_config = nil
    cfg.questing.turtleplates, cfg.plates.questmark = "0", "0"
    Q.PlateIconsOnce()
    ok(_G.pfQuest_config == nil and cfg.questing.turtleplates == "1", "our quest marks off: pfQuest's icons left alone")
    _G.pfQuest_config, _G.pfUI_cache = keep[1], keep[2]
    cfg.questing.turtleplates, cfg.plates.questmark, cfg.disabled.nameplates = keep[3], keep[4], keep[5]
  end
  Q.TurnOff()
  ok(_G.AbandonQuest == gameAbandon, "off: the game's function is back")
  ok(SlashCmdList.PFQUESTOCTOTEST == nil, "off: pfQuest's slash command is gone")
  ok(not f:IsShown() and f:GetScript("OnEvent") == nil, "off: pfQuest's frames are silent and hidden")
  ok(ChatFrame1.AddMessage ~= pq and ChatFrame1.pfQuestOctoHookAddMessage == nil, "off: chat's AddMessage is no longer pfQuest's")
  ok(cf2.AddMessage == pfchat2 and cf2.HookAddMessage == game2,
    "off: with pfUI's chat on top, only pfQuest's link leaves the chain (pfUI's chat stays)")
  cf2.AddMessage, cf2.HookAddMessage = keep2[1], keep2[2]
  -- (11 Nov 2026, Keeyn: "map.lua:34: attempt to index global 'pfMap'" after switching pfQuest off) pfMap
  -- stays for any pfQuest script still running; our nameplates and farm map ignore it while off
  ok(_G.pfMap ~= nil and Q.State() == "off" and not Q.MapOn(), "off: pfMap kept (no errors), its data unused, state off")
  local PL = pfUI.plates and pfUI.plates.Lists
  if PL and PL.Quest then
    _G.pfMap.tooltips = { Hogger = { [1] = {} } }
    ok(PL.Quest("Hogger") == nil, "off: the nameplates take no quest marks from pfQuest")
    _G.pfMap.tooltips = {}
  end
  _G.pfMap = nil

  -- pages build in every state
  local OUo = pfUI.octoui and pfUI.octoui.Options
  ok(OUo and OUo.BUILD and OUo.BUILD.qstpfquest and OUo.BUILD.qsthelpers, "Questing pages registered")
  Q.off, pfQuestOcto = nil, nil
  _G.AbandonQuest = realAbandon
  if ChatFrame1 then rawset(ChatFrame1, "AddMessage", realAdd) end
end

-- the standalone pfQuest is on: everything steps aside
_G.pfDB = { standalone = true }
run("guard.lua")
ok(pfQuestOctoSkip == true and pfUI == realPfUI, "standalone pfQuest loaded: guard leaves pfUI alone")
local before = _G.pfQuestCompat
local good = run("compat/client.lua")
ok(good and _G.pfQuestCompat == before, "...and a guarded file does nothing")
run("restore.lua")
ok(pfUI == realPfUI, "...and restore.lua changes nothing")

-- (9 Nov 2026) pfQuest's toc has "OptionalDeps: pfUI": the standalone one loads AFTER pfUI, so
-- there is no pfDB yet - it being switched on must be enough (both ran, and its chat hook went
-- past pfUI's chat: no times, class colours or links)
local realInfo = rawget(_G, "GetAddOnInfo")
_G.pfDB = nil
_G.GetAddOnInfo = function(n) if n == "pfQuest" then return "pfQuest", "pfQuest", "", 1, 1 end end
run("guard.lua")
ok(pfQuestOctoSkip == true and pfUI == realPfUI, "standalone pfQuest on but not loaded yet: the copy steps aside")
run("restore.lua")
_G.GetAddOnInfo = function(n) if n == "pfQuest" then return "pfQuest", "pfQuest", "", nil, 1 end end
run("guard.lua")
ok(pfQuestOctoSkip == false, "standalone pfQuest switched off: the copy runs")
run("restore.lua")
-- (11 Nov 2026) a pfQuest in another folder name counts, pfQuest's own add-ons do not
local realNum, realDeps = rawget(_G, "GetNumAddOns"), rawget(_G, "GetAddOnDependencies")
local list = {}
_G.GetNumAddOns = function() return table.getn(list) end
_G.GetAddOnInfo = function(n)
  local e = type(n) == "number" and list[n]
  if e then return e[1], e[1], "", e[2], 1 end
end
_G.GetAddOnDependencies = function(i) local e = list[i] if e then return e[3] end end
list = { { "pfUI", 1 }, { "pfQuest-master", 1 } }
run("guard.lua")
ok(pfQuestOctoSkip == true, "pfQuest unpacked as pfQuest-master and on: the copy steps aside")
run("restore.lua")
list = { { "pfUI", 1 }, { "pfQuest-turtle", 1, "pfQuest" }, { "pfQuest-icons", 1, "pfQuest" } }
run("guard.lua")
ok(pfQuestOctoSkip == false, "only pfQuest's add-ons (turtle data, icons): the copy runs")
run("restore.lua")
list = { { "pfQuest-master", nil } }
run("guard.lua")
ok(pfQuestOctoSkip == false, "pfQuest-master switched off: the copy runs")
_G.GetNumAddOns, _G.GetAddOnDependencies = realNum, realDeps
pfUI = realPfUI
pfUI_config = pfQuestOctoHidden and pfQuestOctoHidden.pfUI_config or pfUI_config
if pfQuestOcto and pfQuestOcto.make then CreateFrame = pfQuestOcto.make end
pfQuestOctoHidden, pfQuestOcto = nil, nil
_G.GetAddOnInfo = realInfo
_G.pfDB, pfQuestOctoSkip = realDB, nil
