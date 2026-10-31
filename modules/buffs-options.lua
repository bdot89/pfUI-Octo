pfUI:RegisterModule("buffs-options", "vanilla", function ()
  -- pfUI Octo :: the Buffs section (24 Oct 2026; user: "we will work on the
  -- buffs after"). One page instead of pfUI's five Buffs pages, with every
  -- one of their settings: a pinned preview drawn with buff.lua's own
  -- spacing (buffs, debuffs, weapon buffs), a sample buff bar and the totems.
  -- Click a part for its card; Shift + wheel over the icons = their size.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local BO = { bar = "pbuff" }
  pfUI.buffsOcto = BO

  local function B() return C.buffs end
  local function BB() return C.buffbar[BO.bar] end
  local function TT() return C.totems end
  local function Px(v) return v .. " px" end
  local function UB()
    if pfUI.buff and pfUI.buff.UpdateConfig then pcall(pfUI.buff.UpdateConfig, pfUI.buff) end
    if BO.Layout then BO.Layout() end
  end
  local function UT()
    if pfUI.totems and pfUI.totems.UpdateConfig then pcall(pfUI.totems.UpdateConfig, pfUI.totems) end
    if BO.Layout then BO.Layout() end
  end
  -- the buff bars are made at login: a change shows after a reload
  local function UBB()
    BO.reload = true
    if pfUI.gui then pfUI.gui.settingChanged = true end
    if BO.Layout then BO.Layout() end
  end
  local function Chk(p, label, desc, group, key, after) return O.PfChk(p, label, desc, group, key, after) end
  local function Sld(p, label, desc, min, max, step, group, key, after, fmt) return O.PfSld(p, label, desc, min, max, step, group, key, after, fmt) end
  local function Drop(p, label, desc, options, group, key, after)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v) group()[key] = v after() end)
  end
  local function Color(p, label, desc, group, key, after)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      after()
    end)
  end
  local function Col(str)
    local r, g, b, a = GetStringColor(str or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end
  -- pfUI's "key:label" lists
  local function DD(name)
    local out = {}
    local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns[name]
    if type(list) == "function" then list = list() end
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l }) end
    end
    return out
  end

  local BARS = { { key = "pbuff", label = "Your buffs" }, { key = "pdebuff", label = "Your debuffs" },
                 { key = "tdebuff", label = "Target's debuffs" } }
  local CARD = { buffs = "Buffs and debuffs", debuffs = "Buffs and debuffs", weapons = "Weapon buffs",
                 bar = "Buff bars", totems = "Totems" }
  function BO.Open(card)
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("bfbuffs", card) else O:Open("bfbuffs") end
  end

  -- sample auras for the preview (the game's own icons)
  local BUFFS = { "Spell_Holy_WordFortitude", "Spell_Nature_Regeneration", "Spell_Holy_MagicalSentry",
    "Spell_Shadow_AntiShadow", "Spell_Holy_GreaterBlessingofKings", "Spell_Nature_LightningShield",
    "Spell_Holy_PowerWordShield", "Spell_Nature_Rejuvenation", "Spell_Frost_FrostArmor02", "Spell_Holy_SealOfWisdom" }
  local DEBUFFS = { "Spell_Shadow_ShadowWordPain", "Spell_Shadow_CurseOfTounges", "Ability_Creature_Poison_03" }
  local DTYPES = { "Magic", "Curse", "Poison" }
  local WEAPONS = { "INV_Potion_99", "INV_Stone_02" }
  local TOTEMS = { "Spell_Nature_StoneSkinTotem", "Spell_Fire_SearingTotem", "Spell_Frost_SummonWaterElemental",
    "Spell_Nature_InvisibilityTotem" }
  local TIMES = { "58m", "29m", "12m", "9m", "4m", "2m", "55s", "30s", "12s", "4s" }
  local function Icon(n) return "Interface\\Icons\\" .. n end

  -- ---------------------------------------------------------------- preview

  local function Preview(p)
    W.Pin(p, "Preview", "Your buffs, debuffs and weapon buffs as buff.lua lays them out, a buff bar and your totems. "
      .. "Click a part for its settings; hold Shift and scroll the mouse wheel over the icons for bigger or smaller "
      .. "ones. Click this bar to fold it away.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 210)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local parts = {}
      BO.parts = parts

      -- a group of icons (buffs / debuffs / weapons) in its own frame
      local function Group(name, icons)
        local g = CreateFrame("Button", nil, holder)
        g.kind = name
        g.icons = {}
        for i, tex in ipairs(icons) do
          local ic = CreateFrame("Frame", nil, g)
          ic.tex = ic:CreateTexture(nil, "ARTWORK")
          ic.tex:SetAllPoints(ic)
          ic.tex:SetTexture(Icon(tex))
          ic.tex:SetTexCoord(.07, .93, .07, .93)
          ic.edge = ic:CreateTexture(nil, "BACKGROUND")
          ic.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
          ic.edge:SetPoint("TOPLEFT", ic, "TOPLEFT", -1, 1)
          ic.edge:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 1, -1)
          ic.timer = ic:CreateFontString(nil, "OVERLAY")
          ic.timer:SetFont(pfUI.font_default, 10, "OUTLINE")
          ic.timer:SetText(TIMES[i] or "1h")
          g.icons[i] = ic
        end
        g:RegisterForClicks("LeftButtonUp")
        g:SetScript("OnClick", function() BO.Open(CARD[this.kind]) end)
        g:EnableMouseWheel(true)
        g:SetScript("OnMouseWheel", function()
          if IsShiftKeyDown() then
            B().size = tostring(math.max(12, math.min(64, (tonumber(B().size) or 24) + (arg1 or 0))))
            UB()
            O:Refresh()
          elseif pfUI.plates and pfUI.plates.PassWheel then
            pfUI.plates.PassWheel(this)
          end
        end)
        g:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:AddLine(CARD[this.kind])
          GameTooltip:AddLine("Click: its settings", 1, 1, 1)
          GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller icons", 1, 1, 1)
          GameTooltip:Show()
        end)
        g:SetScript("OnLeave", function() GameTooltip:Hide() end)
        parts[name] = g
        return g
      end
      Group("buffs", BUFFS)
      Group("debuffs", DEBUFFS)
      Group("weapons", WEAPONS)

      -- a buff bar (the tab picked on the Buff bars card)
      local bar = CreateFrame("Button", nil, holder)
      bar.kind = "bar"
      bar.bg = bar:CreateTexture(nil, "BACKGROUND")
      bar.bg:SetAllPoints(bar)
      bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      bar.fill = bar:CreateTexture(nil, "ARTWORK")
      bar.fill:SetTexture(pfUI.media and pfUI.media["img:bar"] or "Interface\\TargetingFrame\\UI-StatusBar")
      bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
      bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
      bar.edge = bar:CreateTexture(nil, "BORDER")
      bar.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
      bar.edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
      bar.edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
      bar.icon = bar:CreateTexture(nil, "OVERLAY")
      bar.name = bar:CreateFontString(nil, "OVERLAY")
      bar.name:SetFont(pfUI.font_default, 11, "OUTLINE")
      bar.name:SetPoint("LEFT", bar, "LEFT", 4, 0)
      bar.time = bar:CreateFontString(nil, "OVERLAY")
      bar.time:SetFont(pfUI.font_default, 11, "OUTLINE")
      bar.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
      bar:RegisterForClicks("LeftButtonUp")
      bar:SetScript("OnClick", function() BO.Open(CARD.bar) end)
      bar:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Buff bars")
        GameTooltip:AddLine("Click: its settings", 1, 1, 1)
        GameTooltip:Show()
      end)
      bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
      parts.bar = bar

      -- the totems
      local tot = CreateFrame("Button", nil, holder)
      tot.kind = "totems"
      tot.icons = {}
      for i, tex in ipairs(TOTEMS) do
        local ic = CreateFrame("Frame", nil, tot)
        ic.tex = ic:CreateTexture(nil, "ARTWORK")
        ic.tex:SetAllPoints(ic)
        ic.tex:SetTexture(Icon(tex))
        ic.tex:SetTexCoord(.07, .93, .07, .93)
        ic.bg = ic:CreateTexture(nil, "BACKGROUND")
        ic.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        ic.bg:SetVertexColor(0, 0, 0, .8)
        ic.bg:SetPoint("TOPLEFT", ic, "TOPLEFT", -2, 2)
        ic.bg:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 2, -2)
        tot.icons[i] = ic
      end
      tot:RegisterForClicks("LeftButtonUp")
      tot:SetScript("OnClick", function() BO.Open(CARD.totems) end)
      tot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Totems")
        GameTooltip:AddLine("Click: its settings", 1, 1, 1)
        GameTooltip:Show()
      end)
      tot:SetScript("OnLeave", function() GameTooltip:Hide() end)
      parts.totems = tot

      -- buff.lua's spacing, scaled down to fit the box when needed
      local function Layout()
        local s = B()
        local size = tonumber(s.size) or 24
        local sp = tonumber(s.spacing) or 5
        local fontsize = tonumber(s.fontsize == "-1" and C.global.font_size or s.fontsize) or 12
        local inside = s.textinside == "1"
        local cell = size + 2 * sp
        local rowh = (inside and 0 or fontsize * 1.5) + cell
        local boxw = (box:GetWidth() or 600) - 30
        local function Place(g, n, perRow, shown, top)
          perRow = math.max(1, tonumber(perRow) or 16)
          local cols = math.min(n, perRow)
          local rows = math.ceil(n / perRow)
          local w, h = cols * cell, rows * rowh
          local scale = math.min(1, boxw / math.max(1, w))
          g:SetScale(scale)
          g:SetWidth(w)
          g:SetHeight(h)
          g:ClearAllPoints()
          g:SetPoint("TOPRIGHT", box, "TOPRIGHT", -14 / scale, top / scale)
          for i, ic in ipairs(g.icons) do
            local row = math.floor((i - 1) / perRow)
            local col = i - 1 - row * perRow
            ic:SetWidth(size)
            ic:SetHeight(size)
            ic:ClearAllPoints()
            ic:SetPoint("TOPRIGHT", g, "TOPRIGHT", -col * cell, -row * rowh)
            ic.timer:SetFont(pfUI.font_default, fontsize, "OUTLINE")
            ic.timer:ClearAllPoints()
            if inside then ic.timer:SetPoint("CENTER", ic, "CENTER", 0, 0)
            else ic.timer:SetPoint("TOP", ic, "BOTTOM", 0, -3) end
          end
          g:SetAlpha(shown and 1 or .25)
          return top - h * scale - 6
        end
        local y = Place(parts.buffs, table.getn(BUFFS), s.buffrowsize, s.buffs == "1", -10)
        y = Place(parts.debuffs, table.getn(DEBUFFS), s.debuffrowsize, s.debuffs == "1", y)
        for i, ic in ipairs(parts.debuffs.icons) do
          local c = DebuffTypeColor and DebuffTypeColor[DTYPES[i]]
          ic.edge:SetVertexColor(c and c.r or .8, c and c.g or 0, c and c.b or 0, 1)
        end
        for _, ic in ipairs(parts.buffs.icons) do ic.edge:SetVertexColor(0, 0, 0, 1) end
        for _, ic in ipairs(parts.weapons.icons) do ic.edge:SetVertexColor(.5, 0, 1, 1) end
        if s.separateweapons == "1" then
          Place(parts.weapons, table.getn(WEAPONS), s.wepbuffrowsize, s.weapons == "1", y)
        else
          -- in the buff row, first
          Place(parts.weapons, table.getn(WEAPONS), 2, s.weapons == "1", -10)
          parts.weapons:ClearAllPoints()
          parts.weapons:SetPoint("TOPRIGHT", parts.buffs, "TOPLEFT", -sp, 0)
        end

        -- the buff bar
        local bb = BB()
        local bw = tonumber(bb.width) or -1
        if bw <= 0 then bw = 200 end
        local bh = tonumber(bb.height) or 20
        bar:SetWidth(math.min(bw, boxw * .55))
        bar:SetHeight(bh)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 14 + bh + 2, 14)
        bar.icon:SetWidth(bh)
        bar.icon:SetHeight(bh)
        bar.icon:ClearAllPoints()
        bar.icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
        local sample = BO.bar == "pbuff" and { BUFFS[1], "Power Word: Fortitude", "Magic" }
          or BO.bar == "pdebuff" and { DEBUFFS[2], "Curse of Tongues", "Curse" }
          or { DEBUFFS[1], "Shadow Word: Pain", "Magic" }
        bar.icon:SetTexture(Icon(sample[1]))
        bar.icon:SetTexCoord(.07, .93, .07, .93)
        local dc = DebuffTypeColor and DebuffTypeColor[sample[3]]
        local r, g, b, a = Col(bb.color)
        if bb.dtypebg == "1" and dc then r, g, b = dc.r, dc.g, dc.b end
        bar.bg:SetVertexColor(r * .3, g * .3, b * .3, .8)
        bar.fill:SetVertexColor(r, g, b, a)
        bar.fill:SetWidth(math.max(1, bar:GetWidth() * .62))
        local er, eg, eb, ea = Col(bb.bordercolor)
        if bb.dtypeborder == "1" and dc then er, eg, eb, ea = dc.r, dc.g, dc.b, 1 end
        bar.edge:SetVertexColor(er, eg, eb, ea)
        local tr, tg, tb = Col(bb.textcolor)
        if bb.dtypetext == "1" and dc then tr, tg, tb = dc.r, dc.g, dc.b end
        bar.name:SetTextColor(tr, tg, tb)
        bar.time:SetTextColor(tr, tg, tb)
        bar.name:SetText(sample[2])
        bar.time:SetText("1:42")
        bar:SetAlpha(bb.enable == "1" and 1 or .35)

        -- the totems: a row or a column as set
        local t = TT()
        local tsize = tonumber(t.iconsize) or 26
        local tsp = (tonumber(t.spacing) or 1) * 2 + 2
        local vertical = t.direction == "VERTICAL"
        local n = table.getn(TOTEMS)
        tot:SetWidth(vertical and tsize or n * tsize + (n - 1) * tsp)
        tot:SetHeight(vertical and n * tsize + (n - 1) * tsp or tsize)
        local tscale = math.min(1, 80 / math.max(1, tot:GetHeight()))
        tot:SetScale(tscale)
        tot:ClearAllPoints()
        tot:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -14 / tscale, 14 / tscale)
        for i, ic in ipairs(tot.icons) do
          ic:SetWidth(tsize)
          ic:SetHeight(tsize)
          ic:ClearAllPoints()
          if vertical then ic:SetPoint("TOP", tot, "TOP", 0, -(i - 1) * (tsize + tsp))
          else ic:SetPoint("LEFT", tot, "LEFT", (i - 1) * (tsize + tsp), 0) end
          if t.showbg == "1" then ic.bg:Show() else ic.bg:Hide() end
        end
      end
      BO.Layout = Layout
      Layout()
      if p.items then table.insert(p.items, { Refresh = Layout }) end

      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      local band = W.Row(pp, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r a part  its settings     " .. k .. "Shift + wheel|r  icon size     " .. k .. "Move frames|r  move them")
      W.HowTo(pp, band, how:GetText(), nil, 0)
      W.Buttons(pp, {
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag your buffs, debuffs and bars where you want them." },
        { "Reload for buff bars", function() ReloadUI() end, nil, "The buff bars are made when you log in: switching one on or off shows after a reload.",
          on = function() return BO.reload end },
      })
    end)
  end

  -- ---------------------------------------------------------------- page

  local function Build(p)
    W.Heading(p, "Buffs", { on = O.ModuleSwitch("buff", "Buffs"), about = "Your buffs, debuffs and weapon buffs by the minimap, the buff bars on your unit frames, "
      .. "and your totems. The Blizzard switch above puts the game's own buff frame back." })
    Preview(p)
    -- (31 Oct 2026, user: menus "overwhelming": one card per tab)
    O.CardTabs(p, {
      { "buffs", "Buffs and debuffs", "Spell_Holy_WordFortitude", { CARD.buffs } },
      { "weapons", "Weapon buffs", "INV_Stone_SharpeningStone_01", { CARD.weapons } },
      { "bar", "Buff bars", "INV_Misc_PocketWatch_01", { CARD.bar } },
      { "totems", "Totems", "Spell_Nature_StoneSkinTotem", { CARD.totems } },
    })

    W.Card(p, CARD.buffs, { tip = "The icons next to the minimap." })
    Chk(p, "Show buffs", nil, B, "buffs", UB)
    Chk(p, "Show debuffs", nil, B, "debuffs", UB)
    Sld(p, "Icon size", "Or Shift + wheel over the icons in the preview.", 12, 64, 1, B, "size", UB, Px)
    Sld(p, "Spacing", nil, 0, 20, 1, B, "spacing", UB, Px)
    Sld(p, "Buffs per row", nil, 1, 32, 1, B, "buffrowsize", UB)
    Sld(p, "Debuffs per row", nil, 1, 16, 1, B, "debuffrowsize", UB)
    Chk(p, "Time inside the icon", "Off: under it.", B, "textinside", UB)
    Chk(p, "Hide the tracking buff", "Find Herbs, Find Minerals, Track Beasts... count as buffs on 1.12. On: they stay off the buff bar and your player frame (the tracking button by the map still shows them).", B, "hidetracking", function() UB() if pfUI.uf and pfUI.uf.player and pfUI.uf.player.UpdateConfig then pfUI.uf.player:UpdateConfig() end end)
    Chk(p, "Time left as a sweep", "A clock wipe over each buff as it runs out.", B, "cooldown_anim", UB)
    Chk(p, "Sweep the other way", "The dark part grows as the time runs out (with ClassicAPI).", B, "cooldown_reverse", UB)
    Sld(p, "Text size", "-1 = pfUI's own text size.", -1, 24, 1, B, "fontsize", UB,
      function(v) return v == -1 and "Default" or (v .. " px") end)

    W.Card(p, CARD.weapons, { tip = "Poisons, oils and sharpening stones on your weapons." })
    Chk(p, "Show weapon buffs", nil, B, "weapons", UB)
    Chk(p, "In a row of their own", "Off: first in the buff row.", B, "separateweapons", UB)
    Sld(p, "Per row", nil, 1, 2, 1, B, "wepbuffrowsize", UB)

    W.Card(p, CARD.bar, { tip = "Bars with each aura's time left, on your unit frames. Switching a bar on or off needs a reload." })
    local btns = {}
    for _, e in ipairs(BARS) do
      local key = e.key
      table.insert(btns, { e.label, function() BO.bar = key O:Refresh() if BO.Layout then BO.Layout() end end, nil,
        "Change the " .. string.lower(e.label) .. " bar.", on = function() return BO.bar == key end })
    end
    W.Buttons(p, btns)
    Chk(p, "Show this bar", "Shows after a reload.", BB, "enable", UBB)
    Chk(p, "Unit frame fonts", nil, BB, "use_unitfonts", UBB)
    Drop(p, "Order", nil, DD("buffbarsort"), BB, "sort", UBB)
    Sld(p, "Width", "-1 = as wide as the unit frame.", -1, 400, 1, BB, "width", UBB,
      function(v) return v == -1 and "Frame width" or (v .. " px") end)
    Sld(p, "Height", nil, 8, 40, 1, BB, "height", UBB, Px)
    Color(p, "Bar", nil, BB, "color", UBB)
    Color(p, "Border", nil, BB, "bordercolor", UBB)
    Color(p, "Text", nil, BB, "textcolor", UBB)
    Chk(p, "Bar in the aura's type colour", "Magic blue, curse purple, poison green, disease brown.", BB, "dtypebg", UBB)
    Chk(p, "Border in the aura's type colour", nil, BB, "dtypeborder", UBB)
    Chk(p, "Text in the aura's type colour", nil, BB, "dtypetext", UBB)
    Chk(p, "Colour by stacks", nil, BB, "colorstacks", UBB)
    W.Check(p, "Only your own debuffs", "Target's debuffs only (experimental).", function() return C.buffbar.tdebuff.selfdebuff == "1" end,
      function(v) C.buffbar.tdebuff.selfdebuff = v and "1" or "0" UBB() end)
    Drop(p, "Filter", nil, DD("buffbarfilter"), BB, "filter", UBB)
    Sld(p, "Only under", "Auras with more time left than this are not shown (seconds).", 0, 3600, 10, BB, "threshold", UBB,
      function(v) return v .. " s" end)
    W.Edit(p, "Always show", "Aura names, separated by #.", function() return BB().whitelist or "" end,
      function(v) BB().whitelist = v UBB() end)
    W.Edit(p, "Never show", "Aura names, separated by #.", function() return BB().blacklist or "" end,
      function(v) BB().blacklist = v UBB() end)

    W.Card(p, CARD.totems, { tip = "Your shaman totems with their time left." })
    Drop(p, "Direction", nil, DD("orientation"), TT, "direction", UT)
    Sld(p, "Icon size", nil, 12, 64, 1, TT, "iconsize", UT, Px)
    Drop(p, "Spacing", nil, DD("spacing"), TT, "spacing", UT)
    Chk(p, "Background", nil, TT, "showbg", UT)
    Chk(p, "Sweep the other way", "With ClassicAPI.", TT, "cooldown_reverse", UT)
    O.TabFilter(p)
  end

  -- layout mode's right-click on a buff bar: the page on that bar's tab
  O.tabs = O.tabs or {}
  O.tabs.bfbuffs = function(what)
    for _, e in ipairs(BARS) do if e.key == what then BO.bar = what end end
  end

  O.replaced[T["Buffs"]] = true
  O:AddPage("Buffs", "bfbuffs", "Buffs", Build)
end)
