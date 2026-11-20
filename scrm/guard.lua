-- pfUI Octo: SuperCleveRoidMacros built in (20 Nov 2026, user: "merge the SCRM into this version so it works
-- across all it will fetch over any you had and just carry on working"). tools\Sync-SCRM.ps1 copies it here with
-- a guard line on every file. This copy steps aside when:
--   - a separate SuperCleveRoidMacros (any folder name with "cleveroid" in it) is switched on: it loads after
--     pfUI, so both would run. pfUI switches that one off for the next login, once (chat-less way back: turn it
--     on again in the add-on list and it is left alone - modules\thirdparty-vanilla.lua);
--   - the client has no ClassicAPI 1.15.8 or newer: SuperCleveRoidMacros cannot finish loading without it.
local function pfUIOctoSCRMOther()
  if type(GetNumAddOns) ~= "function" or type(GetAddOnInfo) ~= "function" then return nil end
  local count = GetNumAddOns()
  if type(count) ~= "number" then return nil end
  for i = 1, count do
    local name, _, _, enabled, loadable = GetAddOnInfo(i)
    if name and enabled and loadable then
      local n = string.lower(name)
      if n ~= "pfui" and string.find(n, "cleveroid", 1, true) then return name end
    end
  end
  return nil
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
