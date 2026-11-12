pfUI:RegisterModule("macrotweak", "vanilla", function ()
  -- octo (12 Nov 2026, Geekoi on Discord: "#showtooltip Ambush / /cast Pick Pocket / /cast Ambush" froze the game
  -- with SuperCleveRoidMacros, fine without pfUI). SuperCleveRoidMacros has its own /use, /equip and #showtooltip
  -- filter and expects this module to stand aside (other pfUI forks do the same); with both, every macro line went
  -- through two SendChatMessage hooks, two /use handlers and pfUI's history hook. pfUI loads before it, so the check
  -- waits for PLAYER_LOGIN (every add-on loaded by then); SRCM_LOADED is its own flag, set whatever its folder is named.
  local function Other()
    return _G.SRCM_LOADED or type(_G.CleveRoids) == "table" or (IsAddOnLoaded and IsAddOnLoaded("SuperCleveRoidMacros"))
      or _G.SuperMacroFrame or (IsAddOnLoaded and IsAddOnLoaded("UltimaMacros"))
  end
  pfUI.macrotweak = { Other = Other }

  local function Setup()
  if Other() then pfUI.macrotweak.off = true return end
  pfUI.macrotweak.on = true

  -- do not write macro calls into chat input history
  if ChatFrameEditBox._AddHistoryLine then
    local userinput
    ChatFrameEditBox._AddHistoryLine = ChatFrameEditBox.AddHistoryLine
    ChatFrameEditBox.AddHistoryLine = function(self, text)
      if not userinput and text and string.find(text, "^/run(.+)") then return end
      if not userinput and string.find(text, "^/script(.+)") then return end
      if not userinput and string.find(text, "^/cast(.+)") then return end
      ChatFrameEditBox._AddHistoryLine(self, text)
    end

    local OnEnter = ChatFrameEditBox:GetScript("OnEnterPressed")
    ChatFrameEditBox:SetScript("OnEnterPressed", function(a1,a2,a3,a4)
      userinput = true
      OnEnter(a1,a2,a3,a4)
      userinput = nil
    end)
  end

  -- make sure #showtooltip inside macros won't be sent
  local hookSendChatMessage = SendChatMessage
  function _G.SendChatMessage(msg, ...)
    if msg and string.find(msg, "^#showtooltip ") then return end
    hookSendChatMessage(msg, unpack(arg))
  end

  -- add /use and /equip to the macro api:
  -- https://wowwiki.fandom.com/wiki/Making_a_macro
  -- supported arguments:
  --   /use <itemname>
  --   /use <inventory slot>
  --   /use <bag> <slot>
  pfUI.api.RegisterSlashCommand("PFUSE", { "/equip" , "/use", "/pfequip", "/pfuse" }, function (msg)
    if not msg or msg == "" then return end
    local bag, slot, _
    if string.find(msg, "%d+%s+%d+") then
      _, _, bag, slot = string.find(msg, "(%d+)%s+(%d+)")
    elseif string.find(msg, "%d+") then
      _, _, slot = string.find(msg, "(%d+)")
    else
      bag, slot = FindItem(msg)
    end

    if bag and slot then
      UseContainerItem(bag, slot)
    elseif not bag and slot then
      UseInventoryItem(slot)
    end
  end)
  end

  if Other() then pfUI.macrotweak.off = true return end
  local wait = CreateFrame("Frame")
  wait:RegisterEvent("PLAYER_LOGIN")
  wait:RegisterEvent("PLAYER_ENTERING_WORLD") -- also there when the module starts after login
  wait:SetScript("OnEvent", function()
    if wait.done then return end
    wait.done = true
    wait:UnregisterAllEvents()
    Setup()
  end)
end)
