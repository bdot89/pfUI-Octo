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

-- the error catcher from guard.lua: the handler it found goes back (unless another add-on set its own since)
local loadErrors = pfQuestOctoErrors
pfQuestOctoErrors = nil
if loadErrors and loadErrors.handler and type(seterrorhandler) == "function" and type(geterrorhandler) == "function"
  and geterrorhandler() == loadErrors.handler then
  seterrorhandler(loadErrors.prev)
end

-- (16 Nov 2026) If pfQuest's map still failed to load, its control-key ticker would error twice a second
-- for the whole session. It is stopped, and one chat line at login says so instead.
-- (23 Nov 2026, Mr_Rosh) The same for the quest tracker: a tracker.lua that stopped half way has no DoLayout and
-- its OnUpdate errored ten times a second (tracker.lua:260, before that :282). It is stopped and hidden.
local brokenTracker = type(pfQuestMapTracker) == "table" and rawget(pfQuestMapTracker, "DoLayout") == nil and true or nil
if not pfQuestOctoSkip and brokenTracker and pfQuestMapTracker.SetScript then
  pfQuestMapTracker:SetScript("OnUpdate", nil)
  pfQuestMapTracker:SetScript("OnEvent", nil)
  pfQuestMapTracker:UnregisterAllEvents()
  pfQuestMapTracker:Hide()
end
if not pfQuestOctoSkip and (pfMap == nil or brokenTracker or (loadErrors and loadErrors[1])) then
  if pfMap == nil then
    if pfQuestControlKey and pfQuestControlKey.SetScript then pfQuestControlKey:SetScript("OnUpdate", nil) end
    pfQuestOctoNoMap = true
  end
  local first = loadErrors and loadErrors[1]
  pfQuestOctoLoadError = first
  local tell = CreateFrame("Frame")
  tell:RegisterEvent("PLAYER_ENTERING_WORLD")
  tell:SetScript("OnEvent", function()
    this:UnregisterAllEvents()
    -- kept in pfUI's saved file (WTF\...\SavedVariables\pfUI.lua) so it can be sent in
    if type(pfUI_cache) == "table" then
      pfUI_cache.pfquesterror = first and (date("%Y-%m-%d %H:%M") .. " " .. first) or nil
    end
    if DEFAULT_CHAT_FRAME then
      -- (27 Nov 2026, Kahno: "overwrites.lua:10: attempt to index global pfDB") no database file loaded at all: files
      -- missing from pfUIpfquestdb (a download that stopped, or antivirus) - say what to do, not an error to report
      if pfDB == nil then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r: |cffff6666pfQuest's database files are missing|r from Interface\\AddOns\\pfUI\\pfquest\\db, so quests and map pins are off. "
          .. "Close the game, delete the pfUI folder and install pfUI Octo again (the launcher, or the pfUI.zip download).")
        return
      end
      local what = (pfMap == nil or brokenTracker) and "pfQuest could not fully load, so quest pins or the quest tracker are off."
        or "pfQuest had an error while loading."
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r: " .. what .. (first
        and (" Please report this first error: |cffff6666" .. first .. "|r")
        or " Please report the FIRST red error shown right after logging in."))
    end
  end)
end
-- (27 Nov 2026, Lobo's out-of-memory crash) turtle-patchtable.lua copies Turtle's extra tables into pfQuest's own
-- (items, units, quests, objects, zones... and their enUS names); the "-turtle" copies stayed in memory after that.
-- They are emptied here, only where the table they were merged into exists (their entries live on in it). An empty
-- table stays, so "is Turtle data there" checks (/db version) still work. Nothing is removed from the database.
if not pfQuestOctoSkip and type(pfDB) == "table" then
  for _, t in pairs(pfDB) do
    if type(t) == "table" then
      for k, v in pairs(t) do
        if type(k) == "string" and type(v) == "table" then
          local _, _, base = string.find(k, "^(.+)%-turtle$")
          if base and type(t[base]) == "table" then t[k] = {} end
        end
      end
    end
  end
  for _, k in ipairs({ "minimap", "meta" }) do
    if type(pfDB[k .. "-turtle"]) == "table" and type(pfDB[k]) == "table" then pfDB[k .. "-turtle"] = {} end
  end
end
-- (18 Nov 2026) out-of-memory crashes (#132 in DXVK's d3d9.dll at logins and after /reload): reading pfQuest's 32 MB
-- of data leaves its read-in garbage behind; Lua 5.0 would let it pile up to twice the database before cleaning.
-- Cleaned here once, during the loading screen (gcmid.lua does the same after the base database).
if pfUI_LoadMark then pfUI_LoadMark("pfQuest's data read") end
collectgarbage()
if pfUI_LoadMark then pfUI_LoadMark("pfQuest's clean-up") end
