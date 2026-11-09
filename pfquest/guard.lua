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
end