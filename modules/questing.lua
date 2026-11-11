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

  -- pfQuest's map data may be used (it is on, built in or standalone)
  function Q.MapOn() return not Q.off and _G.pfMap ~= nil end

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
    -- (11 Nov 2026, Keeyn: with pfQuest switched off, "pfquest\map.lua:34: attempt to index global
    -- 'pfMap' (a nil value)" over and over - a pfQuest script still ticking reads pfMap.) pfMap stays and
    -- is only hidden; the nameplates' quest marks and the farm map check Q.off (pfUI.questing.IsOff).
    -- (pfDB stays: Gathering reads its node lists)
    local map = _G.pfMap
    if map then
      if map.Hide then map:Hide() end
      if map.drawlayer and map.drawlayer.Hide then map.drawlayer:Hide() end
    end
    Q.off = true
  end

  if C.questing.pfquest == "0" then Q.TurnOff() end

  -- (11 Nov 2026, user) lightblade's pfQuest-turtle puts its own quest icons on nameplates
  -- ("nameplatesEnabled"); pfUI Octo's nameplates already mark quest mobs (C.plates.questmark),
  -- so the same mob would get two. Once per character, while ours are in use, theirs go off -
  -- before pfQuest's ADDON_LOADED fills its defaults (this module runs first), so it sticks.
  -- The first character it happens on says so once, with a button to have them back.
  function Q.OursMarkPlates()
    local dis, blizz, plates = C.disabled or {}, C.blizz or {}, C.plates or {}
    return dis.nameplates ~= "1" and blizz.nameplates ~= "1" and plates.questmark == "1"
  end
  function Q.PlateIconsOnce()
    if Q.State() ~= "builtin" or C.questing.turtleplates == "1" then return end
    C.questing.turtleplates = "1"
    if not Q.OursMarkPlates() then return end
    _G.pfQuest_config = _G.pfQuest_config or {}
    if _G.pfQuest_config.nameplatesEnabled == "0" then return end
    _G.pfQuest_config.nameplatesEnabled = "0"
    _G.pfUI_cache = _G.pfUI_cache or {}
    if not _G.pfUI_cache.questplatesnotice then Q.noticeDue = true end
  end
  function Q.Notice()
    _G.pfUI_cache.questplatesnotice = true
    CreateQuestionDialog(T["pfQuest has been updated to the version the OctoWoW launcher installs."] .. "\n\n"
      .. T["It can put its own quest icons on nameplates, but pfUI Octo's nameplates already mark quest mobs, so "
      .. "pfQuest's icons have been switched off to stop two marks showing on the same mob."] .. "\n\n"
      .. "|cffaaaaaa" .. T["You can change this at any time: Questing > pfQuest > Show Quest Icons on Nameplates."] .. "|r",
      { T["OK"], function() end },
      { T["Use pfQuest's icons"], function()
        if _G.pfQuest_config then _G.pfQuest_config.nameplatesEnabled = "1" end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI|r: " .. T["pfQuest's nameplate icons are on again."])
      end })
  end
  Q.PlateIconsOnce()
  if Q.noticeDue then
    -- after login, once no other question box is up (the add-on questions use the same box)
    local wait = CreateFrame("Frame")
    wait:RegisterEvent("PLAYER_ENTERING_WORLD")
    wait:SetScript("OnEvent", function() this.at = GetTime() + 6 end)
    wait:SetScript("OnUpdate", function()
      if not this.at or GetTime() < this.at then return end
      local box = _G.pfQuestionDialog
      if box and box:IsShown() then this.at = GetTime() + 2 return end
      this:SetScript("OnUpdate", nil)
      this:UnregisterAllEvents()
      Q.noticeDue = nil
      Q.Notice()
    end)
  end
end)
