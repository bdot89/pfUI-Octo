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
ok(has("icons-nodes.lua", '"Interface\\\\AddOns\\\\pfUI\\\\pfquest\\\\icons"'), "the node icons are found in pfUI\\pfquest\\icons")
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
pfUI = { stand = "in" }
run("restore.lua")
ok(pfUI == realPfUI and pfUI_config == realConfig and pfQuestOctoHidden == nil, "restore.lua puts pfUI and its settings back")

-- the standalone pfQuest is on: everything steps aside
_G.pfDB = { standalone = true }
run("guard.lua")
ok(pfQuestOctoSkip == true and pfUI == realPfUI, "standalone pfQuest loaded: guard leaves pfUI alone")
local before = _G.pfQuestCompat
local good = run("compat/client.lua")
ok(good and _G.pfQuestCompat == before, "...and a guarded file does nothing")
run("restore.lua")
ok(pfUI == realPfUI, "...and restore.lua changes nothing")
_G.pfDB, pfQuestOctoSkip = realDB, nil
