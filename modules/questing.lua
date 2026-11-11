pfUI:RegisterModule("questing", "vanilla:tbc", function ()
  -- pfUI Octo :: the off switch for the pfQuest built into pfUI (9 Nov 2026; user:
  -- "a tab at the side for questing and pfquest should be in there with an option to
  -- turn it off"). pfQuest's files run while pfUI's files load, before the saved
  -- settings exist, so they cannot be skipped. pfquest\guard.lua and restore.lua
  -- note what they change instead (pfQuestOcto: the game's functions they replaced,
  -- every frame they made, their slash commands). This module is the FIRST in
  -- init\modules.xml: with C.questing.pfquest = "0" it puts all of that back before
  -- any other module starts and before pfQuest's own ADDON_LOADED handlers run (pfUI's
  -- frame hears ADDON_LOADED first, and the frames lose their scripts here).
  local Q = {}
  pfUI.questing = Q

  -- "builtin": pfUI's copy is running; "off": pfUI's copy switched off here;
  -- "standalone": the separate pfQuest add-on is loaded, pfUI's copy stood aside;
  -- "none": no pfQuest at all
  function Q.State()
    if Q.off then return "off" end
    if _G.pfQuestOctoSkip then return "standalone" end
    if _G.pfQuestOcto then return "builtin" end
    return "none"
  end

  function Q.TurnOff()
    local o = _G.pfQuestOcto
    if not o or o.done then return end
    o.done = true
    -- the game's own functions back (quest watch, quest log, abandon...)
    for k, v in pairs(o.changed or {}) do _G[k] = v end
    -- pfQuest's frames silent and away (map, tracker, minimap button, browser...)
    for _, f in ipairs(o.frames or {}) do
      if f.UnregisterAllEvents then f:UnregisterAllEvents() end
      if f.SetScript then
        f:SetScript("OnEvent", nil)
        f:SetScript("OnUpdate", nil)
      end
      if f.Hide then f:Hide() end
    end
    -- /db and the other commands would call into a pfQuest that never started
    for k in pairs(o.slash or {}) do _G.SlashCmdList[k] = nil end
    -- quest link colours in chat (compat\client.lua sets each window's AddMessage).
    -- (11 Nov 2026) Take only pfQuest's link out of the chain: pfUI's chat may sit on top
    -- of it (HookAddMessage), and putting the game's AddMessage back went past pfUI's chat
    -- - no times, short channels or class colours.
    for i = 1, (tonumber(_G.NUM_CHAT_WINDOWS) or 7) do
      local cf = _G["ChatFrame" .. i]
      local orig, pq = cf and cf.pfQuestOctoHookAddMessage, cf and cf.pfQuestOctoParse
      if orig and pq then
        if cf.AddMessage == pq then cf.AddMessage = orig
        elseif cf.HookAddMessage == pq then cf.HookAddMessage = orig end
        cf.pfQuestOctoHookAddMessage, cf.pfQuestOctoParse = nil, nil
      end
    end
    -- the nameplates' quest marks and the farm map ask for pfMap: none now
    -- (pfDB stays: Gathering reads its node lists)
    _G.pfMap = nil
    Q.off = true
  end

  if C.questing.pfquest == "0" then Q.TurnOff() end
end)
