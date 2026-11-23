-- pfUI Octo: after the built-in SuperCleveRoidMacros has loaded (last in scrm.xml; written by hand, kept by
-- tools\Sync-SCRM.ps1). (20 Nov 2026, STAB: "scrm\Core.lua:5312: attempt to call field 'IndexActionSlot' (a nil value)"
-- over and over: in his client one of its files stopped part way while loading, so every action bar change errored.)
-- If a part it cannot run without is missing, it is switched off - no error flood - and one chat line at login says
-- what is missing and the first error seen while its files loaded (scrm\guard.lua notes it), to be sent to us.
if pfUIOctoSCRMSkip then return end
pfUIOctoSCRMNEED = { "IndexActionSlot", "IndexActionBars", "ClearAction", "GetAction", "RegisterExtension", "TestForActiveAction" }
function pfUIOctoSCRMCheck(CR)
  local missing = {}
  for _, n in ipairs(pfUIOctoSCRMNEED) do
    if not (type(CR) == "table" and type(CR[n]) == "function") then table.insert(missing, n) end
  end
  if table.getn(missing) == 0 then return nil end
  return table.concat(missing, ", ")
end
pfUIOctoSCRMBroken = pfUIOctoSCRMCheck(rawget(_G, "CleveRoids"))
-- the error catcher and the CreateFrame wrapper put on by guard.lua are not needed any more
if pfUIOctoSCRMHandler ~= nil and type(seterrorhandler) == "function" and geterrorhandler() == pfUIOctoSCRMCatch then
  seterrorhandler(pfUIOctoSCRMHandler)
end
if pfUIOctoSCRMCreateFrame then CreateFrame = pfUIOctoSCRMCreateFrame end
-- (23 Nov 2026, DaddyWeeds) a broken copy is taken out completely: every game function and slash command its files
-- replaced goes back to the game's own (its PickupAction stopped spells being dragged off the bars), and every frame
-- its files made stops listening. Its own new globals (CleveRoids, its slash commands' SLASH_ names) stay harmless.
function pfUIOctoSCRMUndo()
  local before, put = pfUIOctoSCRMBefore, 0
  if type(before) == "table" then
    for k, v in pairs(before) do
      if rawget(_G, k) ~= v then _G[k] = v put = put + 1 end
    end
  end
  local slash = pfUIOctoSCRMSlashBefore
  if type(slash) == "table" and type(SlashCmdList) == "table" then
    local now = {}
    for k, v in pairs(SlashCmdList) do now[k] = v end
    for k, v in pairs(now) do
      if slash[k] ~= v then SlashCmdList[k] = slash[k] put = put + 1 end
    end
  end
  for _, f in ipairs(pfUIOctoSCRMFrames or {}) do
    if type(f) == "table" then
      if f.UnregisterAllEvents then f:UnregisterAllEvents() end
      if f.SetScript then pcall(f.SetScript, f, "OnUpdate", nil) end
      if f.Hide then f:Hide() end
    end
  end
  return put
end
if pfUIOctoSCRMBroken then
  local CR = rawget(_G, "CleveRoids")
  if type(CR) == "table" and type(CR.Frame) == "table" and CR.Frame.UnregisterAllEvents then CR.Frame:UnregisterAllEvents() end
  pfUIOctoSCRMUndo()
  -- (its "loaded" flag off: pfUI's bars read macros again and macrotweak comes back)
  SRCM_LOADED = nil
  pfUIOctoSCRM, pfUIOctoSCRMSkip = false, true
  local what, first = pfUIOctoSCRMBroken, pfUIOctoSCRMLoadErr
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    this:UnregisterAllEvents()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: the built-in SuperCleveRoidMacros did not load fully, so it is off "
      .. "for now (missing " .. tostring(what) .. "). First error while loading: " .. tostring(first or pfUIOctoSCRMLoadErr or "none seen")
      .. ". Please send this line to the pfUI Octo Discord.")
  end)
end
-- what guard.lua noted is only needed above
pfUIOctoSCRMBefore, pfUIOctoSCRMSlashBefore, pfUIOctoSCRMFrames = nil, nil, nil
