pfUI:RegisterModule("custommedia", "vanilla:tbc", function ()
  -- pfUI Octo :: pfUI-CustomMedia built in (7 Nov 2026; user: "look at the actual media all this should be added like
  -- for like, all our drop downs should have these looks to pick and more"). The add-on is Mr_Rosh's,
  -- github.com/mr-rosh/pfUI-CustomMedia, MIT (custommedia\LICENSE-pfUI-CustomMedia.txt): 404 status bar
  -- textures, 72 fonts, 30 gryphon / end pictures and 8 button backgrounds, now in pfUI\custommedia. The names
  -- are in env\custommedia.lua (tools\MakeCustomMediaList.ps1 makes it).
  --   bars       appended to pfUI.gui.dropdowns.uf_bartexture: unit frames, cast bars, nameplates, meters, swing
  --              timer, XP bar, tooltip - every texture menu, old pages and Octo pages
  --   fonts      appended to pfUI.gui.dropdowns.fonts: every font menu
  --   gryphons   the Gryphons page's list (pfUI.gryphons.art) and the old dropdown
  --   backgrounds  behind action buttons and bag slots (Art page, "Button backgrounds")
  --   static bars  a custom texture keeps its full size while a bar fills (cropped, not squeezed)
  -- Long menus scroll and have a filter box (octo-widgets.lua W.Menu).
  local L = _G.pfUI_customMediaList
  if not L then return end
  local CM = {}
  pfUI.custommedia = CM
  CM.DIR = "Interface\\AddOns\\pfUI\\custommedia\\"
  CM.list = L
  local DIR = CM.DIR

  local function DD(name)
    local g = pfUI.gui
    if not (g and g.dropdowns) then return end
    if type(g.dropdowns[name]) ~= "table" then g.dropdowns[name] = {} end
    return g.dropdowns[name]
  end
  local function Add(list, entry, seen)
    if not list or seen[entry] then return end
    seen[entry] = true
    table.insert(list, entry)
  end

  -- the add-on's fonts that pfUI\fonts already has (not copied twice): file, the add-on's name
  CM.SHARED = {
    { "BalooBhaina.ttf", "Baloo Bhaina" }, { "FiraSansCondensed-Regular.ttf", "Fira Sans Condensed" },
    { "FiraSansCondensed-SemiBold.ttf", "Fira Sans Condensed Semibold" }, { "LondrinaSolid.ttf", "Londrina Solid" },
    { "Roboto.ttf", "Roboto" }, { "Share.ttf", "Share" }, { "ShareBold.ttf", "Share Bold" },
    { "Sniglet.ttf", "Sniglet" }, { "SquadaOne.ttf", "Squada One" },
  }

  -- every list gets the entries once; again is harmless
  function CM.Register()
    local added = 0
    local bars = DD("uf_bartexture")
    if bars then
      local seen = {}
      for _, e in ipairs(bars) do seen[e] = true end
      for _, n in ipairs(L.bars) do
        local e = DIR .. "statusbars\\" .. n .. ".tga:" .. n
        if not seen[e] then Add(bars, e, seen) added = added + 1 end
      end
    end
    local fonts = DD("fonts")
    if fonts then
      local seen = {}
      for _, e in ipairs(fonts) do seen[e] = true end
      for _, f in ipairs(L.fonts) do
        local e = DIR .. "fonts\\" .. f[1] .. ":" .. f[2]
        if not seen[e] then Add(fonts, e, seen) added = added + 1 end
      end
    end
    -- (8 Nov 2026, user: "all drop down menus ... should hold this info") the add-on's nine fonts
    -- pfUI already ships (pfUI\fonts, from OctoBG) join pfUI's own font menu too, under the add-on's names
    if fonts then
      local seen = {}
      for _, e in ipairs(fonts) do seen[e] = true end
      for _, f in ipairs(CM.SHARED) do
        local e = "Interface\\AddOns\\pfUI\\fonts\\" .. f[1] .. ":" .. f[2]
        if not seen[e] then Add(fonts, e, seen) added = added + 1 end
      end
    end
    -- the Octo font menus (combat text, meters, nameplates, action bars) read W.FONTS
    local W = pfUI.octoui and pfUI.octoui.W
    if W and W.FONTS then
      local haveFont = {}
      for _, f in ipairs(W.FONTS) do haveFont[f.key] = true end
      for _, f in ipairs(L.fonts) do
        local key = DIR .. "fonts\\" .. f[1]
        if not haveFont[key] then
          table.insert(W.FONTS, { key = key, label = f[2], font = key, trusted = true })
          added = added + 1
        end
      end
    end
    local gd = DD("gryphons")
    local GR = pfUI.gryphons
    if GR and GR.art then
      local have = {}
      for _, a in ipairs(GR.art) do have[a.key] = true end
      local seen = {}
      for _, e in ipairs(gd or {}) do seen[e] = true end
      for _, g in ipairs(L.gryphons) do
        local path = DIR .. "gryphons\\" .. g[2] .. ".tga"
        if not have[g[1]] then
          table.insert(GR.art, { key = g[1], label = g[1], tex = path, coords = { 0, 1, 0, 1 }, custom = true })
          GR.textures[g[1]] = path
          added = added + 1
        end
        Add(gd, g[1] .. ":" .. g[1], seen)
      end
    end
    return added
  end
  -- (the original add-on, if it is installed too, adds the same names from its own folder: the doubles go)
  function CM.DropOriginal()
    local have = {}
    for _, n in ipairs(L.bars) do have[n] = true end
    for _, f in ipairs(L.fonts) do have[f[2]] = true end
    local lists = { DD("uf_bartexture"), DD("fonts") }
    for _, list in ipairs(lists) do
      local i = 1
      while list and list[i] do
        local e = list[i]
        local _, _, path, label = string.find(e, "^(.-):(.*)$")
        if path and string.find(path, "AddOns\\pfUI-CustomMedia", 1, true) and have[label] then table.remove(list, i) else i = i + 1 end
      end
    end
  end
  CM.Register()

  -- ---------------------------------------------------------- button backgrounds
  -- (the add-on's idea, written for pfUI Octo's settings: C.custommedia.actionbar_texture / _color and bags_...)
  local function G() return C.custommedia end
  CM.BACK = {}
  for _, n in ipairs(L.backgrounds) do table.insert(CM.BACK, { key = n, label = string.upper(string.sub(n, 1, 1)) .. string.sub(n, 2), texture = DIR .. "backgrounds\\" .. n }) end
  local function BackPath(key)
    for _, b in ipairs(CM.BACK) do if b.key == key then return b.texture end end
  end
  local function Colour(s)
    local r, g, b, a = GetStringColor(s or "1,1,1,.5")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end
  local function Paint(frame, tex, r, g, b, a)
    if not frame then return end
    if not frame.cmBack then
      frame.cmBack = frame:CreateTexture(nil, "BACKGROUND")
      frame.cmBack:SetDrawLayer("BACKGROUND", -8)
      frame.cmBack:SetAllPoints(frame)
    end
    if tex then
      frame.cmBack:SetTexture(tex)
      frame.cmBack:SetTexCoord(0, 1, 0, 1)
      frame.cmBack:SetVertexColor(r, g, b, a)
      frame.cmBack:Show()
    else
      frame.cmBack:Hide()
    end
  end
  CM.GROUPS = {
    { "pfActionBarMainButton", 12 }, { "pfActionBarRightButton", 12 }, { "pfActionBarVerticalButton", 12 }, { "pfActionBarLeftButton", 12 },
    { "pfActionBarTopButton", 12 }, { "pfActionBarStanceBar1Button", 12 }, { "pfActionBarStanceBar2Button", 12 },
    { "pfActionBarStanceBar3Button", 12 }, { "pfActionBarStanceBar4Button", 12 }, { "pfActionBarPetButton", 10 },
    { "pfActionBarStancesButton", 10 }, { "pfActionBarPagingButton", 12 },
  }
  function CM.PaintButtons()
    local tex = BackPath(G().actionbar_texture)
    local r, g, b, a = Colour(G().actionbar_color)
    for _, grp in ipairs(CM.GROUPS) do
      for i = 1, grp[2] do Paint(_G[grp[1] .. i], tex, r, g, b, a) end
    end
  end
  function CM.PaintBags()
    local tex = BackPath(G().bags_texture)
    -- (nothing chosen and nothing painted yet: nothing to do on every bag update)
    if not tex and not CM.bagsPainted then return end
    CM.bagsPainted = tex and true or nil
    local r, g, b, a = Colour(G().bags_color)
    for bag = 0, 4 do for slot = 1, 36 do Paint(_G["pfBag" .. bag .. "item" .. slot], tex, r, g, b, a) end end
    if BankFrame and BankFrame:IsShown() then
      for slot = 1, 24 do Paint(_G["pfBag-1item" .. slot], tex, r, g, b, a) end
      for bag = 5, 10 do for slot = 1, 36 do Paint(_G["pfBag" .. bag .. "item" .. slot], tex, r, g, b, a) end end
    end
  end
  function CM.Apply()
    CM.PaintButtons()
    CM.PaintBags()
  end

  -- ----------------------------------------------------------------- static bars
  -- A bar's fill is a texture that shrinks with the value, so a picture with detail is squeezed to fit.
  -- For the custom textures the picture is cropped to the filled share instead, so it stays full size.
  local function Fill(bar)
    local mn, mx
    if bar.GetMinMaxValues then mn, mx = bar:GetMinMaxValues() else mn, mx = bar.min, bar.max end
    local range = mx and mn and mx - mn
    if not range or range <= 0 then return 0 end
    local v
    if bar.min ~= nil then v = bar.val_ or bar.val elseif bar.GetValue then v = bar:GetValue() end
    if not v then return 0 end
    local f = (v - mn) / range
    if f < 0 then return 0 elseif f > 1 then return 1 end
    return f
  end
  local function Crop(bar, texture, vertical)
    if not texture or not texture.GetTexture then return end
    local path = texture:GetTexture()
    local custom = type(path) == "string" and string.find(string.lower(path), "custommedia", 1, true)
    if not custom then
      if bar.cmCropped then bar.cmCropped, bar.cmFrac = nil, nil texture:SetTexCoord(0, 1, 0, 1) end
      return
    end
    local f = Fill(bar)
    if bar.cmCropped and bar.cmFrac == f then return end
    bar.cmCropped, bar.cmFrac = true, f
    if vertical then texture:SetTexCoord(0, 1, 1 - f, 1) else texture:SetTexCoord(0, f, 0, 1) end
  end
  local function Decorate(bar)
    if not bar or bar.cmStatic or not bar.bar or not bar.DisplayValue then return end
    bar.cmStatic = true
    local texture = bar.bar
    local display = bar.DisplayValue
    bar.DisplayValue = function(self, value)
      display(self, value)
      Crop(self, texture, self.mode == "vertical")
    end
    local set = bar.SetStatusBarTexture
    if set then
      bar.SetStatusBarTexture = function(self, a, b, c)
        set(self, a, b, c)
        Crop(self, texture, self.mode == "vertical")
      end
    end
  end
  local function DecorateFrame(f)
    if not f then return end
    if f.hp then Decorate(f.hp.bar) end
    if f.power then Decorate(f.power.bar) end
  end
  if pfUI.uf then
    for _, f in ipairs(pfUI.uf.frames or {}) do DecorateFrame(f) end
    local create = pfUI.uf.CreateUnitFrame
    if type(create) == "function" and not pfUI.uf.cmWrapped then
      pfUI.uf.cmWrapped = true
      pfUI.uf.CreateUnitFrame = function(self, a, b, c, d, e)
        local f = create(self, a, b, c, d, e)
        DecorateFrame(f)
        return f
      end
    end
  end

  -- ----------------------------------------------------------------- events
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("BAG_UPDATE")
  ev:RegisterEvent("BANKFRAME_OPENED")
  ev:SetScript("OnEvent", function()
    local e = _G.event
    if e == "PLAYER_LOGIN" then
      CM.Register()
      CM.DropOriginal()
      for _, f in ipairs(pfUI.uf and pfUI.uf.frames or {}) do DecorateFrame(f) end
    elseif e == "PLAYER_ENTERING_WORLD" then
      this.apply = GetTime() + 1
    elseif e == "BAG_UPDATE" or e == "BANKFRAME_OPENED" then
      CM.PaintBags()
    end
  end)
  ev:SetScript("OnUpdate", function()
    if this.apply and GetTime() >= this.apply then
      this.apply = nil
      CM.Apply()
    end
  end)
end)
