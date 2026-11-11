-- pfUI Octo: pfQuest's files have run (guard.lua): pfUI back under its name
if pfQuestOctoHidden then
  pfUI = pfQuestOctoHidden.pfUI
  pfUI_config = pfQuestOctoHidden.pfUI_config
  pfQuestOctoHidden = nil
end

-- what pfQuest's files changed, for the off switch (modules\questing.lua)
if pfQuestOcto and pfQuestOcto.make then
  local env = getfenv(0)
  CreateFrame = pfQuestOcto.make
  pfQuestOcto.make = nil
  local changed, newslash = {}, {}
  for k, v in pairs(pfQuestOcto.before) do
    if env[k] ~= v then changed[k] = v end
  end
  for k in pairs(SlashCmdList or {}) do
    if not pfQuestOcto.slash[k] then newslash[k] = true end
  end
  pfQuestOcto.changed, pfQuestOcto.slash, pfQuestOcto.before = changed, newslash, nil
end