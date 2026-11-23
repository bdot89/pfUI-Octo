-- pfUI Octo: SuperCleveRoidMacros built in (20 Nov 2026, user: "merge the SCRM into this version so it works
-- across all it will fetch over any you had and just carry on working"). tools\Sync-SCRM.ps1 copies it here with
-- a guard line on every file. This copy steps aside when:
--   - a separate SuperCleveRoidMacros (any folder name with "cleveroid" in it) is switched on: it loads after
--     pfUI, so both would run. pfUI switches that one off for the next login, once (chat-less way back: turn it
--     on again in the add-on list and it is left alone - modules\thirdparty-vanilla.lua);
--   - the client has no ClassicAPI 1.15.8 or newer: SuperCleveRoidMacros cannot finish loading without it.
-- (21 Nov 2026, Lobo: with the separate SuperCleveRoidMacros on, "latest version wont load ... i turned off the
-- original Supercleveroid and it solved it" - both copies had run, sharing one CleveRoids table.) A copy counts as on
-- when it is enabled; only a game's outright "cannot load" (loadable false / 0) leaves it out - a missing answer no
-- longer does. Both the add-on list and the two usual names are asked.
local function pfUIOctoSCRMOn(name, enabled, loadable)
  if not name or not enabled or enabled == 0 then return false end
  if loadable == false or loadable == 0 then return false end
  local n = string.lower(name)
  return n ~= "pfui" and string.find(n, "cleveroid", 1, true) and true or false
end
pfUIOctoSCRMOn_ = pfUIOctoSCRMOn
local function pfUIOctoSCRMOther()
  if type(GetAddOnInfo) ~= "function" then return nil end
  for _, known in ipairs({ "SuperCleveRoidMacros", "CleveRoidMacros" }) do
    local ok, name, _, _, enabled, loadable = pcall(GetAddOnInfo, known)
    if ok and pfUIOctoSCRMOn(name, enabled, loadable) then return name end
  end
  if type(GetNumAddOns) ~= "function" then return nil end
  local count = GetNumAddOns()
  if type(count) ~= "number" then return nil end
  for i = 1, count do
    local name, _, _, enabled, loadable = GetAddOnInfo(i)
    if pfUIOctoSCRMOn(name, enabled, loadable) then return name end
  end
  return nil
end
-- (safety net) a separate copy that loads anyway after ours: it is switched off for the next login and chat asks for
-- a /reload (the two must never stay mixed); modules\thirdparty-vanilla.lua says it
if type(CreateFrame) == "function" then
  local watch = CreateFrame("Frame")
  watch:RegisterEvent("ADDON_LOADED")
  watch:SetScript("OnEvent", function()
    if not pfUIOctoSCRM or type(arg1) ~= "string" then return end
    local n = string.lower(arg1)
    if n == "pfui" or not string.find(n, "cleveroid", 1, true) then return end
    pfUIOctoSCRMClash = arg1
    if type(DisableAddOn) == "function" then pcall(DisableAddOn, arg1) end
  end)
end
pfUIOctoSCRMStandalone = pfUIOctoSCRMOther()
pfUIOctoSCRMReady = type(CLASSIC_API_VERSION) == "number" and CLASSIC_API_VERSION >= 11508
if pfUIOctoSCRMStandalone then
  pfUIOctoSCRMWhy = "the separate " .. pfUIOctoSCRMStandalone .. " is switched on"
elseif not pfUIOctoSCRMReady then
  pfUIOctoSCRMWhy = "it needs ClassicAPI 1.15.8 or newer"
else
  pfUIOctoSCRMWhy = nil
end
pfUIOctoSCRMSkip = pfUIOctoSCRMWhy ~= nil
pfUIOctoSCRM = not pfUIOctoSCRMSkip
-- (20 Nov 2026, STAB: one of its files stopped part way while loading) the first error from these files while
-- they load is noted for scrm\check.lua, which puts the game's own error handler back afterwards
-- (23 Nov 2026, DaddyWeeds: "Second error ... none seen") only these files run between here and check.lua, so ANY error
-- counts: Lua 5.0 cuts long file names to "...ns\Tooltip\Generic.lua:12:", which dropped the "scrm" this looked for.
if pfUIOctoSCRM and type(geterrorhandler) == "function" and type(seterrorhandler) == "function" then
  pfUIOctoSCRMHandler = geterrorhandler() or false
  pfUIOctoSCRMCatch = function(msg)
    if not pfUIOctoSCRMLoadErr and type(msg) == "string" then pfUIOctoSCRMLoadErr = msg end
    if pfUIOctoSCRMHandler then return pfUIOctoSCRMHandler(msg) end
  end
  seterrorhandler(pfUIOctoSCRMCatch)
end
-- (23 Nov 2026, DaddyWeeds: "I cant move the spells on the action bar") a copy switched off by check.lua left its
-- replacements in place: its PickupAction calls CleveRoids.ClearSlot from the file that had not loaded, so every drag
-- off a bar errored before the game's own PickupAction. Noted here, before any of its files: the game's functions and
-- slash commands, and every frame its files make (CreateFrame is wrapped until check.lua), so a broken copy can be
-- taken out completely (check.lua pfUIOctoSCRMUndo).
if pfUIOctoSCRM then
  pfUIOctoSCRMBefore = {}
  for k, v in pairs(_G) do
    if type(v) == "function" then pfUIOctoSCRMBefore[k] = v end
  end
  pfUIOctoSCRMSlashBefore = {}
  if type(SlashCmdList) == "table" then
    for k, v in pairs(SlashCmdList) do pfUIOctoSCRMSlashBefore[k] = v end
  end
  pfUIOctoSCRMFrames = {}
  -- (wrapped once: run again, it keeps the game's own)
  if type(CreateFrame) == "function" and CreateFrame ~= pfUIOctoSCRMWrap then
    pfUIOctoSCRMCreateFrame = CreateFrame
    pfUIOctoSCRMWrap = function(a, b, c, d)
      local f = pfUIOctoSCRMCreateFrame(a, b, c, d)
      if pfUIOctoSCRMFrames and f then table.insert(pfUIOctoSCRMFrames, f) end
      return f
    end
    CreateFrame = pfUIOctoSCRMWrap
  end
end
