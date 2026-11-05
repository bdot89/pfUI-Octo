pfUI:RegisterModule("meters-options", "vanilla", function ()
  -- pfUI Octo :: the Meters section (user, 22 Oct 2026, Details! as the
  -- model: "a preview in UI able to add windows and set them up, change the
  -- looks, everything"). Details! is All Rights Reserved: only its option
  -- names were read. Three pages in place of pfUI's Meters pages (hidden):
  --   Windows  a tab per window (+ New window, Remove), a pinned preview of
  --            the window on a made-up fight, looks, and cards for what it
  --            shows, the window, the title bar, the bars and the texts
  --   Data     what is tracked and kept
  --   Threat   the threat meter
  -- The preview is a real meter window (meters-window.lua CreateWindow with
  -- pv); each part opens its card, the grip sets its size, Shift + wheel
  -- over the bars / title sets their height.
  local M = pfUI.meters
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not M or not M.S or not W or not O or not O.AddPage then return end
  local PfChk, PfSld = O.PfChk, O.PfSld

  local MO = { cur = 1 }
  pfUI.metersOcto = MO

  local function S() return C.meters["win" .. MO.cur] end
  local function G() return C.meters end
  local function Px(v) return v .. " px" end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Pct2(v) return math.floor(v + .5) .. "%" end
  local function Reload() if pfUI.gui then pfUI.gui.settingChanged = true end end

  function MO.Apply()
    M.RestyleAll()
    -- (docked windows: a new width is a new share of the panel)
    if pfUI.panel and pfUI.panel.ArrowLayout then pfUI.panel.ArrowLayout() end
    if MO.preview then MO.Sync() end
  end
  local function Docked() local w = M.windows and M.windows[MO.cur] return w and w.arrowDocked end
  local Up = function() MO.Apply() end

  local function Chk(p, label, desc, group, key, after) return PfChk(p, label, desc, group, key, after or Up) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt, after) return PfSld(p, label, desc, min, max, step, group, key, after or Up, fmt) end
  local function Drop(p, label, desc, options, group, key, after)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v)
      group()[key] = v
      ;(after or Up)()
    end)
  end
  local function Color(p, label, desc, group, key, after)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      ;(after or Up)()
    end)
  end
  local function List(pairs2)
    local out = {}
    for _, e in ipairs(pairs2) do table.insert(out, { key = e[1], label = e[2] }) end
    return out
  end
  local function Textures()
    local out = {}
    local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns.uf_bartexture
    if type(list) == "function" then list = list() end
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l, texture = k }) end
    end
    return out
  end
  local function Fonts(first)
    local out = { { key = "", label = first or "Unit frame font" } }
    for _, f in ipairs(W.Fonts and W.Fonts() or {}) do table.insert(out, { key = f.key, label = f.label, font = f.key }) end
    return out
  end
  local function Modes()
    local out = {}
    for _, m in ipairs(M.MODES or {}) do table.insert(out, { key = m.key, label = m.name }) end
    return out
  end

  -- ---------------------------------------------------------------- preview

  -- what a click on each part opens
  MO.GO = { title = "Title bar", buttons = "Title bar", bars = "Bars", name = "Words", value = "Words",
    window = "The window", shows = "What it shows", status = "Status bar" }
  function MO.Open(part)
    local title = MO.GO[part] or "The window"
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("mtwindows", title) else O:Open("mtwindows") end
  end
  M.PreviewClick = function(win, part) MO.Open(part) end
  M.PreviewSized = function(win) MO.Apply() end

  -- the preview window follows the chosen window's settings
  function MO.Sync()
    local pw = MO.preview
    if not pw then return end
    local s = S()
    pw.cfg = MO.cur
    pw.mode = s.mode or "damage"
    pw.segment = "current"
    M.ApplyStyle(pw)
    local w, h = tonumber(s.width) or 260, tonumber(s.height) or 160
    if not pw.psize then
      pw:SetWidth(w)
      pw:SetHeight(h)
    end
    -- fits the box (the window keeps its own size; the view scales)
    local box = MO.box
    local k = math.min(2.2, ((box:GetWidth() or 600) - 20) / w, ((box:GetHeight() or 200) - 30) / h)
    pw:SetScale(math.max(.4, k))
    pw:ClearAllPoints()
    pw:SetPoint("CENTER", box, "CENTER", 0, -6 / math.max(.4, k))
    pw:Show()
    pw:SetAlpha(1)
    pw.Refresh(pw)
    MO.Spots()
  end

  -- spots over the bar texts (the bars themselves open Bars)
  MO.spots = {}
  local function Spot(i, part)
    local key = i .. part
    local h = MO.spots[key]
    if h then return h end
    h = CreateFrame("Button", nil, MO.preview)
    h:SetFrameLevel(MO.preview:GetFrameLevel() + 12)
    h.part = part
    h.hl = h:CreateTexture(nil, "OVERLAY")
    h.hl:SetAllPoints(h)
    h.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    local ar, ag, ab = .2, .55, .9
    if GetAccentColor then ar, ag, ab = GetAccentColor() end
    h.hl:SetVertexColor(ar, ag, ab, .3)
    h.hl:Hide()
    h:SetScript("OnEnter", function()
      this.hl:Show()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:AddLine(this.part == "name" and "Name (and rank number)" or "Value: total, per second, percent")
      GameTooltip:AddLine("Click: its settings", 1, 1, 1)
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
    h:SetScript("OnClick", function() MO.Open(this.part) end)
    MO.spots[key] = h
    return h
  end
  function MO.Spots()
    local pw = MO.preview
    if not pw then return end
    for i, b in ipairs(pw.bars) do
      for _, e in ipairs({ { b.left, "name", "LEFT" }, { b.right, "value", "RIGHT" } }) do
        local h = Spot(i, e[2])
        local fs = e[1]
        local w = fs:GetStringWidth() or 0
        if b:IsShown() and w > 0 then
          local _, size = fs:GetFont()
          h:ClearAllPoints()
          h:SetWidth(math.min(w, fs:GetWidth() or w) + 4)
          h:SetHeight((tonumber(size) or 10) + 2)
          h:SetPoint(e[3], fs, e[3], e[3] == "LEFT" and -2 or 2, 0)
          h:Show()
        else
          h:Hide()
        end
      end
    end
  end

  -- Shift + wheel over the window: bar height (over the title: its height)
  local function Wheel()
    local s = S()
    if IsShiftKeyDown() then
      local key = MouseIsOver(MO.preview.head and MO.preview.titlebtn) and "titleheight" or "barheight"
      local v = (tonumber(s[key]) or 16) + (arg1 or 0)
      s[key] = tostring(math.max(8, math.min(40, v)))
      MO.Apply()
    elseif pfUI.plates and pfUI.plates.PassWheel then
      pfUI.plates.PassWheel(MO.box)
    end
  end

  local function Preview(p)
    W.Pin(p, "Preview", "The chosen window with your settings, on a made-up fight. Pick a window with the tabs. Click any "
      .. "part for its settings; drag the corner grip to size it; hold Shift and scroll over the bars (or the title) to "
      .. "change their height. Click this bar to fold it away.", function(p)
      -- the windows as tabs, and New / Remove
      local row = W.Row(p, 24, 0, 4)
      MO.tabs = {}
      for i = 1, M.MAXWIN do
        local b = W.Button(row, "Window " .. i, 92, 22)
        b:SetPoint("LEFT", row, "LEFT", (i - 1) * 96, 0)
        b.n = i
        b:SetScript("OnClick", function()
          MO.cur = this.n
          MO.Apply()
          O:Refresh()
        end)
        MO.tabs[i] = b
        -- (31 Oct 2026, user: "a red X next to each meter you have made")
        if i > 1 then
          local x = CreateFrame("Button", nil, b)
          x:SetWidth(14)
          x:SetHeight(14)
          x:SetPoint("RIGHT", b, "RIGHT", -3, 0)
          x:SetFrameLevel(b:GetFrameLevel() + 2)
          x.text = x:CreateFontString(nil, "OVERLAY")
          W.Font(x.text, 11, .95, .3, .3)
          x.text:SetPoint("CENTER", x, "CENTER", 0, 0)
          x.text:SetText("X")
          x.n = i
          x:SetScript("OnEnter", function()
            this.text:SetTextColor(1, .55, .55)
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText("Remove window " .. this.n, .95, .3, .3)
            GameTooltip:AddLine("Takes this meter window away for good (it asks first).", 1, 1, 1, 1)
            GameTooltip:Show()
          end)
          x:SetScript("OnLeave", function() this.text:SetTextColor(.95, .3, .3) GameTooltip:Hide() end)
          x:SetScript("OnClick", function()
            local n = this.n
            CreateQuestionDialog("Remove meter window " .. n .. "?", function()
              M.RemoveWindow(n)
              if MO.cur > n or MO.cur == n then MO.cur = math.max(1, MO.cur - 1) end
              MO.Apply()
              O:Refresh()
            end)
          end)
          b.removeBtn = x
        end
      end
      local new = W.Button(row, "+ New window", 108, 22)
      new:SetPoint("LEFT", row, "LEFT", M.MAXWIN * 96 + 4, 0)
      new:SetScript("OnClick", function()
        local w = M.AddWindow()
        if w then MO.cur = w.id end
        MO.Apply()
        O:Refresh()
      end)
      W.Tip(new, "New window", "Adds a meter window (up to " .. M.MAXWIN .. "). It floats: move it with Move frames or its title bar.")
      MO.newBtn = new
      -- (user, 24 Oct 2026: at the top, whichever window is being changed)
      local row2 = W.Row(p, 24, 0, 4)
      local match = W.Button(row2, "Match all windows to this one", 230, 22)
      match:SetPoint("LEFT", row2, "LEFT", 0, 0)
      match:SetScript("OnClick", function()
        local n = M.MatchAll and M.MatchAll(MO.cur) or 0
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r meters: " .. n .. " " .. (n == 1 and "window" or "windows")
          .. " now " .. (n == 1 and "has" or "have") .. " the size and look of window " .. MO.cur .. ".")
      end)
      W.Tip(match, "Match all windows to this one", "Every other meter window takes this window's size and look - bars, "
        .. "fonts, colours, title bar, buttons. What each one shows (damage, threat...) stays its own.")
      MO.matchBtn = match
      -- (25 Oct 2026, user: "i want this button to open the preview box up the top ... a test mode for everything
      -- added ... it should be clear") the tests sit up here, always in view: a made-up fight for every window,
      -- the breakdown on top of everything, a tour of its views, the threat label and the status bar
      local row3 = W.Row(p, 24, 0, 4)
      local function TestFight() if M.TestMode and not M.testOn then M.TestMode(true) end end
      local function OpenBreakdown(tour)
        TestFight()
        local w = M.windows and M.windows[MO.cur] or M.windows and M.windows[1]
        local win = w or { mode = S().mode or "damage", segment = "current", cfg = MO.cur, id = MO.cur }
        local rows = M.Rows(win.mode, win.segment)
        if rows[1] then
          M.ShowDetails(win, rows[1])
          if pfMeterBreakdown and pfMeterBreakdown.Raise then pfMeterBreakdown:Raise() end
          if M.breakdown and M.breakdown.Tour then M.breakdown.Tour(tour and true or false) end
        end
      end
      local tests = {
        { "Test fight", function() M.TestMode() end, 100,
          "A made-up Onyxia fight in every meter window, with everything a real one has. Click again to switch it off." },
        { "Open breakdown", function() OpenBreakdown(false) end, 120,
          "Opens the breakdown of the top bar of this window on the made-up fight, on top of everything." },
        { "Tour the views", function() OpenBreakdown(true) end, 110,
          "Opens the breakdown and steps through all its views, one every two seconds. Its Tour button stops it." },
        { "Threat label", function() if M.threat and M.threat.Sample then M.threat.Sample(8) end end, 100,
          "Shows a made-up threat reading on your target's nameplate for 8 seconds." },
        { "Status bar", function() local s = S() s.status = s.status == "1" and "0" or "1" MO.Apply() O:Refresh() end, 90,
          "Turns this window's status bar on or off so you can see it in the preview." },
      }
      local ROLES = { "go", "open", "open", "go", "pick" }
      for i, t in ipairs(tests) do
        local b = W.Button(row3, t[1], t[3], 22)
        if W.Tint then W.Tint(b, ROLES[i]) end
        if i == 1 then b:SetPoint("LEFT", row3, "LEFT", 0, 0) else b:SetPoint("LEFT", row3.last, "RIGHT", 4, 0) end
        row3.last = b
        local fn = t[2]
        b:SetScript("OnClick", function() fn() end)
        W.Tip(b, t[1], t[4])
      end
      local box = (W.ZoomBox or W.Box)(p, 250)
      MO.box = box
      -- the preview window, a real one
      local pw = M.CreateWindow(MO.cur, { parent = box, cfg = MO.cur })
      MO.preview = pw
      pw:EnableMouseWheel(true)
      pw:SetScript("OnMouseWheel", Wheel)
      -- the window's background opens Window
      local bgspot = CreateFrame("Button", nil, pw)
      bgspot:SetAllPoints(pw)
      bgspot:SetFrameLevel(pw:GetFrameLevel())
      bgspot:SetScript("OnClick", function() MO.Open("window") end)
      bgspot:EnableMouseWheel(true)
      bgspot:SetScript("OnMouseWheel", Wheel)
      -- the status bar opens its card
      if pw.status then
        local stspot = CreateFrame("Button", nil, pw.status)
        stspot:SetAllPoints(pw.status)
        stspot:SetFrameLevel(pw.status:GetFrameLevel() + 2)
        stspot:SetScript("OnClick", function() MO.Open("status") end)
        stspot:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:AddLine("Status bar")
          GameTooltip:AddLine("Click: its settings", 1, 1, 1)
          GameTooltip:Show()
        end)
        stspot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        MO.statusSpot = stspot
      end
      local cap = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      cap:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
      cap:SetTextColor(.6, .6, .6)
      MO.cap = cap
      table.insert(p.items, { Refresh = function()
        local n = table.getn(M.windows)
        if MO.cur > n then MO.cur = n end
        for i, b in ipairs(MO.tabs) do
          if i <= n then b:Show() else b:Hide() end
          W.Pick(b, i == MO.cur)
        end
        if n >= M.MAXWIN then MO.newBtn:Hide() else MO.newBtn:Show() end
        local s = S()
        local where = "floating"
        cap:SetText("Window " .. MO.cur .. " (" .. where .. "), shown on a made-up fight  -  " .. (s.width or "?") .. " x " .. (s.height or "?"))
        MO.Sync()
      end })
      -- texts' spots follow the words
      box:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .3
        MO.Spots()
      end)
      local band = W.Row(p, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r a part  its settings     " .. k .. "Drag|r the corner grip  size     " .. k .. "Shift + wheel|r  bar / title height     "
        .. k .. "Move frames|r  move windows")
      W.HowTo(p, band, how:GetText())
    end)
  end

  -- the looks, three to a row; the one in use is lit
  local function Looks(p)
    local btns, rows = {}, {}
    local n = table.getn(M.LOOKS)
    for r = 1, math.ceil(n / 3) do rows[r] = W.Row(p, 24, 0, 6) end
    local function Paint()
      local cur = M.CurrentLook({ cfg = MO.cur })
      for _, b in ipairs(btns) do W.Pick(b, b.key == cur) end
    end
    for i, l in ipairs(M.LOOKS) do
      local b = W.Button(rows[math.floor((i - 1) / 3) + 1], l[2], 200, 22)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(i - 1, 3) * 206, 0)
      b.key = l[1]
      b:SetScript("OnClick", function()
        M.ApplyLook({ cfg = MO.cur }, this.key)
        Paint()
        MO.Apply()
        O:Refresh()
      end)
      W.Tip(b, l[2], "Background, border, title bar, bar texture, spacing and icons of this window in one click.")
      btns[i] = b
    end
    table.insert(p.items, { Refresh = Paint })
    Paint()
  end

  -- ---------------------------------------------------------------- windows page

  local BORDERS = { { "pfui", "pfUI's thin line" }, { "none", "None" }, { "gold", "Gold" }, { "accent", "Accent colour" },
    { "glow", "Soft glow (accent)" }, { "custom", "Own colour" } }
  local AUTOHIDE = { { "never", "Always shown" }, { "outofcombat", "Hide out of combat" }, { "incombat", "Hide in combat" } }
  local COLORBY = { { "class", "Class colour" }, { "fixed", "One colour" } }
  local GROW = { { "down", "Top to bottom" }, { "up", "Bottom to top" } }
  local ICONS = { { "class", "Class icon" }, { "none", "None" } }
  local ICONSIDE = { { "left", "Left of the name" }, { "right", "Right end of the bar" } }
  local OUTLINE = { { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" }, { "NONE", "None" } }
  local TEXTCOLOR = { { "white", "White" }, { "class", "Class colour" }, { "custom", "My own colour (set below)" } }
  local SELFMARK = { { "0", "Not marked" }, { "border", "A border in my colour" }, { "tint", "The bar in my colour" } }
  local ICO = "Interface\\Icons\\"
  local function IconPx(v) return v <= 0 and "Bar height" or (v .. " px") end
  local function ValuePx(v) return v <= 0 and "Same as names" or (v .. " px") end

  -- (25 Oct 2026, user: "the options are a mess ... more custom stuff and it should be clear what stuff does here,
  -- font colour changes, icons". One card per thing you can see, in the order you look at a window: pick a look,
  -- what it shows, the frame, the title bar, the bars, the pictures, the words, their colours. Each card has a
  -- picture, each setting says what it does in its tooltip, and the pinned preview shows every change at once.)
  -- every window in one list: in the bottom panel (up to three, splitting it edge to edge) or floating
  -- where you put it (user, 28 Oct 2026: "the menu should state clear which meters you want in the
  -- bottom 3 max ... Any you dont want in the bottom window you can select float mode ... all on one page")
  local function DisplayName(win)
    local s = M.S and M.S(win)
    for _, m in ipairs(M.MODES or {}) do if s and m.key == s.mode then return m.name end end
    return ""
  end
  function MO.WhereCard(p)
    local PN = pfUI.panel
    if not (PN and PN.ArrowDock) then return end
    W.Card(p, "Where your windows go", { icon = "Interface\\Icons\\INV_Misc_Bag_10", tip = "Bottom panel: the window "
      .. "sits in the window above the bottom-right bar, sharing it edge to edge with the others there (one fills it, "
      .. "two take half each, three a third) - up to " .. PN.ARROWMAX .. ". Floating: it stays exactly where you put it on "
      .. "the screen (Move frames, or drag its title bar)." })
    -- (1 Nov 2026, dennis: dock into the left panel too)
    W.Dropdown(p, "Panel side", "Which bottom panel the docked windows sit in. Left: over the left chat window.",
      { { key = "right", label = "Right panel" }, { key = "left", label = "Left panel (over the chat)" } },
      function() return C.panel.arrowside or "right" end,
      function(v)
        local open = C.panel.arrowmode == "meters" and PN.ArrowIsOpen()
        if open then PN.ArrowSet(false) end
        C.panel.arrowside = v
        if PN.ArrowPlace then PN.ArrowPlace() end
        if open then PN.ArrowSet(true) end
      end)
    local box = W.Box(p, 28 * M.MAXWIN + 34)
    local rows = {}
    local function Paint()
      local n = M.windows and table.getn(M.windows) or 0
      local docked = table.getn(PN.ArrowMeters())
      for i, r in ipairs(rows) do
        local win = M.windows and M.windows[i]
        if win then
          local inPanel = PN.ArrowDocks(i)
          r.label:SetText("Window " .. i .. "  |cff999999" .. DisplayName(win) .. "|r")
          W.Lit(r.dock, inPanel)
          W.Lit(r.float, not inPanel)
          r.label:Show() r.dock:Show() r.float:Show()
        else
          r.label:Hide() r.dock:Hide() r.float:Hide()
        end
      end
      box.count:SetText("Bottom panel: |cffffffff" .. docked .. " of " .. PN.ARROWMAX .. "|r     Floating: |cffffffff"
        .. math.max(0, n - docked) .. "|r" .. ((C.panel.arrowopen ~= "1" and docked > 0) and
        "     |cffffd100The panel is shut - the arrow at the right end of the bottom-right bar opens it.|r" or ""))
    end
    for i = 1, M.MAXWIN do
      local r = {}
      r.label = box:CreateFontString(nil, "OVERLAY")
      r.label:SetFont(W.UIFont(), 12, "OUTLINE")
      r.label:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -10 - (i - 1) * 28)
      r.dock = W.Button(box, "Bottom panel", 130, 22)
      r.dock:SetPoint("TOPLEFT", box, "TOPLEFT", 230, -6 - (i - 1) * 28)
      r.float = W.Button(box, "Floating", 110, 22)
      r.float:SetPoint("LEFT", r.dock, "RIGHT", 6, 0)
      local n = i
      r.dock:SetScript("OnClick", function() PN.ArrowDock(n, true) Paint() O:Refresh() end)
      r.float:SetScript("OnClick", function() PN.ArrowDock(n, false) Paint() O:Refresh() end)
      W.Tip(r.dock, "Bottom panel", "Window " .. n .. " goes in the window above the bottom-right bar, sharing it edge to edge (up to " .. PN.ARROWMAX .. ").")
      W.Tip(r.float, "Floating", "Window " .. n .. " stays where you put it on the screen.")
      if W.Tint then pcall(W.Tint, r.dock, "pick") pcall(W.Tint, r.float, "pick") end
      rows[i] = r
    end
    box.count = box:CreateFontString(nil, "OVERLAY")
    box.count:SetFont(W.UIFont(), 11, "OUTLINE")
    box.count:SetTextColor(.7, .7, .75)
    box.count:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 12, 8)
    MO.PaintWhere = Paint
    Paint()
    if p.items then table.insert(p.items, { Refresh = Paint }) end
    W.Buttons(p, {
      { "Open / shut the bottom panel", function()
        if C.panel.arrowmode ~= "meters" and PN.ArrowMode then PN.ArrowMode("meters") end
        if PN.ArrowToggle then PN.ArrowToggle() end
        Paint()
      end, 230, "The same as the arrow at the right end of the bottom-right bar.", role = "go",
        on = function() return C.panel.arrowmode == "meters" and C.panel.arrowopen == "1" end },
      { "Panel arrow options  >", function() O:Open("chpanel") end, 190, "The arrow on or off (Chat > Panel arrow).", role = "open" },
    })
  end

  local function BuildWindows(p)
    W.Heading(p, "Meter windows", { on = { function() return C.meters.hidden ~= "1" end, function(v) M.ShowAll(v) end,
      "Show or hide every meter window (the same as the meters button)." },
      about = "Pick a window with the tabs above the preview (or make a new one), then change it card by card: "
      .. "each card is one part of the window - the picture on its title says which. Every window has its own settings; "
      .. "the preview shows the one you are editing and every change shows at once. Click a part of the preview to jump "
      .. "to its card. Hover any setting for what it does." })
    Preview(p)
    -- (31 Oct 2026, user: menus "overwhelming" - 13 cards on one page, now 4 tabs)
    if O.CardTabs then
      O.CardTabs(p, {
        { "look", "Look", "INV_Misc_Eye_01", { "Start with a look", "The window", "Title bar" } },
        { "bars", "Bars and words", "Ability_MeleeDamage", { "Bars", "Pictures", "Words", "Colours of the words" } },
        { "shows", "What it shows", "INV_Misc_Book_09", { "What it shows", "Status bar" } },
        { "tools", "Tools", "INV_Misc_Gear_01", { "Where your windows go", "Where they are", "Try it without a fight",
          "Share this look", "Remove this window" } },
      })
    end
    MO.WhereCard(p)

    W.Card(p, "Start with a look", { icon = ICO .. "INV_Misc_Eye_01", tip = "Ready-made looks: background, border, title bar, bar texture, "
      .. "spacing and icons in one click. Change anything afterwards in the cards below." })
    Looks(p)

    W.Card(p, "What it shows", { icon = ICO .. "INV_Misc_Book_09", tip = "The display this window opens with and the fight it follows "
      .. "(its title bar changes both while you play)." })
    Drop(p, "Display", "Damage done, healing, interrupts, deaths, threat... the same list as the title bar's menu.", Modes(), S, "mode")
    Drop(p, "Fight", "Current: the fight you are in (or the last one). Overall: everything since the last reset.",
      List({ { "current", "Current fight" }, { "overall", "Overall" } }), S, "segment")

    W.Card(p, "The window", { icon = ICO .. "INV_Banner_01", tip = "Size, background, border, and how it shows in and out of combat." })
    Sld(p, "Width", "How wide the window is when it floats. You can also drag its corner. In the bottom panel the "
      .. "windows share the panel evenly instead.", 150, 600, 1, S, "width", Px)
    Sld(p, "Height", "How tall the window is when it floats (more height = more bars). In the bottom panel: the panel's height.", 60, 500, 1, S, "height", Px)
    W.Live(p, function()
      if not Docked() then return "" end
      return "|cff73bfffThis window is in the bottom panel:|r it shares the panel evenly with the windows there. "
        .. "Set it to Floating (top card, \"Where your windows go\") to give it its own size and place."
    end)
    Color(p, "Background", "The colour and see-through of the window behind the bars.", S, "bg")
    Drop(p, "Border", "The edge round the window. Soft glow and Accent follow your accent colour.", List(BORDERS), S, "border")
    Color(p, "Border colour", "Used by the border choice \"Own colour\".", S, "bordercolor")
    Sld(p, "Opacity in combat", "How solid the whole window is while you fight.", .1, 1, .05, S, "alpha", Pct)
    Sld(p, "Opacity out of combat", "How solid it is when nothing is going on. 0 hides it.", 0, 1, .05, S, "oocalpha", Pct)
    Drop(p, "Hide", "Keep the window off the screen in or out of combat.", List(AUTOHIDE), S, "autohide")
    Chk(p, "Lock size and place", "Locked: it cannot be dragged or resized by accident.", S, "lock")

    -- (where each window goes - bottom panel or floating - is the card at the top: MO.WhereCard)

    W.Card(p, "Title bar", { icon = ICO .. "INV_Scroll_03", tip = "The strip at the top: the display's name, the fight, and the buttons." })
    Chk(p, "Show the title bar", "Off: only the bars show. Right-click the window for its menu.", S, "title")
    Sld(p, "Height", "How tall the strip is.", 10, 40, 1, S, "titleheight", Px)
    Color(p, "Background", "The colour behind the title.", S, "titlebg")
    Chk(p, "Title in the accent colour", "On: the title takes your accent colour. Off: the colour below.", S, "titleaccent")
    Color(p, "Title colour", "The title's colour when it is not in the accent colour.", S, "titlecolor")
    Drop(p, "Title font", "The writing of the title and the fight.", Fonts("pfUI's font"), S, "titlefont")
    Sld(p, "Title size", "How big the title is.", 8, 20, 1, S, "titlesize", Px)
    Chk(p, "Show the fight", "The time and name of the fight beside the title.", S, "showseg")
    Chk(p, "Menu button", "The button that opens the display menu.", S, "btnmenu")
    Chk(p, "Report button", "The button that sends the window to chat.", S, "btnreport")
    Chk(p, "Reset button", "The button that clears the data (it asks first).", S, "btnreset")
    Chk(p, "Padlock button", "Lock or unlock the window: unlocked, drag the title to move it and the corner to resize it.", S, "btnlock")

    W.Card(p, "Bars", { icon = ICO .. "Ability_MeleeDamage", tip = "The coloured bars, one per player or row." })
    Sld(p, "Height", "How tall each bar is.", 8, 40, 1, S, "barheight", Px)
    Sld(p, "Spacing", "The gap between bars.", 0, 10, 1, S, "spacing", Px)
    Drop(p, "Texture", "The pattern of the bar's fill.", Textures(), S, "texture")
    Drop(p, "Colour", "Class colour: each bar takes its player's class. One colour: every bar the same.", List(COLORBY), S, "colorby")
    Color(p, "One colour", "The colour used when Colour is \"One colour\".", S, "barcolor")
    Sld(p, "Bar opacity", "How solid the coloured part is.", .1, 1, .05, S, "baralpha", Pct)
    Color(p, "Behind the bars", "The empty part of each row (what is left of the bar).", S, "barbg")
    Drop(p, "Grow", "Which end the first bar is at.", List(GROW), S, "grow")
    Chk(p, "A border round each bar", "A thin line round every bar.", S, "barborder")
    Color(p, "Bar border colour", "The colour of that line.", S, "barbordercolor")
    Color(p, "Under the mouse", "The colour a bar lights up in when you point at it (click it for its breakdown).", S, "hovercolor")
    Drop(p, "Mark my own bar", "Find yourself fast: a border or a different colour on your own bar.", List(SELFMARK), S, "selfmark")
    Color(p, "My bar's colour", "The border or bar colour used by \"Mark my own bar\".", S, "selfcolor")

    W.Card(p, "Pictures", { icon = ICO .. "Spell_Fire_FlameBolt", tip = "The class picture on each bar." })
    Drop(p, "Class picture", "A small picture of each player's class on their bar.", List(ICONS), S, "icons")
    Sld(p, "Picture size", "How big it is. Bar height: as tall as the bar.", 0, 32, 1, S, "iconsize", IconPx)
    Drop(p, "Where", "On the left of the name, or at the right end of the bar.", List(ICONSIDE), S, "iconside")

    W.Card(p, "Words", { icon = ICO .. "INV_Letter_15", tip = "The name on the left and the numbers on the right." })
    Drop(p, "Font", "The writing of the names and numbers.", Fonts("Unit frame font"), S, "font")
    Sld(p, "Name size", "How big the names are.", 6, 20, 1, S, "fontsize", Px)
    Sld(p, "Number size", "How big the numbers on the right are.", 0, 20, 1, S, "valuesize", ValuePx)
    Drop(p, "Outline", "A dark edge round the letters so they read on any bar.", List(OUTLINE), S, "outline")
    Chk(p, "Shadow", "A soft shadow under the letters.", S, "shadow")
    Chk(p, "Rank numbers", "1. 2. 3. before the names.", S, "rank")
    Drop(p, "Numbers", "The order of total, per second and percent on the right.", List(M.ORDERS), S, "order")
    Chk(p, "Per second", "Show the per-second figure.", S, "showps")
    Chk(p, "Percent", "Show the share of the whole.", S, "showpct")
    Chk(p, "In brackets", "(472, 22%) or just 472, 22%.", S, "brackets")

    W.Card(p, "Colours of the words", { icon = ICO .. "Spell_Frost_FrostBolt02", tip = "A colour for each kind of text. "
      .. "Pick \"My own colour\" and set it with the colour box beside it." })
    Drop(p, "Names", "White, the player's class colour, or one colour of your own.", List(TEXTCOLOR), S, "namecolor")
    Color(p, "Names: my colour", "Used when Names is \"My own colour\".", S, "namecustom")
    Drop(p, "Numbers", "The main number on the right.", List(TEXTCOLOR), S, "valuecolor")
    Color(p, "Numbers: my colour", "Used when Numbers is \"My own colour\".", S, "valuecustom")
    Color(p, "Small numbers", "The per-second and percent figures and their brackets.", S, "subcolor")
    Color(p, "Rank numbers", "The 1. 2. 3. before each name.", S, "rankcolor")

    W.Card(p, "Status bar", { icon = ICO .. "INV_Misc_PocketWatch_01", tip = "A strip under the bars with three things of your choice." })
    Chk(p, "Show the status bar", "The strip under the bars.", S, "status")
    Drop(p, "Left", "What the left third shows (time, your value, fight, clock, fps, ping).", List(M.SLOTS), S, "statusleft")
    Drop(p, "Middle", "What the middle shows.", List(M.SLOTS), S, "statusmid")
    Drop(p, "Right", "What the right shows.", List(M.SLOTS), S, "statusright")

    W.Card(p, "Share this look", { icon = ICO .. "INV_Misc_Ticket_Tarot_Maelstrom_01", tip = "Copy this window's look as text to give to a friend, or paste one in. "
      .. "What the window shows, its fight and its lock are not part of it." })
    W.Edit(p, "This window's look", "Click, then Ctrl+A and Ctrl+C to copy.", function() return M.ExportLook({ cfg = MO.cur }) end,
      function() end)
    if M.CanCopy and M.CanCopy() then
      W.Buttons(p, { { "Copy this look", function()
        local lc = pfUI.api and pfUI.api.libclient
        if lc and lc.Copy and lc.Copy(M.ExportLook({ cfg = MO.cur })) then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: the look is on your clipboard - paste it with Ctrl+V.")
        end
      end, 140, "ClassicAPI puts the look on your clipboard: paste it anywhere with Ctrl+V.", role = "save" } })
    end
    W.Edit(p, "Paste a look here", "Paste (Ctrl+V) and press Enter: this window takes it.", function() return "" end, function(v)
      local n = M.ImportLook({ cfg = MO.cur }, v)
      if n > 0 then
        MO.Apply()
        O:Refresh()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r: window " .. MO.cur .. " took " .. n .. " settings of the look.")
      elseif v and v ~= "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r: that is not a meter look (it starts with OCTOMETER1:).")
      end
    end)

    -- (user, 24 Oct 2026: a meter went off the screen, "a reset positions button")
    W.Card(p, "Where they are", { icon = ICO .. "INV_Misc_Map_01", tip = "Lost a window off the screen? Reset puts it back." })
    W.Buttons(p, {
      { "Reset positions", function() if M.ResetPositions then M.ResetPositions() end end, 140,
        "Every meter window back to its starting place in the middle of the screen." },
      { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, 120,
        "Layout mode: drag the meter windows (and everything else) where you want them." },
      { "Show / hide all", function() if M.ToggleAll then M.ToggleAll() end end, 120,
        "The same as clicking the meters button on your screen." },
    })
    W.Check(p, "Meters button on the screen", "A small button that shows or hides every meter window. Shift + drag "
      .. "moves it; right-click opens these options.", function() return C.meters.togglebtn ~= "0" end, function(v)
      C.meters.togglebtn = v and "1" or "0"
      if M.toggle then if v then M.toggle:Show() else M.toggle:Hide() end end
    end)

    -- (user, 23 Oct 2026: "a full test mode ... click on test bars in the
    -- meter and look at the extra frames with information")
    W.Card(p, "Try it without a fight", { icon = ICO .. "Spell_Nature_WispSplode", on = { function() return M.testOn and true or false end,
      function(v) if M.TestMode then M.TestMode(v) end end,
      "Every window shows a made-up Onyxia fight with everything a real one has. Click any bar for its breakdown." },
      tip = "A made-up fight so you can try every display and its breakdown." })
    W.Live(p, function()
      if M.testOn then
        return "|cff55ff55On|r - every window shows a made-up 2 minute Onyxia fight. Click any bar: every name in the "
          .. "breakdown opens that player, enemy or spell. A real fight turns it off."
      end
      return "Off - switch it on to try every display and its breakdown without a fight (/pfmetertest)."
    end, 2)
    W.Buttons(p, {
      { "Open a breakdown", function()
        if M.TestMode and not M.testOn then M.TestMode(true) end
        local w = M.windows and M.windows[1]
        if not w then return end
        local rows = M.Rows(w.mode, w.segment)
        if rows[1] then M.ShowDetails(w, rows[1]) end
      end, 150, "Turns test mode on and opens the breakdown of window 1's top bar." },
    })

    W.Card(p, "Remove this window", { icon = ICO .. "Ability_Rogue_FeignDeath", tip = "Window 1 stays; the others can go." })
    W.Buttons(p, { { "Remove window", function()
      if MO.cur <= 1 then return end
      CreateQuestionDialog("Remove meter window " .. MO.cur .. "?", function()
        M.RemoveWindow(MO.cur)
        MO.cur = math.max(1, MO.cur - 1)
        MO.Apply()
        O:Refresh()
      end)
    end, 150, "Takes this window away for good (window 1 cannot be removed)." } })
    if O.TabFilter then O.TabFilter(p) end
  end

  -- ---------------------------------------------------------------- data, threat


  local function BuildData(p)
    W.Heading(p, "Meter data", { about = "What the meters track and keep." })
    W.Card(p, "Meters")
    Chk(p, "Use the meters", "After a reload.", G, "enable", Reload)
    Chk(p, "Ask to reset in a new instance", nil, G, "resetask", function() end)
    -- (25 Oct 2026, the user updated ClassicAPI: "use it wherever it makes pfUI Octo better")
    W.Card(p, "Combat log source", { icon = "Interface\\Icons\\INV_Misc_Book_09", tip = "Where the meters read what happens. ClassicAPI's "
      .. "combat log gives every hit, heal, cast, interrupt, dispel and aura exactly - with the spell's own number, who cast a debuff "
      .. "and what a dispel removed. Without it the meters read the chat log's text lines, which works with less detail." })
    Chk(p, "Use ClassicAPI's combat log", "On: exact events when ClassicAPI is installed. Off: always the chat log's text lines.", G, "clog",
      function() if M.ClogApply then M.ClogApply() end end)
    W.Live(p, function() return M.ClogStatus and M.ClogStatus() or "" end, 2)

    W.Card(p, "Tracking")
    Chk(p, "Merge pets into their owner", nil, G, "mergepets", function() M.who = {} end)
    Chk(p, "Everyone nearby (battlegrounds)", nil, G, "trackall", function() M.who = {} end)
    Drop(p, "Fights kept", nil, List({ { "5", "5" }, { "10", "10" }, { "20", "20" }, { "30", "30" } }), G, "history", function() end)
    W.Card(p, "Fights", { tip = "How fights are kept and timed, as in Details!." })
    Chk(p, "Merge trash", "Trash fights in a row become one \"Trash\" fight; boss fights stay apart.", G, "mergetrash", function() end)
    Chk(p, "Switch to the new fight", "When a fight starts, windows showing an earlier one show it.", G, "autocurrent", function() end)
    Drop(p, "Per second over", "Active: each player's own active time (Details' activity). Whole fight: the fight's length "
      .. "(Details' effective time).", List({ { "active", "Active time" }, { "effective", "Whole fight" } }), G, "timemeasure", Up)
    Chk(p, "Do not keep trash fights", "Only boss fights stay in the list (the overall still counts the trash).", G, "erasetrash", function() end)
    W.Card(p, "Numbers, reports and tooltips")
    Drop(p, "Numbers", nil, List({ { "short", "Short (12.3k)" }, { "comma", "With commas (12,345)" }, { "full", "In full (12345)" } }),
      G, "numformat", Up)
    Drop(p, "Report lines", "How many players a report sends.", List({ { "5", "5" }, { "10", "10" }, { "15", "15" }, { "20", "20" }, { "25", "25" } }),
      G, "reportlines", function() end)
    Chk(p, "Tooltips on the bars", nil, G, "tooltip", function() end)
    Drop(p, "Tooltip lines", nil, List({ { "5", "5" }, { "8", "8" }, { "12", "12" }, { "20", "20" } }), G, "tooltiplines", function() end)
    Chk(p, "Windows snap together", "A window dropped near another sits flush against it.", G, "snap", function() end)

    -- custom displays (Details' custom tab, without code)
    W.Card(p, "Custom displays", { tip = "Your own displays: one spell's damage, healing, casts or damage taken, or one buff's "
      .. "or debuff's uptime, per player. They show under Custom in a window's title menu once a spell is set." })
    for i = 1, 5 do
      local n = i
      local function CU() return C.meters["custom" .. n] end
      local function Changed() if M.CustomNames then M.CustomNames() end MO.Apply() end
      W.Edit(p, "Display " .. n .. ": name", "Leave empty to use the spell's name.", function() return CU().name or "" end,
        function(v) CU().name = v or "" Changed() end)
      Drop(p, "Display " .. n .. ": shows", nil, List(M.CUSTOMKINDS or {}), CU, "kind", Changed)
      W.Edit(p, "Display " .. n .. ": spell or aura", "Exactly as the game writes it, e.g. Sunder Armor.",
        function() return CU().spell or "" end, function(v) CU().spell = v or "" Changed() end)
    end
  end

  -- ---------------------------------------------------------------- threat
  -- (moved from OctoBG's "Threat label" page, 23 Oct 2026, and added to)

  -- the preview: a made-up nameplate with the label as you set it, going
  -- through safe, near your cap, past it and aggro. The label can be dragged
  -- (Across / Up-down), Shift + wheel sizes its text, right-click puts it back.
  local function ThreatPreview(p)
    local TH = M.threat
    W.Pin(p, "Preview", "A nameplate with your threat label, going through safe, near your cap, past it and aggro. "
      .. "Click the label or the plate for their settings, drag the label to move it.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 120)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      -- the mock plate: name over the health bar, one frame like a real plate,
      -- so "above" sits over the name as it does in game
      local plate = CreateFrame("Button", nil, holder)
      plate:SetWidth(150)
      plate:SetHeight(28)
      plate:SetPoint("CENTER", box, "CENTER", 0, -8)
      plate.bar = plate:CreateTexture(nil, "ARTWORK")
      plate.bar:SetTexture(pfUI.media["img:bar"] or "Interface\\Buttons\\WHITE8X8")
      plate.bar:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT")
      plate.bar:SetWidth(110)
      plate.bar:SetHeight(12)
      plate.bar:SetVertexColor(.8, .15, .15)
      plate.bg = plate:CreateTexture(nil, "BACKGROUND")
      plate.bg:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT")
      plate.bg:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT")
      plate.bg:SetHeight(12)
      plate.bg:SetTexture(0, 0, 0, .7)
      plate.name = plate:CreateFontString(nil, "OVERLAY")
      plate.name:SetFont(pfUI.font_default, 11, "OUTLINE")
      plate.name:SetPoint("BOTTOM", plate, "BOTTOM", 0, 15)
      plate.name:SetText("Onyxia's Elite Guard")
      plate:SetScript("OnClick", function() MO.OpenThreat("Label") end)
      plate:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Your target's nameplate")
        GameTooltip:AddLine("Click: the label's settings", 1, 1, 1)
        GameTooltip:Show()
      end)
      plate:SetScript("OnLeave", function() GameTooltip:Hide() end)
      local caption = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      caption:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
      caption:SetTextColor(.6, .6, .6)
      local l = TH and TH.NewLabel(holder) or nil

      local function Place()
        l:ClearAllPoints()
        if C.meters.twhere == "screen" then
          l:SetPoint("BOTTOM", box, "BOTTOM", 0, 6)
        else
          local pt = TH.POINTS[C.meters.twhere] or TH.POINTS.above
          l:SetPoint(pt[1], plate, pt[2], tonumber(C.meters.tx) or 0, tonumber(C.meters.ty) or 0)
        end
      end
      local function Clamp(v, lo, hi) return tostring(math.max(lo, math.min(hi, math.floor(v + .5)))) end

      if l then
        l:SetFrameStrata("FULLSCREEN")
        l:SetFrameLevel(holder:GetFrameLevel() + 5)
        l:EnableMouse(true)
        l:EnableMouseWheel(true)
        l.hl = l:CreateTexture(nil, "BACKGROUND")
        l.hl:SetAllPoints(l)
        l.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        local ar, ag, ab = .2, .55, .9
        if GetAccentColor then ar, ag, ab = GetAccentColor() end
        l.hl:SetVertexColor(ar, ag, ab, .25)
        l.hl:Hide()
        l:SetScript("OnEnter", function()
          this.hl:Show()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:AddLine("Threat label")
          GameTooltip:AddLine("Click: its settings", 1, 1, 1)
          if C.meters.twhere == "screen" then
            GameTooltip:AddLine("It sits in its own box: move that with Move frames", 1, 1, 1)
          else
            GameTooltip:AddLine("Drag: move it", 1, 1, 1)
          end
          GameTooltip:AddLine("Shift + mouse wheel: text size", 1, 1, 1)
          GameTooltip:AddLine("Right-click: put it back", 1, 1, 1)
          GameTooltip:Show()
        end)
        l:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
        l:SetScript("OnMouseDown", function()
          if arg1 == "RightButton" or C.meters.twhere == "screen" then return end
          local cx, cy = GetCursorPosition()
          this.down = { cx, cy, tonumber(C.meters.tx) or 0, tonumber(C.meters.ty) or 0 }
          this.moved = nil
        end)
        -- dragging runs in the holder's OnUpdate (the label's own is TH's)
        l:SetScript("OnMouseUp", function()
          if arg1 == "RightButton" then
            C.meters.tx, C.meters.ty, C.meters.tsize = "0", "2", "13"
            Place()
            O:Refresh()
            return
          end
          local moved = this.moved
          this.down, this.moved = nil, nil
          if moved then O:Refresh() else MO.OpenThreat("Label") end
        end)
        l:SetScript("OnMouseWheel", function()
          if IsShiftKeyDown() then
            C.meters.tsize = Clamp((tonumber(C.meters.tsize) or 13) + (arg1 or 0), 8, 30)
            holder.t = 0
            O:Refresh()
          elseif pfUI.plates and pfUI.plates.PassWheel then
            pfUI.plates.PassWheel(this)
          end
        end)
      end
      MO.threatPreview = { plate = plate, label = l, caption = caption, holder = holder }
      local STEPS = { { "safe", 45 }, { "near your cap", nil }, { "past your cap", 120 }, { "you have aggro" } }
      holder:SetScript("OnUpdate", function()
        if not l then return end
        local d = l.down
        if d then
          local x, y = GetCursorPosition()
          local k = box:GetEffectiveScale() or 1
          local dx, dy = (x - d[1]) / k, (y - d[2]) / k
          if l.moved or math.abs(dx) + math.abs(dy) >= 3 then
            l.moved = true
            C.meters.tx = Clamp(d[3] + dx, -150, 150)
            C.meters.ty = Clamp(d[4] + dy, -100, 100)
            Place()
          end
        end
        if (this.t or 0) > GetTime() then return end
        this.t = GetTime() + .25
        local step = math.mod(math.floor(GetTime() / 2.5), 4) + 1
        local limit = tonumber(C.meters.threatwarn) or 90
        local j
        if step == 4 then j = TH.SampleJudge(nil, true)
        elseif step == 2 then j = TH.SampleJudge(limit * ((tonumber(C.meters.tnear) or 80) + 8) / 100)
        else j = TH.SampleJudge(STEPS[step][2] / 100 * limit) end
        caption:SetText("Now: " .. STEPS[step][1] .. "   -   " .. TH.CapText())
        if C.meters.tlabel ~= "1" or C.meters.tlook == "none" then l:Hide() return end
        Place()
        TH.Paint(l, j)
        l:Show()
      end)

      -- how to use it, on screen
      local band = W.Row(pp, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r the label  its settings     " .. k .. "Drag|r  move it     " .. k .. "Shift + wheel|r  text size     "
        .. k .. "Right-click|r  put back")
      W.HowTo(pp, band, how:GetText())
    end)
  end

  function MO.OpenThreat(card)
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("mtthreat", card) else O:Open("mtthreat") end
  end

  local function BuildThreat(p)
    local TH = M.threat
    W.Heading(p, "Threat", { on = O.KeySwitch(function() return C.meters end, "threat", "Ask the server for threat on or off (takes a reload).", function() pfUI.gui.settingChanged = true end), about = "Your threat on the mob you target, from the server (the same answers TWThreat shows): "
      .. "only in a party or raid, on a mob in combat. A label by your target's nameplate turns yellow near your cap and red "
      .. "past it, a popup and a sound can warn you, and a meter window can show everyone's threat." })
    if not TH then
      W.Card(p, "Threat")
      Chk(p, "Threat meter", "After a reload.", G, "threat", Reload)
      return
    end
    ThreatPreview(p)
    W.Live(p, function() return "Status: " .. TH.StatusLine() end)
    W.Buttons(p, {
      { "Sample on my target (8 s)", function() if TH.sampleUntil and GetTime() < TH.sampleUntil then TH.sampleUntil = 0 else TH.Sample(8) end end,
        nil, "Your threat label shows a made-up reading on your target for 8 seconds. Click again to stop.",
        on = function() return TH.sampleUntil and GetTime() < TH.sampleUntil end },
      { "Test the popup", function() TH.Alert(C.meters.threatpopup or "THREAT", 1, .25, .2) TH.Sound() end, nil, nil,
        on = function() return pfThreatAlert and pfThreatAlert:IsShown() end },
      { "Open a threat window", function()
        local w = M.AddWindow()
        if w then M.SetMode(w, "threat") end
      end, nil, nil, on = function()
        for _, w in ipairs(M.windows or {}) do if w.mode == "threat" and w:IsShown() then return true end end
      end },
    })

    W.Card(p, "Threat meter", { tip = "Asking the server for threat. Off: no label, no popups, no threat window." })
    Chk(p, "Ask the server for threat", "After a reload.", G, "threat", Reload)
    Chk(p, "Solo with a pet too", "Out of a group with your pet tanking (Voidwalker, hunter pet): you and your pet's "
      .. "threat on your target, ESTIMATED from your hits (the server sends threat to groups only). In a group the "
      .. "server's exact numbers are used as before.", G, "threatsolo")
    Sld(p, "Update speed", "How often the server is asked (seconds). Lower = faster numbers, a little more traffic. "
      .. "Each answer is on screen the moment it arrives.", .1, 1, .05, G, "threatrate",
      function(v) return string.format("%.2f s", v) end, function() end)
    Sld(p, "Window redraw", "How often all meter windows redraw (seconds). Lower = smoother, a little more work.",
      .05, .5, .05, G, "refresh", function(v) return string.format("%.2f s", v) end, function() end)

    W.Card(p, "Your cap", { tip = "How much threat you allow yourself before the label turns red and the popup shouts." })
    Sld(p, "Stay under", "Your threat as a share of the reference below.", 10, 150, 5, G, "threatwarn", Pct2, function() end)
    Drop(p, "...of", "The pull point: where the mob turns to you (110% of the tank's threat in melee, 130% at range). "
      .. "The top player: stay behind the tank; the top two or three: behind the off-tank or a big hitter too.",
      List(TH.REFS), G, "threatref", function() end)
    Sld(p, "Yellow from", "The label turns yellow at this share of your cap.", 50, 95, 5, G, "tnear", Pct2, function() end)
    W.Buttons(p, {
      { "Safe 70%", function() C.meters.threatwarn, C.meters.threatref = "70", "1" O:Refresh() end,
        on = function() return C.meters.threatwarn == "70" and C.meters.threatref == "1" end },
      { "Push 90%", function() C.meters.threatwarn, C.meters.threatref = "90", "1" O:Refresh() end,
        on = function() return C.meters.threatwarn == "90" and C.meters.threatref == "1" end },
      { "Edge 100%", function() C.meters.threatwarn, C.meters.threatref = "100", "1" O:Refresh() end,
        on = function() return C.meters.threatwarn == "100" and C.meters.threatref == "1" end },
    })

    W.Card(p, "Label", { tip = "The label by your target's nameplate (or in a box you place)." })
    Chk(p, "Show the label", nil, G, "tlabel", function() end)
    Drop(p, "Show it as", nil, List(TH.LOOKS), G, "tlook", function() end)
    Drop(p, "Where", "A box I place: move the \"Threat Box\" with Move frames.", List(TH.PLACES), G, "twhere", function() end)
    Sld(p, "Across", nil, -150, 150, 1, G, "tx", Px, function() end)
    Sld(p, "Up / down", nil, -100, 100, 1, G, "ty", Px, function() end)
    Sld(p, "Text size", nil, 8, 30, 1, G, "tsize", Px, function() end)
    Drop(p, "Outline", nil, List({ { "NONE", "None" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" } }), G, "toutline", function() end)
    Chk(p, "With aggro: the next player", "\"Aggro  next 92%\" - for tanks.", G, "tnext", function() end)
    Chk(p, "...and their name", "\"Aggro  next Jaina 92%\".", G, "tnextname", function() end)

    W.Card(p, "Colours")
    Color(p, "Safe", nil, G, "tcolsafe", function() end)
    Color(p, "Near your cap", nil, G, "tcolnear", function() end)
    Color(p, "Past your cap", nil, G, "tcolover", function() end)
    Color(p, "Aggro", nil, G, "tcolaggro", function() end)

    W.Card(p, "Popups", { tip = "A big line in the middle of the screen, once each time you cross your cap." })
    Chk(p, "Shout when I pass my cap", nil, G, "threatflash", function() end)
    Chk(p, "Also when I pull aggro", "\"AGGRO!\" - tanks may want this off.", G, "threataggro", function() end)
    W.Edit(p, "Message", nil, function() return C.meters.threatpopup or "" end, function(v)
      if v and v ~= "" then C.meters.threatpopup = v end
    end)
    Chk(p, "Sound", nil, G, "threatsound", function() end)
    local CT = pfUI.sctB and pfUI.sctB.SCT
    local sounds = {}
    for _, s in ipairs(CT and CT.SOUNDS or { { key = "RaidWarning", label = "Raid warning" } }) do
      if s.key then table.insert(sounds, { key = s.key, label = s.label }) end
    end
    W.Dropdown(p, "Which sound", "Picking one plays it.", sounds, function() return C.meters.threatsoundkey end, function(v)
      C.meters.threatsoundkey = v
      if CT and CT.PlaySound then CT.PlaySound(v) end
    end)
  end

  O.replaced[T["Meters"]] = true
  O:AddPage("Meters", "mtwindows", "Windows", BuildWindows)
  O:AddPage("Meters", "mtdata", "Data", BuildData)
  O:AddPage("Meters", "mtthreat", "Threat", BuildThreat)
end)
