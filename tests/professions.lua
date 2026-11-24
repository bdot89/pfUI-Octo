-- pfUI Octo: the profession windows (modules/professions-octo.lua) and the worn look on the other character windows
-- (charframe.lua CF.DressFrame), run by tests\run.lua. The real windows load on demand in the client: stand-ins here.
local ok = octo_ok
local PO = pfUI.professionsOcto
local CF = pfUI.charframe
ok(PO and PO.Setup and PO.Paint and PO.KINDS.Craft, "professions window loaded (pfUI.professionsOcto)")
ok(CF and CF.DressFrame and CF.PaintFrame and table.getn(CF.OTHERS) >= 5, "the worn look for the other windows")
ok(pfUI_config.charframe.others == "1" and pfUI_config.charframe.prof == "1", "defaults: both on")
if not PO then return end
ok(PO.Icon("Enchanting") == "Interface\\Icons\\Trade_Engraving" and string.find(PO.Icon("Something new"), "Book"), "a profession's picture")

-- a stand-in Enchanting window: the frame, its rows, the client's search box and ticks, the rank bar, the light
local k = PO.KINDS.Craft
local keep = {}
local names = { k.frame, k.list, k.detail, k.rank, k.search, k.mats, k.skill, k.highlight, k.create, k.cancel, k.collapse,
  "GetCraftInfo", "GetCraftDisplaySkillLine", "CRAFTS_DISPLAYED" }
for i = 1, 30 do table.insert(names, k.row .. i) end
for _, n in ipairs(names) do keep[n] = rawget(_G, n) end
local f = CreateFrame("Frame", k.frame, UIParent)
f:SetWidth(676) f:SetHeight(440)
CreateFrame("ScrollFrame", k.list, f)
CreateFrame("ScrollFrame", k.detail, f)
CreateFrame("StatusBar", k.rank, f)
CreateFrame("EditBox", k.search, f)
CreateFrame("CheckButton", k.mats, f)
CreateFrame("CheckButton", k.skill, f)
CreateFrame("Button", k.create, f)
CreateFrame("Button", k.cancel, f)
CreateFrame("Button", k.collapse, f)
_G[k.highlight] = f:CreateTexture(nil, "ARTWORK")
for i = 1, 23 do
  local b = CreateFrame("Button", k.row .. i, f)
  local id = i
  b.GetID = function() return id end
  b:Show()
end
_G.CRAFTS_DISPLAYED = 23
_G.GetCraftInfo = function(i) if i == 1 or i == 6 then return "Boots", nil, "header" end return "Enchant " .. i, nil, "optimal" end
_G.GetCraftDisplaySkillLine = function() return "Enchanting", 225, 225 end
local good, err = pcall(PO.Setup, k)
ok(good and f.octoProf, "the Enchanting window takes the new layout" .. (good and "" or (": " .. tostring(err))))
local sp = _G[k.search].points and _G[k.search].points[1]
ok(sp and sp[2] == f and sp[5] == -56, "(Wolfahrt) the search box sits above the list, not on it")
local lp = _G[k.list].points and _G[k.list].points[1]
ok(lp and lp[5] == -104 and sp[5] > lp[5], "the list starts under the search box")
-- (24 Nov 2026, in game: on Engineering the ticks ran into the filter menus) the ticks sit in the list's column
local mp = _G[k.mats].points and _G[k.mats].points[1]
ok(mp and mp[2] == f and mp[3] == "TOPLEFT" and mp[4] * .8 < 318 and mp[5] * .8 < sp[5] and mp[5] * .8 > lp[5],
  "the Have materials tick sits between the search box and the list, left of the menus")
ok(_G.CRAFTS_DISPLAYED >= 20 and _G[k.row .. _G.CRAFTS_DISPLAYED], "the list fills the window's height with rows")
PO.Paint(k)
-- (24 Nov 2026, in game: the Enchant button was gone) pinned to the window's bottom edge, above the art
local cr = _G[k.create]
local cp = cr.points and cr.points[1]
ok(cp and cp[2] == f and cp[3] == "BOTTOMRIGHT" and cr:IsShown() and cr:GetFrameLevel() > f.octoArt:GetFrameLevel(),
  "the Enchant button sits on the window's bottom edge, above the art")
local b1, b2 = _G[k.row .. 1], _G[k.row .. 2]
ok(b1.octoBar and b1.octoBar:IsShown() and not b2.octoBar:IsShown(), "categories are gold bars, recipes are plain")
ok(f.octoArt and f.octoArt.mark.texture == "Interface\\Icons\\Trade_Engraving", "Enchanting's picture behind the recipe")

-- the worn look on another window
local sb = CreateFrame("Frame", nil, UIParent)
pfUI.api.CreateBackdrop(sb)
local w = CF.DressFrame(sb)
ok(w and w.grime and w.burn and table.getn(w.lines) == 4, "another window gets grime, burnt edges and a bronze line")
pfUI_config.charframe.others = "0"
CF.PaintFrame(sb)
ok(not w.grime:IsShown(), "switched off: plain")
pfUI_config.charframe.others = "1"

for n, v in pairs(keep) do rawset(_G, n, v) end
for _, n in ipairs(names) do if keep[n] == nil then rawset(_G, n, nil) end end
