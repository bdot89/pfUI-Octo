-- pfUI Octo: click casting and Puppeteer (24 Nov 2026, Khijazi), run by tests\run.lua.
-- "Left-click spells also target", and SuperCleveRoidMacros keeping Puppeteer's mouseover.
local ok = octo_ok
local UF = pfUI.uf
ok(UF and UF.ClickAction, "pfUI.uf:ClickAction")
ok(pfUI_config.unitframes.clickcasttarget == "0", "default: a left-click spell leaves your target alone")
if not (UF and UF.ClickAction) then return end

local env = getfenv(UF.ClickAction)
local names = { "CastSpellByName", "TargetUnit", "TargetLastTarget", "UnitIsUnit", "SpellIsTargeting", "CursorHasItem",
  "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown", "superwow_active", "RunMacroText" }
local keepG, keepE = {}, {}
for _, k in ipairs(names) do keepG[k] = rawget(_G, k) keepE[k] = env ~= _G and rawget(env, k) or nil end
local log, target = {}, "party2"
local stubs = {
  CastSpellByName = function(s, u) table.insert(log, "cast " .. s .. (u and (" on " .. u) or "")) end,
  TargetUnit = function(u) target = u table.insert(log, "target " .. u) end,
  TargetLastTarget = function() target = "party2" table.insert(log, "back") end,
  UnitIsUnit = function(a, b) return (a == "target" and b or a) == target end,
  SpellIsTargeting = function() return nil end,
  CursorHasItem = function() return nil end,
  IsAltKeyDown = function() return nil end,
  IsControlKeyDown = function() return nil end,
  IsShiftKeyDown = function() return nil end,
  RunMacroText = function() end,
}
for k, v in pairs(stubs) do _G[k] = v if env ~= _G and rawget(env, k) ~= nil then rawset(env, k, v) end end

local f = { label = "raid", id = 3, clickactions = { LeftButton = "Flash Heal", RightButton = "Renew" } }
local function Click(btn)
  log, target = {}, "party2"
  _G.this = f
  UF:ClickAction(btn)
  return table.concat(log, ", ")
end

-- SuperWoW: the spell goes on the frame's unit
_G.superwow_active = true
if env ~= _G then rawset(env, "superwow_active", true) end
pfUI_config.unitframes.clickcasttarget = "0"
ok(Click("LeftButton") == "cast Flash Heal on raid3" and target == "party2", "SuperWoW, off: cast on them, target kept (" .. table.concat(log, ", ") .. ")")
pfUI_config.unitframes.clickcasttarget = "1"
ok(Click("LeftButton") == "cast Flash Heal on raid3, target raid3" and target == "raid3", "SuperWoW, on: cast, and they are your target")
ok(Click("RightButton") == "cast Renew on raid3" and target == "party2", "on: a right-click spell still leaves the target alone")

-- plain client: target swap for the cast, kept when the switch is on
_G.superwow_active = nil
if env ~= _G then rawset(env, "superwow_active", nil) end
pfUI_config.unitframes.clickcasttarget = "0"
ok(Click("LeftButton") == "target raid3, cast Flash Heal, back" and target == "party2", "no SuperWoW, off: target swapped back")
pfUI_config.unitframes.clickcasttarget = "1"
ok(Click("LeftButton") == "target raid3, cast Flash Heal" and target == "raid3", "no SuperWoW, on: stays on them")

pfUI_config.unitframes.clickcasttarget = "0"
for _, k in ipairs(names) do
  _G[k] = keepG[k]
  if env ~= _G and keepE[k] ~= nil then rawset(env, k, keepE[k]) end
end

-- SuperCleveRoidMacros: a Puppeteer frame under the mouse is a real mouseover (only when the built-in copy loaded)
local CR = rawget(_G, "CleveRoids")
if CR and CR.PuppeteerHover then
  local hadPT, hadUE = rawget(_G, "Puppeteer"), rawget(_G, "UnitExists")
  _G.UnitExists = function(u) return u == "raid5" end
  local fr = { hovered = true, GetResolvedUnit = function() return "raid5" end }
  _G.Puppeteer = { MouseoverFrame = fr }
  ok(CR.PuppeteerHover() == "raid5", "SCRM: Puppeteer's hovered frame counts as the mouseover")
  fr.hovered = false
  ok(CR.PuppeteerHover() == nil, "SCRM: leaving it (hovered off) clears it")
  _G.Puppeteer, _G.UnitExists = hadPT, hadUE
else
  -- the copy needs ClassicAPI 1.15.8+ to load; check the code is there
  local h = io.open("scrm/Utility.lua", "rb") or io.open((rawget(_G, "DIR") or ".") .. "/scrm/Utility.lua", "rb")
  local t = h and h:read("*a") or ""
  if h then h:close() end
  ok(string.find(t, "function CleveRoids.PuppeteerHover", 1, true) and string.find(t, "\"puppeteer\", u", 1, true),
    "SCRM: Puppeteer's hover is a mouseover source (code present)")
end
