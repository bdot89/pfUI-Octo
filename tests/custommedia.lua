-- pfUI Octo: pfUI-CustomMedia built in (modules/custommedia.lua, env/custommedia.lua, W.LongMenu), run by tests\run.lua:
-- every listed file exists, every texture / font / gryphon menu has the entries, long menus scroll and filter.
local ok = octo_ok
local CM = pfUI.custommedia
ok(CM and CM.list and CM.Register, "custom media loaded (pfUI.custommedia)")
if not CM then return end
local L = CM.list
ok(table.getn(L.bars) == 404 and table.getn(L.fonts) == 72 and table.getn(L.gryphons) == 30 and table.getn(L.backgrounds) == 8,
  "the lists: " .. table.getn(L.bars) .. " bars, " .. table.getn(L.fonts) .. " fonts, " .. table.getn(L.gryphons) .. " gryphons, " .. table.getn(L.backgrounds) .. " backgrounds")

-- every file the lists name is in the folder
local function exists(rel)
  local f = io.open(octo_dir .. "/custommedia/" .. rel, "rb")
  if f then f:close() end
  return f ~= nil
end
local missing = {}
for _, n in ipairs(L.bars) do if not exists("statusbars/" .. n .. ".tga") then table.insert(missing, "statusbars/" .. n) end end
for _, f in ipairs(L.fonts) do if not exists("fonts/" .. f[1]) then table.insert(missing, "fonts/" .. f[1]) end end
for _, g in ipairs(L.gryphons) do if not exists("gryphons/" .. g[2] .. ".tga") then table.insert(missing, "gryphons/" .. g[2]) end end
for _, n in ipairs(L.backgrounds) do if not exists("backgrounds/" .. n .. ".tga") then table.insert(missing, "backgrounds/" .. n) end end
ok(table.getn(missing) == 0, "every listed file exists (missing: " .. table.concat(missing, ", ") .. ")")
ok(exists("LICENSE-pfUI-CustomMedia.txt"), "the licence is with the files")

-- the menus have them
local dd = pfUI.gui.dropdowns
local function has(list, needle)
  for _, e in ipairs(list or {}) do if string.find(e, needle, 1, true) then return true end end
  return false
end
ok(has(dd.uf_bartexture, "custommedia\\statusbars\\Glass.tga:Glass"), "bar texture menus have the custom textures")
ok(has(dd.fonts, "custommedia\\fonts\\Lato-Regular.ttf:Lato"), "font menus have the custom fonts")
ok(has(dd.gryphons, "Orc:Orc") and pfUI.gryphons.Art("Orc") and pfUI.gryphons.Art("Orc").custom, "the gryphon list has the custom pictures")
local n1 = table.getn(dd.uf_bartexture)
CM.Register()
ok(table.getn(dd.uf_bartexture) == n1, "registering again adds nothing")

-- the original add-on's doubles go
table.insert(dd.uf_bartexture, "Interface\\AddOns\\pfUI-CustomMedia\\statusbars\\Glass.tga:Glass")
CM.DropOriginal()
ok(not has(dd.uf_bartexture, "AddOns\\pfUI-CustomMedia\\statusbars"), "the original add-on's double of a texture is dropped")

-- long menus scroll and filter
local W = pfUI.octoui.W
local opts = {}
for i = 1, 100 do table.insert(opts, { key = "k" .. i, label = "Item " .. i .. (i == 77 and " special" or "") }) end
local picked
local anchor = CreateFrame("Frame", nil, UIParent)
local m = W.Menu(anchor, opts, 200, function(k) picked = k end)
ok(m.long, "a list of 100 becomes a scrolling menu")
local small = W.Menu(anchor, { { key = "a", label = "A" }, { key = "b", label = "B" } }, 200, function() end)
ok(not small.long, "a short list stays a plain menu")
if m.long then
  m:Show()
  Mock.Run(m, "OnShow")
  local first
  for _, c in ipairs(m.children or m._kids or {}) do if c.opt then first = c break end end
  ok(first ~= nil, "rows are filled in")
end

-- the Octo font menus (W.Fonts) have the custom fonts too, without loading each one to try it
do
  local found
  for _, f in ipairs(W.Fonts()) do if f.label == "Lato" then found = f end end
  ok(found and found.trusted and string.find(found.key, "custommedia", 1, true), "W.Fonts lists the custom fonts")
end

-- pfUI's own dropdown (the old pages): a long list shows 15 rows at a time and filters
do
  local list = {}
  for i = 1, 120 do table.insert(list, { text = "Entry " .. i .. (i == 90 and " rare" or ""), texture = "Interface\\Buttons\\WHITE8X8" }) end
  local dd = pfUI.api.CreateDropDownButton("pfTestLongDrop", UIParent)
  dd:SetMenu(list)
  dd:ShowMenu()
  local shown = 0
  for _, e in ipairs(dd.menuframe.elements) do if e:IsShown() then shown = shown + 1 end end
  ok(dd.menuframe.long and shown == 15 and table.getn(dd.menuframe.elements) == 15, "a list of 120: 15 rows made and shown (" .. shown .. ")")
  dd.menuframe.filter:SetText("rare")
  Mock.Run(dd.menuframe.filter, "OnTextChanged")
  local texts = {}
  for _, e in ipairs(dd.menuframe.elements) do if e:IsShown() then table.insert(texts, e.text:GetText()) end end
  ok(table.getn(texts) == 1 and texts[1] == "Entry 90 rare", "the filter finds it (" .. table.concat(texts, ",") .. ")")
  dd.menuframe.filter:SetText("")
  Mock.Run(dd.menuframe.filter, "OnTextChanged")
  dd.menuframe.offset = 0
  dd.menuframe.wheel()
  dd:HideMenu()
  local short = pfUI.api.CreateDropDownButton("pfTestShortDrop", UIParent)
  short:SetMenu({ { text = "A" }, { text = "B" } })
  short:ShowMenu()
  ok(not short.menuframe.long, "a short list is the plain menu")
  short:HideMenu()
end

-- (8 Nov 2026) the add-on's fonts pfUI already ships are in pfUI's own font menu too
do
  local have = {}
  for _, e in ipairs(pfUI.gui.dropdowns.fonts or {}) do
    local _, _, label = string.find(e, ":([^:]*)$")
    if label then have[label] = true end
  end
  ok(have["Sniglet"] and have["Squada One"] and have["Baloo Bhaina"] and have["Share Bold"], "pfUI's font menu has every font of the add-on")
end

-- the gryphons move in layout mode, and go back on the bar
do
  local G = pfUI.gryphons
  if G and G.ResetPosition then
    ok(pfUI.movables.pfGryphonLeft and pfUI.movables.pfGryphonRight, "both gryphons are layout mode boxes")
    pfUI_config.position.pfGryphonLeft = { anchor = "CENTER", xpos = 10, ypos = 10 }
    G.ResetPosition()
    ok(pfUI_config.position.pfGryphonLeft == nil, "Put back on the bar clears their saved places")
  end
end
