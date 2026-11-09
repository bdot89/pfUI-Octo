-- pfUI Octo: when the standalone pfQuest add-on is loaded (it loads before pfUI)
-- it already made pfDB, and every file of this copy returns at its first line
pfQuestOctoSkip = pfDB ~= nil
-- The standalone pfQuest loads BEFORE pfUI, sees no pfUI and draws its windows
-- with its own stand-in (compat\pfUI.lua); pfUI then takes the name over. This
-- copy loads after pfUI's files but before pfUI has its settings, so pfUI is
-- hidden while pfQuest's files run and put back after (restore.lua): pfQuest
-- starts exactly as it does next to the standalone pfUI.
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