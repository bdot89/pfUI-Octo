pfUI:RegisterModule("cdm-options", "vanilla", function ()
  -- pfUI Octo :: the Cooldowns section (15 Nov 2026, modules/cdm.lua). Its own module so
  -- the section - and its on / off switch - stays when the bars are switched off. One page:
  -- the picked bar as it looks (click an icon = pick it, right-click = quick menu), the bar's
  -- settings, its spells, adding spells and items, and the picked icon's own settings.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local CP = { bar = 1 }
  pfUI.cdmOptions = CP

  local function CD() return pfUI.cdm end
  local function G() return C.cdm end
  local function Again() O:Rebuild("cdmbars") end
  local function Up() if CD() then CD().Changed() end end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  function CP.Bar()
    local bars = CD().Bars()
    if CP.bar > table.getn(bars) then CP.bar = table.getn(bars) end
    if CP.bar < 1 then CP.bar = 1 end
    return bars[CP.bar], bars
  end
  -- the picked icon's entry (on the picked bar)
  function CP.Entry()
    local bar = CP.Bar()
    for _, e in ipairs(bar.spells) do
      if e.name == CP.pick then return e end
    end
  end
  local function Length(cd)
    if not cd then return "" end
    if cd >= 60 then return math.floor(cd / 60 * 10 + .5) / 10 .. " min" end
    return math.floor(cd + .5) .. " sec"
  end

  -- the quick menu of an icon (preview and list)
  function CP.IconMenu(anchor, name)
    local cd = CD()
    local _, bars = CP.Bar()
    local opts = {
      { key = "pick", label = "Its settings" },
      { key = "left", label = "Move earlier" }, { key = "right", label = "Move later" },
    }
    for i, b in ipairs(bars) do
      if i ~= CP.bar then table.insert(opts, { key = "bar" .. i, label = "Move to " .. (b.name or ("Bar " .. i)) }) end
    end
    table.insert(opts, { key = "remove", label = "|cffff6060Remove|r" })
    W.Menu(anchor, opts, 190, function(key)
      if key == "pick" then CP.pick = name
      elseif key == "left" then cd.Shift(name, -1)
      elseif key == "right" then cd.Shift(name, 1)
      elseif key == "remove" then cd.Remove(name) if CP.pick == name then CP.pick = nil end
      else
        local _, _, n = string.find(key, "^bar(%d+)$")
        if n then cd.MoveTo(name, tonumber(n)) end
      end
      Up() Again()
    end)
  end

  local function Preview(p)
    W.Pin(p, "Your bar", "The picked bar with made-up states so every look shows: ready, on cooldown (shade and time), "
      .. "active (green edge and time, with the effect's stacks). Click an icon to pick it; right-click for its menu. "
      .. "Shift + wheel: bigger / smaller icons.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 104)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local legend = holder:CreateFontString(nil, "OVERLAY")
      legend:SetFont(W.UIFont(), 10, "")
      legend:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 12, 8)
      legend:SetTextColor(.6, .6, .62)
      legend:SetText("shade + time = on cooldown   |cff4de066green|r = its effect is on you   corner number = stacks or how many")
      local sample = CreateFrame("Frame", nil, holder)
      local buttons, hots = {}, {}
      local function Make() return CD().NewButton(sample, true) end
      local function Hot(i)
        if hots[i] then return hots[i] end
        local h = CreateFrame("Button", nil, sample)
        h:SetFrameLevel(sample:GetFrameLevel() + 8)
        h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        h:EnableMouseWheel(true)
        h:SetScript("OnClick", function()
          local name = this.name
          if not name or string.find(name, "^Sample ") then return end
          if arg1 == "RightButton" then CP.IconMenu(this, name) return end
          CP.pick = name
          Again()
          if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("cdmbars", "The picked icon") end
        end)
        h:SetScript("OnMouseWheel", function()
          if IsShiftKeyDown() then
            local bar = CP.Bar()
            bar.size = tostring(math.max(16, math.min(72, (tonumber(bar.size) or 36) + (arg1 or 0) * 2)))
            Up()
            O:Refresh()
          elseif pfUI.plates and pfUI.plates.PassWheel then
            pfUI.plates.PassWheel(this)
          end
        end)
        h:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
          GameTooltip:AddLine(this.name or "?")
          GameTooltip:AddLine("Click: its settings.  Right-click: move or remove.", .35, .7, 1)
          GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        hots[i] = h
        return h
      end
      local function Paint()
        local cd = CD()
        local bar = CP.Bar()
        local now = GetTime()
        local rows = cd.Samples(CP.bar, now)
        local n = cd.Layout(sample, buttons, bar, rows, table.getn(rows), Make, now)
        for i = 1, n do
          local h = Hot(i)
          h.name = rows[i].e.name
          h:SetAllPoints(buttons[i])
          h:Show()
          -- the picked icon: a white edge
          if rows[i].e.name == CP.pick then buttons[i]:SetBackdropBorderColor(1, 1, 1, 1) end
        end
        for i = n + 1, table.getn(hots) do hots[i]:Hide() end
        local room = (box:GetWidth() or 600) - 24
        local scale = math.min(1.4, room / math.max(1, sample:GetWidth()), 56 / math.max(1, sample:GetHeight()))
        sample:SetScale(scale)
        sample:ClearAllPoints()
        sample:SetPoint("CENTER", box, "CENTER", 0, 6)
        sample:SetAlpha(tonumber(bar.alpha) or 1)
      end
      CP.PaintPreview = Paint
      holder:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .1
        Paint()
      end)
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end
      W.Buttons(pp, {
        { "Fill again", function()
          G().removed = {}
          local n = CD().Rescan()
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r cooldowns: " .. n .. " added.")
          Up() Again()
        end, nil, "Reads your spell book again and puts every spell with a cooldown on its bar - also the ones you removed." },
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the bars where you want them." },
      })
    end)
  end

  -- every spell of the book that is on no bar (cooldown ones first)
  function CP.SpellMenu()
    local cd = CD()
    local opts = {}
    for k, b in pairs(cd.book) do
      if not cd.Where(b.name) then
        table.insert(opts, { key = b.name, label = b.name .. (b.cd and ("  |cff9a9aa0" .. Length(b.cd) .. "|r") or ""), icon = b.tex, cd = b.cd })
      end
    end
    table.sort(opts, function(a, b)
      if (a.cd ~= nil) ~= (b.cd ~= nil) then return a.cd ~= nil end
      return a.key < b.key
    end)
    return opts
  end
  -- worn and carried items that can be used
  function CP.ItemMenu()
    local cd = CD()
    cd.itemsDirty = true
    local opts = {}
    for k, it in pairs(cd.Items()) do
      local usable = it.inv and (it.inv == 13 or it.inv == 14)
      if not usable then
        -- (the game says "enable" 1 for items with a Use: effect)
        local start, dur, enable
        if it.inv then start, dur, enable = GetInventoryItemCooldown("player", it.inv)
        else start, dur, enable = GetContainerItemCooldown(it.bag, it.slot) end
        usable = (enable == 1) or (dur and dur > 0)
      end
      if usable and not cd.Where(it.name) then
        table.insert(opts, { key = it.name, label = it.name .. (it.inv and "  |cff9a9aa0worn|r" or ""), icon = it.tex })
      end
    end
    table.sort(opts, function(a, b) return a.key < b.key end)
    return opts
  end

  local function Build(p)
    local cd = CD()
    if not cd then
      W.Heading(p, "Cooldown bars", { on = O.ModuleSwitch("cdm", "Cooldown bars"),
        about = "The cooldown bars are switched off. Switch them on and close the options to reload; your bars come back." })
      W.Note(p, "The bars are off. Use the switch at the top right to turn them back on (takes a reload).")
      return
    end
    local bar, bars = CP.Bar()
    W.Heading(p, "Cooldown bars", { on = O.ModuleSwitch("cdm", "Cooldown bars"),
      about = "Bars of your cooldowns, apart from the action bars: each icon shows ready, on cooldown, or active while its "
        .. "effect is on you. They fill by themselves from your spell book - a new spell with a cooldown finds its "
        .. "bar and its place - and you can add any spell, trinket or item." })
    Preview(p)

    -- which bar
    W.Card(p, "Bars", { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", tip = "Up to " .. cd.MAXBARS .. " bars. Pick the one the rest of the page is about." })
    local list = {}
    for ii, b in ipairs(bars) do
      local i = ii
      table.insert(list, { (b.name or ("Bar " .. i)), function() CP.bar = i CP.pick = nil Again() end, nil,
        table.getn(b.spells) .. " on it.", role = "pick", on = function() return CP.bar == i end })
    end
    W.Buttons(p, list)
    W.Buttons(p, {
      { "New bar", function()
        if table.getn(bars) >= cd.MAXBARS then return end
        table.insert(bars, cd.NewBar("Bar " .. (table.getn(bars) + 1), "none"))
        CP.bar = table.getn(bars)
        CP.pick = nil
        Up() Again()
      end, nil, "An empty bar that only holds what you add." },
      { "Delete this bar", function()
        CreateQuestionDialog("Delete the bar \"" .. (bar.name or "?") .. "\"? Its spells can fill in on another bar again.", function()
          table.remove(bars, CP.bar)
          CP.bar, CP.pick = 1, nil
          cd.Fill()
          Up() Again()
        end)
      end, nil, "Asks first." },
    })
    W.Edit(p, "Name", "The bar's name.", function() return bar.name end, function(v)
      if v and v ~= "" then bar.name = v Again() end
    end)
    W.Dropdown(p, "Fills by itself with", "Which of your spells' cooldowns come onto this bar by themselves, now and when you learn new ones.",
      cd.AUTO, function() return bar.auto or "none" end, function(v) bar.auto = v cd.Fill() Up() Again() end)
    W.Check(p, "Keep in order of cooldown length", "Shortest first; a new spell slots in where it belongs. Moving an icon by hand switches this off.",
      function() return bar.sort == "1" end, function(v) bar.sort = v and "1" or "0" if v then cd.Sort(bar) end Up() Again() end)

    W.Card(p, "Layout of " .. (bar.name or "this bar"), { icon = "Interface\\Icons\\INV_Misc_Gear_01", tip = "Size, rows and when the bar shows." })
    local function B() return bar end
    W.Dropdown(p, "Show the bar", nil, cd.SHOW, function() return bar.show or "always" end, function(v) bar.show = v Up() end)
    O.PfSld(p, "Icon size", "Also Shift + wheel on the preview.", 16, 72, 1, B, "size", Up, O.Px)
    O.PfSld(p, "Gap", nil, 0, 12, 1, B, "spacing", Up, O.Px)
    O.PfSld(p, "Icons in a row", nil, 1, 24, 1, B, "per", Up)
    O.PfChk(p, "Downwards", "Icons run down instead of across.", B, "vertical", Up)
    O.PfChk(p, "Centred", "Icons that hide leave no hole: the rest close up round the middle. Off: they close up to the left.", B, "center", Up)
    O.PfSld(p, "Opacity", nil, .1, 1, .05, B, "alpha", Up, Pct)
    O.PfChk(p, "Dark panel behind", nil, B, "bg", Up)
    O.PfChk(p, "Click an icon to use it", "Off: the bar is only a display and the mouse goes through it.", B, "click", Up)

    W.Card(p, "Look of all icons", { icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01", tip = "Shared by every bar." })
    O.PfChk(p, "Time left on the icons", nil, G, "timers", Up)
    O.PfSld(p, "Number size", "Against the icon's size.", .2, .6, .02, G, "textsize", Up, Pct)
    O.PfSld(p, "Icon zoom", "Cuts the icon's own border off.", 0, .25, .01, G, "zoom", Up, Pct)
    W.Color(p, "Edge", nil, function() return cd.Color("bordercolor", .2, .2, .24, 1) end, function(r, g, b, a) G().bordercolor = r .. "," .. g .. "," .. b .. "," .. (a or 1) Up() end)
    W.Color(p, "Active (edge and time)", "While the spell's effect is on you.", function() return cd.Color("activecolor", .3, .9, .4, 1) end,
      function(r, g, b, a) G().activecolor = r .. "," .. g .. "," .. b .. "," .. (a or 1) Up() end)
    W.Color(p, "Glow", nil, function() return cd.Color("glowcolor", 1, .82, .2, 1) end, function(r, g, b, a) G().glowcolor = r .. "," .. g .. "," .. b .. "," .. (a or 1) Up() end)

    -- its spells
    W.Card(p, "On " .. (bar.name or "this bar"), { icon = "Interface\\Icons\\INV_Misc_Book_09",
      tip = "Every spell and item on the bar, in its order. Ones you do not know (yet) take no room on the bar." })
    if table.getn(bar.spells) == 0 then W.Note(p, "Nothing on this bar yet: add spells or items in the next card.") end
    for ii, e in ipairs(bar.spells) do
      local i, en = ii, e
      local st = cd.State(en, GetTime())
      local r = W.Row(p, 26, 0, 2)
      local ic = r:CreateTexture(nil, "ARTWORK")
      ic:SetWidth(22)
      ic:SetHeight(22)
      ic:SetPoint("LEFT", r, "LEFT", 2, 0)
      ic:SetTexCoord(.07, .93, .07, .93)
      ic:SetTexture(st.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
      local name = r:CreateFontString(nil, "OVERLAY")
      name:SetFont(W.UIFont(), 12, "")
      name:SetPoint("LEFT", ic, "RIGHT", 8, 0)
      name:SetWidth(220)
      name:SetJustifyH("LEFT")
      name:SetText(((not st.known) and "|cff777777" or (en.name == CP.pick and "|cffffffff" or "")) .. en.name)
      local what = r:CreateFontString(nil, "OVERLAY")
      what:SetFont(W.UIFont(), 11, "")
      what:SetPoint("LEFT", name, "RIGHT", 6, 0)
      what:SetWidth(200)
      what:SetJustifyH("LEFT")
      what:SetTextColor(.6, .6, .63)
      what:SetText((not st.known) and (en.kind == "item" and "not in your bags" or "not learned") or
        ((en.kind == "item" and "item" or Length(cd.BaseCD(en.name))) .. (en.auto and "   filled in" or "")))
      local del = W.Button(r, "X", 24, 20)
      del:SetPoint("RIGHT", r, "RIGHT", -4, 0)
      if W.Tint then W.Tint(del, "danger") end
      del:SetScript("OnClick", function() cd.Remove(en.name) if CP.pick == en.name then CP.pick = nil end Up() Again() end)
      W.Tip(del, "Remove", "Takes " .. en.name .. " off the bar. It does not fill in again by itself (Fill again brings everything back).")
      local set = W.Button(r, "Settings", 70, 20)
      set:SetPoint("RIGHT", del, "LEFT", -6, 0)
      if W.Tint then W.Tint(set, "pick") end
      set:SetScript("OnClick", function() CP.pick = en.name Again() end)
      W.Tip(set, "Settings", "Glow, sound, when it shows... in the card \"The picked icon\".")
      local dn = W.Button(r, "Down", 46, 20)
      dn:SetPoint("RIGHT", set, "LEFT", -6, 0)
      dn:SetScript("OnClick", function() if cd.Shift(en.name, 1) then Up() Again() end end)
      local up = W.Button(r, "Up", 36, 20)
      up:SetPoint("RIGHT", dn, "LEFT", -4, 0)
      up:SetScript("OnClick", function() if cd.Shift(en.name, -1) then Up() Again() end end)
      W.Tip(up, "Up", "Earlier on the bar. The bar stops sorting itself by cooldown length.")
    end

    W.Card(p, "Add to " .. (bar.name or "this bar"), { icon = "Interface\\Icons\\Spell_ChargePositive",
      tip = "Any spell of your spell book (also ones with no cooldown, to see their effect's time and stacks - Inner Fire), a trinket or an item." })
    local addrow = W.Row(p, 28, 0, 4)
    local spell = W.Button(addrow, "A spell...", 130, 22)
    spell:SetPoint("LEFT", addrow, "LEFT", 2, 0)
    if W.Tint then W.Tint(spell, "pick") end
    spell:SetScript("OnClick", function()
      local opts = CP.SpellMenu()
      if table.getn(opts) == 0 then return end
      local menu = W.LongMenu or W.Menu
      menu(this, opts, 260, function(key)
        cd.Add(CP.bar, key, "spell")
        CP.pick = key
        Up() Again()
      end)
    end)
    W.Tip(spell, "A spell", "Your spell book, the ones with a cooldown first. Type to filter.")
    local item = W.Button(addrow, "A trinket or item...", 150, 22)
    item:SetPoint("LEFT", spell, "RIGHT", 8, 0)
    if W.Tint then W.Tint(item, "pick") end
    item:SetScript("OnClick", function()
      local opts = CP.ItemMenu()
      if table.getn(opts) == 0 then return end
      W.Menu(this, opts, 260, function(key)
        cd.Add(CP.bar, key, "item")
        CP.pick = key
        Up() Again()
      end)
    end)
    W.Tip(item, "A trinket or item", "Your worn trinkets and the usable items in your bags. It is followed by name, wherever it is.")
    W.Edit(p, "By name", "A spell's or item's exact name; Enter adds it. An item if it is in your bags or worn, else a spell.",
      function() return "" end, function(v)
        if not v or v == "" then return end
        cd.itemsDirty = true
        local kind = cd.Items()[cd.Lower(v)] and "item" or "spell"
        if cd.Add(CP.bar, v, kind) then CP.pick = v Up() Again() end
      end, 220)

    -- the picked icon
    local e = CP.Entry()
    W.Card(p, "The picked icon", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
      tip = "Click an icon in the preview (or Settings in the list) to pick it." })
    if not e then
      W.Note(p, "No icon picked: click one in the preview at the top.")
    else
      W.Note(p, "|cffffffff" .. e.name .. "|r", nil, true)
      W.Dropdown(p, "Shows", "Hidden icons leave no hole: the others close up.", cd.WHEN,
        function() return e.when or "always" end, function(v) e.when = v Up() end)
      W.Dropdown(p, "Glow", "In the glow colour of \"Look of all icons\".", cd.GLOWS,
        function() return e.glow or "off" end, function(v) e.glow = v Up() end)
      W.Dropdown(p, "Sound when it comes ready", nil, cd.SOUNDS, function() return e.sound or "" end,
        function(v) e.sound = v cd.PlaySound(v) end)
      W.Check(p, "Grey while on cooldown", nil, function() return e.desat ~= "0" end, function(v) e.desat = v and "1" or "0" Up() end)
      W.Check(p, "Cooldown shade", "The dark part that shrinks away as the cooldown runs.", function() return e.swipe ~= "0" end,
        function(v) e.swipe = v and "1" or "0" Up() end)
      W.Check(p, "Show while its effect is on me", "Green edge, the effect's time left and its stacks instead of the cooldown.",
        function() return e.active ~= "0" end, function(v) e.active = v and "1" or "0" Up() end)
      W.Edit(p, "Effect to watch", "Empty = the buff with the spell's own name. Fill in another buff's exact name when it is called differently "
        .. "(a trinket's effect, a proc).", function() return e.buff or "" end, function(v) e.buff = v or "" Up() end, 220)
      W.Slider(p, "Red numbers under", "The cooldown's time turns red in its last seconds. 0 = never.", 0, 15, 1,
        function() return tonumber(e.thresh) or 3 end, function(v) e.thresh = tostring(v) Up() end, function(v) return v .. " s" end)
      W.Edit(p, "Own picture", "Empty = the spell's. Else a texture path, for example Interface\\Icons\\Spell_Holy_InnerFire.",
        function() return e.icon or "" end, function(v) e.icon = v or "" Up() end, 300)
      local moves = {}
      for i, b in ipairs(bars) do table.insert(moves, { key = tostring(i), label = b.name or ("Bar " .. i) }) end
      W.Dropdown(p, "On bar", "Move it to another bar.", moves, function() return tostring(CP.bar) end, function(v)
        if cd.MoveTo(e.name, tonumber(v)) then CP.bar = tonumber(v) Up() Again() end
      end)
    end
    W.Note(p, "Command: /cdm (this page), /cdm fill (read the spell book again, removed ones too).")
  end

  O:AddPage("Cooldowns", "cdmbars", "Bars", Build)
end)
