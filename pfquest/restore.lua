-- pfUI Octo: pfQuest's files have run (guard.lua): pfUI back under its name
if pfQuestOctoHidden then
  -- (14 Nov 2026, Khijazi: "/db ... clicking on Objects/Items" = browser.lua:532 "attempt to call field
  -- SetButtonFontColor". pfQuest's files ran with a stand-in pfUI (compat\pfUI.lua); what they call later,
  -- on a click, is the real one. Every helper the stand-in has and the real pfUI lacks goes across.)
  local standin, real = pfUI, pfQuestOctoHidden.pfUI
  if type(standin) == "table" and type(standin.api) == "table" and real and type(real.api) == "table" then
    for k, v in pairs(standin.api) do
      if real.api[k] == nil and k ~= "emulated" then real.api[k] = v end
    end
    for _, k in ipairs({ "font_default", "backdrop", "backdrop_small", "backdrop_no_top" }) do
      if real[k] == nil and standin[k] ~= nil then real[k] = standin[k] end
    end
  end
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