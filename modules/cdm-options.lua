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
  -- a list menu under a button, SHOWN (W.Menu / W.LongMenu hand it back hidden: 15 Nov 2026, user:
  -- "these buttons do nothing"); long = with the filter box and scroll bar
  function CP.Pop(anchor, opts, width, long, onPick)
    if W.CloseMenus then W.CloseMenus() end
    local make = (long and W.LongMenu) or W.Menu
    local m = make(anchor, opts, width, onPick)
    if m and m.Show then m:Show() end
    return m
  end
  local function Length(cd)
    if not cd then return "" end
    if cd >= 60 then return math.floor(cd / 60 * 10 + .5) / 10 .. " min" end
    return math.floor(cd + .5) .. " sec"
  end

  -- the quick menu of an icon (preview and list)
  function CP.IconMenu(anchor, name)
    return CP.OpenMenu(anchor, name)
  end

  -- An icon's right-click menu (15 Nov 2026; user, of EllesmereUI's: "add all the options ...
  -- a drop down box this should do all the same everything identical"): Remove Spell, then a
  -- line per option of pfUI.cdm.SPEC that opens its choices beside it, Replace with Buff,
  -- Talent Conditions, Add Custom Icon; under a rule, moving it. Picks apply at once and the
  -- menu stays open; the preview runs that icon through ready / cooldown / active meanwhile.
  local ROW, MW, SW = 20, 216, 236
  local function Panel(w)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    f:SetWidth(w)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(.07, .07, .09, .98)
    f:SetBackdropBorderColor(.28, .28, .33, 1)
    f:EnableMouse(true)
    f.rows = {}
    f:Hide()
    return f
  end
  local function Line(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f)
    r:SetHeight(ROW)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -3 - (i - 1) * ROW)
    r:SetPoint("RIGHT", f, "RIGHT", -1, 0)
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints(r)
    r.hl:SetTexture(1, 1, 1, .09)
    r.hl:Hide()
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetFont(W.UIFont(), 12, "")
    r.text:SetPoint("LEFT", r, "LEFT", 10, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", -22, 0)
    r.text:SetJustifyH("LEFT")
    r.mark = r:CreateFontString(nil, "OVERLAY")
    r.mark:SetFont(W.UIFont(), 12, "")
    r.mark:SetPoint("RIGHT", r, "RIGHT", -8, 0)
    r.rule = r:CreateTexture(nil, "ARTWORK")
    r.rule:SetTexture(1, 1, 1, .12)
    r.rule:SetHeight(1)
    r.rule:SetPoint("LEFT", r, "LEFT", 8, 0)
    r.rule:SetPoint("RIGHT", r, "RIGHT", -8, 0)
    r:SetScript("OnEnter", function()
      if this.d and not this.d.head and not this.d.rule then this.hl:Show() end
      if this.enter then this.enter(this) end
    end)
    r:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
    r:SetScript("OnClick", function() if this.d and this.d.fn then this.d.fn(this) end end)
    f.rows[i] = r
    return r
  end
  -- fill a panel with { label, fn, sub (function -> lines), on, head, rule, red, tip }
  local function Fill(f, lines, enter)
    for i, d in ipairs(lines) do
      local r = Line(f, i)
      r.d, r.enter = d, enter
      r.text:SetText(d.rule and "" or d.label)
      if d.head then r.text:SetTextColor(.55, .55, .6) elseif d.red then r.text:SetTextColor(1, .4, .4)
      elseif d.on then r.text:SetTextColor(1, .82, .2) else r.text:SetTextColor(.9, .9, .92) end
      r.mark:SetText(d.sub and ">" or (d.on and "|cffffd24dx|r" or ""))
      if d.rule then r.rule:Show() else r.rule:Hide() end
      r:Show()
    end
    for i = table.getn(lines) + 1, table.getn(f.rows) do f.rows[i]:Hide() end
    f:SetHeight(table.getn(lines) * ROW + 6)
  end
  function CP.MenuLines(name)
    local cd = CD()
    local _, _, e = cd.Where(name)
    if not e then return {} end
    local m = CP.menu
    local function Changed() if m then m.changed = true end Up() end
    local function Choices(spec)
      return function()
        local out = {}
        local function Group(s)
          for _, o in ipairs(cd.Opts(s)) do
            local opt, key = o, s.key
            table.insert(out, { label = opt.label, on = cd.Get(e, key) == opt.key, fn = function()
              e[key] = opt.key
              if key == "sound" then cd.PlaySound(opt.key) end
              Changed()
            end })
          end
        end
        Group(spec)
        if spec.more then
          table.insert(out, { label = spec.more.head, head = true })
          Group(spec.more)
        end
        return out
      end
    end
    local lines = { { label = "Remove Spell", red = true, fn = function()
      cd.Remove(name)
      if CP.pick == name then CP.pick = nil end
      Changed()
      if m then m:Hide() end
    end } }
    table.insert(lines, { rule = true })
    for _, s in ipairs(cd.SPEC) do
      if not s.extra then table.insert(lines, { label = s.label, sub = Choices(s), tip = s.tip }) end
    end
    local buff = (e.buff and e.buff ~= "") and e.buff or "None"
    table.insert(lines, { label = "Replace with Buff: " .. buff, tip = "Watch another effect than the one with the spell's own name: a trinket's, a proc's.",
      sub = function()
        local out = { { label = "None (the spell's own name)", on = buff == "None", fn = function() e.buff = "" Changed() end } }
        local names = {}
        for _, a in pairs(cd.buffs) do if a.name then table.insert(names, a.name) end end
        table.sort(names)
        if buff ~= "None" then
          local had
          for _, n in ipairs(names) do if n == buff then had = true end end
          if not had then table.insert(names, 1, buff) end
        end
        if table.getn(names) > 0 then table.insert(out, { label = "The effects on you now", head = true }) end
        for i = 1, math.min(table.getn(names), 16) do
          local n = names[i]
          table.insert(out, { label = n, on = n == buff, fn = function() e.buff = n Changed() end })
        end
        table.insert(out, { label = "Another: type it under \"The picked icon\"", head = true })
        return out
      end })
    local cond = (e.talent and e.talent ~= "") and ((e.talentnot == "1" and "Lacks " or "Has ") .. e.talent) or "None"
    table.insert(lines, { label = "Talent Conditions: " .. cond, tip = "Only show this icon with - or without - one of your talents.",
      fn = function(row)
        cd.Talents()
        local opts = { { key = "", label = "None (always)" } }
        for _, t in ipairs(cd.talentList or {}) do
          table.insert(opts, { key = "+" .. t.name, label = "Has: " .. t.name .. (t.rank > 0 and "  |cff40e060(you do)|r" or ""), icon = t.tex })
        end
        for _, t in ipairs(cd.talentList or {}) do
          table.insert(opts, { key = "-" .. t.name, label = "Lacks: " .. t.name, icon = t.tex })
        end
        local anchor = (m and m.anchor) or row
        if m then m:Hide() end
        CP.Pop(anchor, opts, 270, true, function(key)
          if key == "" then e.talent, e.talentnot = nil, nil
          else e.talent, e.talentnot = string.sub(key, 2), (string.sub(key, 1, 1) == "-") and "1" or nil end
          Up() Again()
        end)
      end })
    local custom = e.icon and e.icon ~= ""
    table.insert(lines, { label = custom and "Custom Icon: change" or "Add Custom Icon", sub = function()
      return {
        { label = "Pick a picture...", fn = function()
          local GO = pfUI.gearOcto
          local anchor = (m and m.anchor) or UIParent
          if m then m:Hide() end
          if GO and GO.IconPicker then
            GO.IconPicker(anchor, e.icon, {}, function(path) e.icon = path Up() Again() end)
          end
        end },
        { label = "The spell's own picture", on = not custom, fn = function() e.icon = "" Changed() end },
      }
    end })
    -- ours, beyond the model: glow speed and the animations
    table.insert(lines, { rule = true })
    for _, s in ipairs(cd.SPEC) do
      if s.extra then table.insert(lines, { label = s.label, sub = Choices(s), tip = s.tip }) end
    end
    table.insert(lines, { rule = true })
    table.insert(lines, { label = "Move earlier", fn = function() cd.Shift(name, -1) Changed() end })
    table.insert(lines, { label = "Move later", fn = function() cd.Shift(name, 1) Changed() end })
    local _, bars = CP.Bar()
    if table.getn(bars) > 1 then
      table.insert(lines, { label = "Move to bar", sub = function()
        local out = {}
        for ii, b in ipairs(bars) do
          local i = ii
          table.insert(out, { label = b.name or ("Bar " .. i), on = i == CP.bar, fn = function()
            if cd.MoveTo(name, i) then Changed() if m then m:Hide() end end
          end })
        end
        return out
      end })
    end
    return lines
  end
  function CP.OpenMenu(anchor, name)
    local cd = CD()
    if not cd.Where(name) then return end
    local m = CP.menu
    if not m then
      m = Panel(MW)
      m.sub = Panel(SW)
      m.sub:SetFrameLevel(m:GetFrameLevel() + 5)
      m:SetScript("OnUpdate", function()
        if MouseIsOver(this) or (this.sub:IsShown() and MouseIsOver(this.sub)) then this.away = 0 return end
        this.away = (this.away or 0) + (arg1 or 0)
        if this.away > 1.2 then this:Hide() end
      end)
      m:SetScript("OnHide", function()
        this.sub:Hide()
        CD().demo = CP.pick
        if this.changed then this.changed = nil Again() end
      end)
      CP.menu = m
    end
    m.name, m.anchor, m.away, m.changed = name, anchor, 0, nil
    cd.demo = name
    local function Enter(row)
      local d = row.d
      if d.tip then
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        GameTooltip:AddLine(d.label, 1, 1, 1)
        GameTooltip:AddLine(d.tip, .75, .75, .78, 1)
        GameTooltip:Show()
      end
      if d.head or d.rule then return end
      if not d.sub then m.sub:Hide() return end
      m.subOf = d
      Fill(m.sub, d.sub(), nil)
      m.sub:ClearAllPoints()
      m.sub:SetPoint("TOPLEFT", row, "TOPRIGHT", 2, 3)
      m.sub:Show()
    end
    Fill(m, CP.MenuLines(name), Enter)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    m:Show()
    return m
  end
  -- after a pick in the sub-menu: its marks and the menu's own lines follow
  local upWas = Up
  Up = function()
    upWas()
    local m = CP.menu
    if m and m:IsShown() and CD().Where(m.name) then
      local sub = m.subOf
      Fill(m, CP.MenuLines(m.name), m.rows[1] and m.rows[1].enter)
      if m.sub:IsShown() and sub then
        -- the same line of the fresh list (found by its place)
        for _, r in ipairs(m.rows) do
          if r.d and r.d.sub and string.sub(r.d.label, 1, 12) == string.sub(sub.label, 1, 12) then
            m.subOf = r.d
            Fill(m.sub, r.d.sub(), nil)
          end
        end
      end
    end
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
    cd.demo = CP.pick
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
        ((en.kind == "item" and "item" or (en.kind == "aura" and "effect" or Length(cd.BaseCD(en.name)))) .. (en.auto and "   filled in" or "")))
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
      CP.Pop(this, opts, 260, true, function(key)
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
      CP.Pop(this, opts, 260, false, function(key)
        cd.Add(CP.bar, key, "item")
        CP.pick = key
        Up() Again()
      end)
    end)
    W.Tip(item, "A trinket or item", "Your worn trinkets and the usable items in your bags. It is followed by name, wherever it is.")
    local aura = W.Button(addrow, "An effect or proc...", 150, 22)
    aura:SetPoint("LEFT", item, "RIGHT", 8, 0)
    if W.Tint then W.Tint(aura, "pick") end
    aura:SetScript("OnClick", function()
      cd.ReadBuffs()
      local opts = {}
      for _, a in pairs(cd.buffs) do
        if a.name and not cd.Where(a.name) then table.insert(opts, { key = a.name, label = a.name, icon = a.tex }) end
      end
      table.sort(opts, function(a, b) return a.key < b.key end)
      if table.getn(opts) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r cooldowns: no effect on you now that is not on a bar. Type its name in \"By name\" instead.")
        return
      end
      CP.Pop(this, opts, 260, false, function(key)
        local e = cd.Add(CP.bar, key, "aura")
        if e then e.idle = "hide" end
        CP.pick = key
        Up() Again()
      end)
    end)
    W.Tip(aura, "An effect or proc", "Any effect that is on you now - an item's proc, a trinket's effect, a buff from a talent. "
      .. "Its icon shows its time and stacks while it is up and hides otherwise (change that with its Non Active State). "
      .. "Not up right now? Type its exact name in \"By name\".")
    W.Edit(p, "By name", "The exact name of a spell, an item or an effect; Enter adds it. An item if you carry or wear it, a spell if it is in your spell book, else an effect (a proc) followed by its name.",
      function() return "" end, function(v)
        if not v or v == "" then return end
        cd.itemsDirty = true
        local key = cd.Lower(v)
        local kind = cd.Items()[key] and "item" or (cd.book[key] and "spell" or "aura")
        if kind == "spell" then v = cd.book[key].name end
        local e = cd.Add(CP.bar, v, kind)
        if e then
          -- (a proc only shows while it is up, unless you change its Non Active State)
          if kind == "aura" then e.idle = "hide" end
          CP.pick = v
          Up() Again()
        end
      end, 220)

    -- the picked icon
    local e = CP.Entry()
    W.Card(p, "The picked icon", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
      tip = "Click an icon in the preview (or Settings in the list) to pick it." })
    if not e then
      W.Note(p, "No icon picked: click one in the preview at the top.")
    else
      W.Note(p, "|cffffffff" .. e.name .. "|r", nil, true)
      W.Note(p, "The same choices as the icon's right-click menu in the preview. The preview runs the picked icon through ready, on cooldown and active.")
      for _, sp in ipairs(cd.SPEC) do
        local s = sp
        W.Dropdown(p, s.label, s.tip, cd.Opts(s), function() return cd.Get(e, s.key) end, function(v)
          e[s.key] = v
          if s.key == "sound" then cd.PlaySound(v) end
          Up()
        end)
        if s.more then
          local m = s.more
          W.Dropdown(p, m.head, nil, m.opts, function() return cd.Get(e, m.key) end, function(v) e[m.key] = v Up() end)
        end
      end
      W.Edit(p, "Replace with Buff", "Empty = the buff with the spell's own name. Fill in another buff's exact name when it is called differently "
        .. "(a trinket's effect, a proc).", function() return e.buff or "" end, function(v) e.buff = v or "" Up() end, 220)
      W.Live(p, function()
        if not e.talent or e.talent == "" then return "Talent Conditions: |cffffffffnone|r (set from the right-click menu)" end
        return "Talent Conditions: |cffffffff" .. (e.talentnot == "1" and "lacks " or "has ") .. e.talent .. "|r"
          .. (cd.TalentOK(e) and "  |cff40e060met|r" or "  |cffff6060not met: hidden|r")
      end)
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

  O:AddPage("CoolDownManager", "cdmbars", "Bars", Build)
end)
