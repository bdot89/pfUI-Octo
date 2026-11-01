-- pfUI Octo :: character stats (1 Nov 2026, user: "fully merge the even better
-- character stats into this addon ... so i can delete the other addon folder").
-- The files in this folder are EvenBetterCharacterStats 1.0.0 (bdot89; based on
-- BetterCharacterStats by moh, Bennylava, Lexie, Spit, Pepopo, MarcelineVQ),
-- loaded by pfUI.toc. Its settings stay in BCSConfig (per character).
--
-- The old addon still installed beside it would build a second set of the same
-- frames: it is switched off for the next start, and said once in chat.
if IsAddOnLoaded and IsAddOnLoaded("EvenBetterCharacterStats") then
  if DisableAddOn then DisableAddOn("EvenBetterCharacterStats") end
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function()
    this:UnregisterAllEvents()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffpfUI Octo|r: EvenBetterCharacterStats is built into pfUI Octo now. "
      .. "The separate addon is switched off - /reload, then you can delete its folder.")
  end)
end
