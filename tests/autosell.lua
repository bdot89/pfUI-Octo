-- pfUI Octo: Always sell / Never sell lists for the vendor auto-sell (modules/autovendor.lua), run by tests\run.lua.
-- 25 Nov 2026, Лев on Discord (Automaton's "Always sell").
local ok = octo_ok
local AV = pfUI.autovendor
ok(AV and AV.Wanted and AV.Toggle and AV.Lists, "auto-sell lists loaded (pfUI.autovendor)")
if not AV then return end
local was = pfUI_cache.autosell
local slotsWas = rawget(_G, "GetContainerNumSlots")
_G.GetContainerNumSlots = function() return 0 end
pfUI_cache.autosell = nil
local grey = "|cff9d9d9d|Hitem:2589:0:0:0|h[Broken Tooth]|h|r"
local white = "|cffffffff|Hitem:4306:0:0:0|h[Silk Cloth]|h|r"
ok(AV.Wanted(grey) and not AV.Wanted(white), "greys are sold, the rest is not")
AV.Toggle(white, "always")
ok(AV.Wanted(white) and AV.Lists().always[4306] == "Silk Cloth", "Always sell: a white item is sold too")
AV.Toggle(grey, "never")
ok(not AV.Wanted(grey) and AV.Lists().never[2589], "Never sell: a grey is kept")
AV.Toggle(white, "never")
ok(not AV.Lists().always[4306] and AV.Lists().never[4306], "an item sits on one list only")
AV.Toggle(white, "never")
ok(not AV.Lists().never[4306], "the same again takes it off")

-- Ctrl + Alt + right-click a bag item = Always sell, not used
local used
local linkWas, ctrlWas, altWas, shiftWas = rawget(_G, "GetContainerItemLink"), rawget(_G, "IsControlKeyDown"), rawget(_G, "IsAltKeyDown"), rawget(_G, "IsShiftKeyDown")
_G.GetContainerItemLink = function() return white end
_G.IsControlKeyDown, _G.IsAltKeyDown, _G.IsShiftKeyDown = function() return 1 end, function() return 1 end, function() return nil end
local env = pfUI.env or {}
local envWas = { rawget(env, "IsControlKeyDown"), rawget(env, "IsAltKeyDown"), rawget(env, "IsShiftKeyDown"), rawget(env, "GetContainerItemLink") }
rawset(env, "IsControlKeyDown", _G.IsControlKeyDown) rawset(env, "IsAltKeyDown", _G.IsAltKeyDown) rawset(env, "IsShiftKeyDown", _G.IsShiftKeyDown) rawset(env, "GetContainerItemLink", _G.GetContainerItemLink)
local took = AV.Intercept(0, 1)
ok(took and AV.Lists().always[4306], "Ctrl + Alt + right-click puts it on Always sell (and does not use it)")
_G.IsControlKeyDown = function() return nil end
_G.GetContainerItemLink, _G.IsControlKeyDown, _G.IsAltKeyDown, _G.IsShiftKeyDown = linkWas, ctrlWas, altWas, shiftWas
rawset(env, "IsControlKeyDown", envWas[1]) rawset(env, "IsAltKeyDown", envWas[2]) rawset(env, "IsShiftKeyDown", envWas[3]) rawset(env, "GetContainerItemLink", envWas[4])
SlashCmdList["PFAUTOSELL"]("purge")
ok(not next(AV.Lists().always), "/sell purge empties Always sell")
pfUI_cache.autosell = was
_G.GetContainerNumSlots = slotsWas
