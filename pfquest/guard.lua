-- pfUI Octo: when the standalone pfQuest add-on is on, every file of this copy
-- returns at its first line. pfQuest's toc says "OptionalDeps: pfUI", so the
-- standalone one loads AFTER pfUI and has not made pfDB yet: whether it is
-- switched on decides (9 Nov 2026: both ran, two of everything, and its chat
-- hook went straight to the game's, past pfUI's chat - no times, class colours
-- or links for anyone who still had pfQuest on).
-- (11 Nov 2026, dennis on Discord: two quest menus on the world map.) Any folder
-- name counts - a download unpacks as "pfQuest-master" - but not pfQuest's
-- add-ons (pfQuest-turtle, pfQuest-icons...), which need pfQuest to load.
local function pfQuestOctoMain(name, enabled, loadable, d1, d2, d3, d4)
  if not (name and enabled and loadable) then return false end
  local n = string.lower(name)
  if n == "pfui" or not string.find(n, "^pfquest") then return false end
  local d = { d1, d2, d3, d4 }
  for i = 1, 4 do
    if d[i] and string.find(string.lower(d[i]), "^pfquest") then return false end
  end
  return true
end
local function pfQuestOctoStandalone()
  if pfDB ~= nil then return true end
  if type(GetAddOnInfo) ~= "function" then return false end
  local ok, name, _, _, enabled, loadable = pcall(GetAddOnInfo, "pfQuest")
  if ok and name and enabled and loadable then return true end
  if type(GetNumAddOns) ~= "function" then return false end
  local count = GetNumAddOns()
  if type(count) ~= "number" then return false end
  for i = 1, count do
    local n, _, _, en, lo = GetAddOnInfo(i)
    local d1, d2, d3, d4
    if GetAddOnDependencies then d1, d2, d3, d4 = GetAddOnDependencies(i) end
    if pfQuestOctoMain(n, en, lo, d1, d2, d3, d4) then return true end
  end
  return false
end
pfQuestOctoSkip = pfQuestOctoStandalone()
-- Built in, pfQuest's own add-on names are not loaded (or are an old copy left
-- in AddOns): their versions come from pfUI's toc. Every GetAddOnMetadata in the
-- copied code calls this instead.
function pfQuestOctoMeta(addon, field)
  if field == "Version" then
    if addon == "pfQuest" or addon == "pfQuest-tbc" or addon == "pfQuest-wotlk" then
      return GetAddOnMetadata("pfUI", "X-pfQuest-Version")
    elseif addon == "pfQuest-turtle" then
      return GetAddOnMetadata("pfUI", "X-pfQuest-Turtle-Version")
    end
  end
  return GetAddOnMetadata(addon, field)
end
-- This copy loads after pfUI's files but before pfUI has its settings, so pfUI
-- is hidden while pfQuest's files run and put back after (restore.lua):
-- pfQuest starts exactly as it does next to the standalone pfUI.
if not pfQuestOctoSkip then
  pfQuestOctoHidden = { pfUI = pfUI, pfUI_config = pfUI_config }
  pfUI = nil
  pfUI_config = nil

  -- the off switch (Questing page, modules\questing.lua): what pfQuest's files
  -- change is noted here and in restore.lua - the game's functions they replace,
  -- the frames they make, their slash commands - so it can all be put back at
  -- login before anything else starts
  local env = getfenv(0)
  local before, slash, frames = {}, {}, {}
  for k, v in pairs(env) do if type(v) == "function" then before[k] = v end end
  for k in pairs(SlashCmdList or {}) do slash[k] = true end
  local make = CreateFrame
  pfQuestOcto = { before = before, slash = slash, frames = frames, make = make }
  CreateFrame = function(a1, a2, a3, a4)
    local f
    if a4 then f = make(a1, a2, a3, a4) elseif a3 then f = make(a1, a2, a3)
    elseif a2 then f = make(a1, a2) else f = make(a1) end
    table.insert(frames, f)
    return f
  end
end