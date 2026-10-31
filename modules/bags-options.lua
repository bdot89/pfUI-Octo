pfUI:RegisterModule("bags-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Bags page (25 Oct 2026, modules/bags-octo.lua): every
  -- setting of the Bagnon-style windows, a pinned preview drawn from the
  -- same measures as the real windows (click a bag in it to show / hide its
  -- slots), and buttons to open, sort and re-place the real ones.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local BO = pfUI.bagsOcto
  if not W or not O or not O.AddPage or not BO then return end
  local BP = {}
  pfUI.bagsOctoOptions = BP

  local function G() return C.bagsocto end
  local function Px(v) return v .. " px" end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Up() BO.Refresh() if BP.Draw then BP.Draw() end end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key, Up) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, Up, fmt) end
  local function Color(p, label, desc, key)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(G()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      G()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      Up()
    end)
  end
  BP.WASH = { { key = "class", label = "Class colour" }, { key = "accent", label = "Accent colour" }, { key = "custom", label = "My own colour" } }

  -- ---------------------------------------------------------------- preview

  -- items for an empty preview (pictures from the 1.12 icon set, qualities)
  -- (the third field: the mark it shows - new, junk, quest, start, bad)
  BP.SAMPLE = {
    { "INV_Misc_Rune_01", 1 }, { "INV_Potion_51", 1, "new" }, { "INV_Sword_04", 3, "bad" }, { "INV_Misc_Food_15", 1 },
    { "INV_Chest_Chain_05", 2 }, { "INV_Misc_Gem_Ruby_02", 4, "new" }, { "INV_Misc_Herb_07", 1 }, { "INV_Scroll_03", 1, "quest" },
    { "INV_Misc_Bag_08", 2 }, { "INV_Misc_Bone_HumanSkull_01", 0, "junk" }, { "INV_Misc_Note_01", 1, "start" }, { "INV_Jewelry_Ring_15", 3 },
  }
  -- the sample's marks as the settings show them
  function BP.SampleMarks(flag)
    local s = G()
    local m = {}
    if flag == "new" then m.new = s.glownew == "1" end
    if flag == "junk" then m.junk = s.junk == "1" end
    if (flag == "quest" or flag == "start") and s.quest == "1" then m.quest = flag end
    if flag == "bad" then m.bad = C.appearance.bags.unusable == "1" end
    return m
  end
  BP.SAMPLESIZES = { [0] = 16, [1] = 14, [2] = 14, [3] = 12, [4] = 10, [-2] = 0 }

  -- the bag sizes the preview draws: yours, or a made-up set of bags
  function BP.Sizes()
    local real = BO.Sizes("bags")
    local any = 0
    for _, n in pairs(real) do any = any + n end
    if any > 0 then return real, true end
    return BP.SAMPLESIZES, false
  end

  local function Preview(p)
    W.Pin(p, "Preview", "Your bag window with these settings, drawn from the same measures as the real one (your own "
      .. "items when you carry some). Click a bag in its bag bar to show or hide that bag's slots. Click this bar to fold it "
      .. "away.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 250)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      local win = CreateFrame("Frame", nil, holder)
      local bg = win:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(win)
      bg:SetTexture(.06, .065, .075, 1)
      local edge = {}
      for i = 1, 4 do
        edge[i] = win:CreateTexture(nil, "BORDER")
        edge[i]:SetTexture(0, 0, 0, 1)
      end
      edge[1]:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0) edge[1]:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0) edge[1]:SetHeight(1)
      edge[2]:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, 0) edge[2]:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0) edge[2]:SetHeight(1)
      edge[3]:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0) edge[3]:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, 0) edge[3]:SetWidth(1)
      edge[4]:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0) edge[4]:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0) edge[4]:SetWidth(1)

      local head = CreateFrame("Frame", nil, win)
      head:SetHeight(BO.HEAD)
      local wash = head:CreateTexture(nil, "BACKGROUND")
      wash:SetAllPoints(head)
      local title = BO.Text(head, 12)
      title:SetPoint("LEFT", head, "LEFT", 6, 0)
      local knobs = {}
      for i = 1, 4 do
        local k = head:CreateTexture(nil, "ARTWORK")
        k:SetWidth(14) k:SetHeight(14)
        k:SetTexture(.18, .19, .21, 1)
        k:SetPoint("RIGHT", head, "RIGHT", -3 - (i - 1) * 18, 0)
        knobs[i] = k
      end
      local search = CreateFrame("Frame", nil, win)
      search:SetHeight(BO.SEARCH)
      local sbg = search:CreateTexture(nil, "BACKGROUND")
      sbg:SetAllPoints(search)
      sbg:SetTexture(.03, .03, .035, 1)
      local stext = BO.Text(search, 11)
      stext:SetPoint("LEFT", search, "LEFT", 6, 0)
      stext:SetTextColor(.5, .5, .5)
      stext:SetText(T and T["Search"] or "Search")
      local bar = CreateFrame("Frame", nil, win)
      bar:SetHeight(BO.BAR)
      local bags = {}
      for i, bag in ipairs(BO.ORDER.bags) do
        local b = CreateFrame("Button", nil, bar)
        b:SetWidth(BO.BAR) b:SetHeight(BO.BAR)
        b:SetPoint("LEFT", bar, "LEFT", (i - 1) * (BO.BAR + 4), 0)
        b.bag = bag
        b.edge = b:CreateTexture(nil, "BACKGROUND")
        b.edge:SetAllPoints(b)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(.08, .92, .08, .92)
        b:SetScript("OnClick", function()
          if this.bag == -2 then BO.ToggleBag(-2) else BO.SetHidden(this.bag, not BO.Hidden(this.bag)) end
          Up()
        end)
        b:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:SetText(BO.BagName(this.bag))
          GameTooltip:AddLine("Click: show / hide its slots", 1, 1, 1)
          GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bags[i] = b
      end
      local foot = CreateFrame("Frame", nil, win)
      foot:SetHeight(BO.FOOT)
      local free = BO.Text(foot, 11)
      free:SetPoint("LEFT", foot, "LEFT", 2, 0)
      local money = BO.Text(foot, 11)
      money:SetPoint("RIGHT", foot, "RIGHT", -2, 0)
      local slots = {}

      local function Slot(i)
        if slots[i] then return slots[i] end
        local f = CreateFrame("Frame", nil, win)
        f.edge = f:CreateTexture(nil, "BACKGROUND")
        f.edge:SetAllPoints(f)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
        f.icon:SetTexCoord(.08, .92, .08, .92)
        f.glow = f:CreateTexture(nil, "OVERLAY")
        f.glow:SetTexture(BO.ICON.glow)
        f.glow:SetBlendMode("ADD")
        f.glow:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.junk = f:CreateTexture(nil, "OVERLAY")
        f.junk:SetTexture(BO.ICON.junk)
        f.junk:SetWidth(13) f.junk:SetHeight(13)
        f.junk:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.quest = f:CreateTexture(nil, "OVERLAY")
        f.quest:SetWidth(13) f.quest:SetHeight(13)
        f.quest:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -1)
        slots[i] = f
        return f
      end

      -- one preview slot's marks, painted like the real ones
      local function PaintMarks(f, m)
        f.glow:SetWidth(m.size * 1.75)
        f.glow:SetHeight(m.size * 1.75)
        if m.new then
          local r, g, b = GetStringColor(G().newcolor)
          f.glow:SetVertexColor(tonumber(r) or 1, tonumber(g) or .85, tonumber(b) or .3, 1)
          f.glow:Show()
        else
          f.glow:Hide()
        end
        if m.junk then f.junk:Show() else f.junk:Hide() end
        if m.quest then f.quest:SetTexture(BO.ICON[m.quest]) f.quest:Show() else f.quest:Hide() end
        if m.bad then
          local r, g, b = GetStringColor(C.appearance.bags.unusable_color)
          f.icon:SetVertexColor(tonumber(r) or .9, tonumber(g) or .2, tonumber(b) or .2)
        else
          f.icon:SetVertexColor(1, 1, 1)
        end
      end

      local function Draw()
        local s = G()
        local sizes, real = BP.Sizes()
        local m = BO.Metrics("bags", sizes)
        local bw, bh = (box:GetWidth() or 760), (box:GetHeight() or 250)
        local k = math.min(1, (bw - 20) / m.w, (bh - 16) / m.h)
        win:SetScale(k)
        win:SetWidth(m.w)
        win:SetHeight(m.h)
        win:ClearAllPoints()
        win:SetPoint("CENTER", holder, "CENTER", 0, 0)
        bg:SetAlpha(tonumber(s.bgalpha) or .92)
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", win, "TOPLEFT", m.pad, -m.headY)
        head:SetPoint("TOPRIGHT", win, "TOPRIGHT", -m.pad, -m.headY)
        local r, g, b = BO.Wash("bags")
        BO.PaintWash(wash, r, g, b, .4)
        title:SetText((UnitName("player") or "") .. "'s bags")
        if s.title == "1" then title:Show() else title:Hide() end
        knobs[3]:SetAlpha(s.sortbtn == "1" and 1 or 0)
        if m.searchY then
          search:ClearAllPoints()
          search:SetPoint("TOPLEFT", win, "TOPLEFT", m.pad, -m.searchY)
          search:SetPoint("TOPRIGHT", win, "TOPRIGHT", -m.pad, -m.searchY)
          search:Show()
        else
          search:Hide()
        end
        if m.barY then
          bar:ClearAllPoints()
          bar:SetPoint("TOPLEFT", win, "TOPLEFT", m.pad, -m.barY)
          bar:SetWidth(m.w - 2 * m.pad)
          bar:Show()
          for _, bt in ipairs(bags) do
            local off = (bt.bag == -2 and not pfUI.bag.showKeyring) or (bt.bag ~= -2 and BO.Hidden(bt.bag))
            bt.icon:SetTexture(real and BO.BagIcon(bt.bag) or (bt.bag == 0 and "Interface\\Buttons\\Button-Backpack-Up" or
              (bt.bag == -2 and "Interface\\Icons\\INV_Misc_Key_03" or "Interface\\Icons\\INV_Misc_Bag_08")))
            bt.icon:SetAlpha(off and .4 or 1)
            if off then bt.edge:SetTexture(.95, .3, .3, 1) else bt.edge:SetTexture(.25, .85, .4, .9) end
          end
        else
          bar:Hide()
        end
        for _, f in pairs(slots) do f:Hide() end
        local n = table.getn(BP.SAMPLE)
        for i, e in ipairs(m.places) do
          local f = Slot(i)
          f:ClearAllPoints()
          f:SetPoint("TOPLEFT", win, "TOPLEFT", m.pad + e.col * (m.size + m.gap), -(m.gridY + e.row * (m.size + m.gap)))
          f:SetWidth(m.size)
          f:SetHeight(m.size)
          local tex, q
          local marks = {}
          if real then
            local t, _, _, quality = GetContainerItemInfo(e.bag, e.slot)
            tex, q = t, quality
            if t then marks = BO.Marks(e.bag, e.slot) end
          elseif math.mod(i * 7, 5) ~= 0 then
            local smp = BP.SAMPLE[math.mod(i - 1, n) + 1]
            tex, q = "Interface\\Icons\\" .. smp[1], smp[2]
            marks = BP.SampleMarks(smp[3])
          end
          marks.size = m.size
          PaintMarks(f, marks)
          if tex then
            f.icon:SetTexture(tex)
            f.icon:Show()
            local qr, qg, qb = .5, .5, .5
            if q and q > 1 and GetItemQualityColor then qr, qg, qb = GetItemQualityColor(q) end
            f.edge:SetTexture(qr, qg, qb, 1)
          else
            f.icon:Hide()
            f.edge:SetTexture(1, 1, 1, .2)
          end
          f:Show()
        end
        if m.footY then
          foot:ClearAllPoints()
          foot:SetPoint("TOPLEFT", win, "TOPLEFT", m.pad, -m.footY)
          foot:SetPoint("TOPRIGHT", win, "TOPRIGHT", -m.pad, -m.footY)
          foot:Show()
          local total, used = table.getn(m.places), 0
          for i = 1, total do if slots[i] and slots[i].icon:IsShown() then used = used + 1 end end
          free:SetText(string.format("|cff40d966%d|r |cff999aa6/ %d free|r", total - used, total))
          if s.free == "1" then free:Show() else free:Hide() end
          money:SetText(CreateGoldString(real and GetMoney() or 1234567))
          if s.money == "1" then money:Show() else money:Hide() end
        else
          foot:Hide()
        end
      end
      BP.Draw = Draw
      holder:SetScript("OnShow", Draw)
      -- the new-item glow breathes as on the real slots
      holder:SetScript("OnUpdate", function()
        local a = .55 + .45 * math.sin(GetTime() * 4)
        for _, f in pairs(slots) do if f.glow:IsShown() then f.glow:SetAlpha(a) end end
      end)
      Draw()

      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      local band = W.Row(pp, 20, 0, 3)
      local hb = band:CreateTexture(nil, "BACKGROUND")
      hb:SetAllPoints(band)
      hb:SetTexture("Interface\\Buttons\\WHITE8X8")
      hb:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local kc = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(kc .. "Click|r a bag  show / hide its slots     " .. kc .. "Drag|r a real window's title  move it     "
        .. kc .. "Right-click|r its title  this page")
      W.HowTo(pp, band, how:GetText(), nil, 0)
      W.Buttons(pp, {
        { "Open my bags", function() if ToggleBackpack then ToggleBackpack() end end, nil, "Shows or hides your real bag window." },
        { "Sort my bags", function()
          if pfUI.api.libbagsort then pfUI.api.libbagsort:Sort("bags") end
        end, nil, "Sorts your bags (instantly with ClassicAPI, else one item at a time).", role = "go" },
        { "Reset positions", function() BO.ResetPlaces() Draw() end, nil, "Puts both windows back where they start." },
      })
    end)
  end

  -- ---------------------------------------------------------------- page

  local function Build(p)
    W.Heading(p, "Bags", { on = O.KeySwitch(G, "enable", "Bagnon-style bag and bank windows on or off (off takes a reload: "
      .. "pfUI's own bag look comes back).", function(v)
        if v then BO.Refresh() else pfUI.gui.settingChanged = true end
      end),
      about = "One window for all your bags and one for the bank, in the Octo look: a title bar to drag them by, a search "
      .. "box, a bag bar that shows or hides each bag's slots, free slots and money at the bottom, and a sort button. "
      .. "Bagnon's ideas, written fresh for 1.12 on pfUI's own bag slots. Bank bags not bought yet show red in the bank's "
      .. "bag bar: click one at the banker to buy it." })
    Preview(p)
    -- (31 Oct 2026, user: menus "overwhelming")
    O.CardTabs(p, {
      { "window", "Window", "INV_Misc_Bag_08", { "Window", "What it shows", "Title bar colour" } },
      { "slots", "Slots and bags", "INV_Misc_Bag_10", { "Slot order", "Which bags" } },
      { "marks", "Item marks", "INV_Misc_Gem_Ruby_02", { "Item marks" } },
    })

    W.Card(p, "Window", { icon = "Interface\\Icons\\INV_Misc_Bag_08", tip = "Size and shape of both windows." })
    Sld(p, "Bag columns", "Slots per row in the bag window.", 4, 24, 1, "columns")
    Sld(p, "Bank columns", "Slots per row in the bank window.", 4, 30, 1, "bankcolumns")
    Sld(p, "Slot size", nil, 20, 48, 1, "size", Px)
    Sld(p, "Spacing", "Gap between slots.", 0, 10, 1, "spacing", Px)
    Sld(p, "Scale", nil, .5, 1.5, .05, "scale", Pct)
    Sld(p, "Background opacity", nil, 0, 1, .05, "bgalpha", Pct)
    Chk(p, "Lock position", "The windows no longer move when dragged.", "locked")

    W.Card(p, "What it shows", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", tip = "Parts of the windows, each on or off." })
    Chk(p, "Title", "Your name in the title bar.", "title")
    Chk(p, "Search box", "Type to dim every item that does not match (names and tooltip text).", "search")
    Chk(p, "Bag bar", "A button per bag: click to show or hide its slots, drag to move the bag. The arrow in the title bar toggles it too.", "bagbar")
    Chk(p, "Free slots", "Free / all slots at the bottom (red when full, gold when nearly).", "free")
    Chk(p, "Money", "Your gold at the bottom of the bag window.", "money")
    Chk(p, "Sort button", "Sorts the window's items: instantly with ClassicAPI, else one item at a time.", "sortbtn")

    W.Card(p, "Item marks", { icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_02", tip = "Small marks on items so you can see at a glance what is new, junk, for a quest or no use to you." })
    Chk(p, "New item glow", "A breathing glow on items you got since you logged in (looted, bought, made, from mail or "
      .. "a trade). Mouse over an item and its glow stops. With ClassicAPI the client marks them itself; without it, an "
      .. "item counts as new when you had none of it a moment before.", "glownew")
    Color(p, "Glow colour", nil, "newcolor")
    Chk(p, "Clear when the bags close", "Closing your bag window stops every glow. Off: they glow until you mouse over them.", "newclear")
    Chk(p, "Junk coin", "A coin on grey (poor) items: the ones a vendor buys for scrap.", "junk")
    Chk(p, "Quest marks", "A ? on quest items, a yellow ! on items that start a quest.", "quest")
    W.Check(p, "Red tint on items you can't use", "Gear you can't wear and items you can't use show red (pfUI's tooltip check; "
      .. "ClassicAPI answers first when you have it). Switching it on without ClassicAPI takes a reload.",
      function() return C.appearance.bags.unusable == "1" end, function(v)
        C.appearance.bags.unusable = v and "1" or "0"
        pfUI.gui.settingChanged = true
        Up()
      end)
    W.Buttons(p, { { "Clear new items", function() BO.ClearNew() Up() end, nil, "Stops every new-item glow now." } })

    W.Card(p, "Slot order", { icon = "Interface\\Icons\\INV_Misc_Note_01", tip = "How the slots fill the grid." })
    Chk(p, "Each bag on a new row", "Every bag starts its own row, so you can tell them apart.", "bagbreak")
    Chk(p, "Last slot first", "Reverses the order: the last bag's last slot comes first.", "reverse")

    W.Card(p, "Which bags", { icon = "Interface\\Icons\\INV_Misc_Bag_10", tip = "Hidden bags keep their items; their slots are just not drawn. Same as clicking them in the bag bar." })
    local function BagTick(bag, label)
      return { label, function() return not BO.Hidden(bag) end, function(v) BO.SetHidden(bag, not v) Up() end,
        "Show this bag's slots." }
    end
    W.Toggles(p, { BagTick(0, "Backpack"), BagTick(1, "Bag 1"), BagTick(2, "Bag 2"), BagTick(3, "Bag 3"), BagTick(4, "Bag 4") })
    W.Toggles(p, { BagTick(-1, "Bank"), BagTick(5, "Bank bag 1"), BagTick(6, "Bank bag 2"), BagTick(7, "Bank bag 3") })
    W.Toggles(p, { BagTick(8, "Bank bag 4"), BagTick(9, "Bank bag 5"), BagTick(10, "Bank bag 6") })

    W.Card(p, "Title bar colour", { icon = "Interface\\Icons\\INV_Fabric_Silk_02", tip = "A soft wash of colour behind each window's title." })
    W.Dropdown(p, "Bag window", nil, BP.WASH, function() return G().wash end, function(v) G().wash = v Up() end)
    Color(p, "Bag window: my own colour", "Used when the bag window is set to My own colour.", "washcolor")
    W.Dropdown(p, "Bank window", nil, BP.WASH, function() return G().bankwash end, function(v) G().bankwash = v Up() end)
    Color(p, "Bank window: my own colour", "Used when the bank window is set to My own colour.", "bankwashcolor")
    O.TabFilter(p)
  end

  O:AddPage("Bags", "bagsocto", "Bags", Build)
end)
