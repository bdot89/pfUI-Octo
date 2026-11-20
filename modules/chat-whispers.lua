pfUI:RegisterModule("chat-whispers", "vanilla:tbc", function ()
  -- pfUI Octo :: whisper window (chat phase 3, docs\chat-spec.md, 23 Oct
  -- 2026; the user asked for "automatic whisper window options" from Prat -
  -- Prat hands this to WIM; both are other people's code, nothing copied).
  -- (20 Nov 2026, user: "it is highly spammed and when doing masterlooting ... it opens 10 windows at once when people
  -- bid with a whisper to me ... make one window with tabs in for people one bar that controls them all make it simple
  -- and easy to navigate") ONE window: a tab per person down the left (class icon, name in class colour, unread
  -- count), the conversation of the picked one on the right with a box to answer in, and one bar on top that works
  -- on the picked person (invite / target / who / close) and the window (fold). A new whisper never steals the
  -- tab you are on or your typing: its tab lights up and counts. Tab in the answer box jumps to the next unread one.
  -- Right-click a tab to close it; shift-click the bar's x to close them all. In combat a new whisper can wait
  -- until it ends, or open folded. The last lines per person are kept (pfUI_cache.whispers) for next time.
  -- Settings C.chat.whisper; options: Chat > Whispers.
  local WH = { windows = {}, order = {}, queue = {}, scroll = 0 }
  pfUI.whispers = WH
  local function S() return C.chat.whisper end
  local ME = UnitName("player")
  local TABH = 20

  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function Font() return pfUI.font_default, tonumber(S().fontsize) or 12 end
  local function Store()
    pfUI_cache.whispers = pfUI_cache.whispers or {}
    local key = (ME or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
    pfUI_cache.whispers[key] = pfUI_cache.whispers[key] or {}
    return pfUI_cache.whispers[key]
  end

  -- who someone is: class, level, guild (pfUI's unit scan; asks for it)
  local function Who(name)
    local class, level, _, _, guild
    if GetUnitData then class, level, _, _, guild = GetUnitData(name, true) end
    if (not level or level == 0) and pfUI.chatPlus and pfUI.chatPlus.levels then level = pfUI.chatPlus.levels[name] end
    return class, level, guild
  end
  WH.Who = Who
  local function Hex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return nil end
    return string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
  end
  local function SetIcon(tex, class)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
      tex:SetTexture(pfUI.media["img:classicons"])
      tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      tex:Show()
    else
      tex:Hide()
    end
  end

  local function Btn(parent, label, tip, fn)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(18)
    b:SetHeight(18)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b:SetBackdropColor(.1, .1, .12, 1)
    b:SetBackdropBorderColor(.25, .25, .28, 1)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(pfUI.font_default, 10, "OUTLINE")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function()
      local r, g, bb = Accent()
      this:SetBackdropBorderColor(r, g, bb, 1)
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(tip, 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() this:SetBackdropBorderColor(.25, .25, .28, 1) GameTooltip:Hide() end)
    return b
  end

  -- ---------------------------------------------------------------- the one window

  local H
  local function Hub()
    if H then return H end
    H = CreateFrame("Frame", "pfWhisperHub", UIParent)
    H:SetFrameStrata("MEDIUM")
    H:SetWidth(tonumber(S().hubwidth) or 440)
    H:SetHeight(tonumber(S().hubheight) or 230)
    H:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    H:SetMovable(true)
    H:SetResizable(true)
    H:EnableMouse(true)
    H:SetClampedToScreen(true)
    if H.SetMinResize then H:SetMinResize(280, 130) end
    H:SetScript("OnMouseDown", function() WH.Seen(WH.windows[WH.active]) end)

    -- the bar: drag to move, click to fold; its buttons work on the picked person
    local bar = CreateFrame("Button", nil, H)
    bar:SetPoint("TOPLEFT", H, "TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", H, "TOPRIGHT", -1, -1)
    bar:SetHeight(22)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() H:StartMoving() end)
    bar:SetScript("OnDragStop", function()
      H:StopMovingOrSizing()
      S().x, S().y = tostring(math.floor(H:GetLeft() + .5)), tostring(math.floor(H:GetTop() + .5))
    end)
    bar:SetScript("OnClick", function() WH.Fold() end)
    H.bar = bar
    H.icon = bar:CreateTexture(nil, "ARTWORK")
    H.icon:SetWidth(16)
    H.icon:SetHeight(16)
    H.icon:SetPoint("LEFT", bar, "LEFT", 4, 0)
    H.title = bar:CreateFontString(nil, "OVERLAY")
    H.title:SetFont(pfUI.font_default, 12, "OUTLINE")
    H.title:SetPoint("LEFT", H.icon, "RIGHT", 4, 0)
    H.title:SetJustifyH("LEFT")

    local function Who_() return WH.active end
    H.close = Btn(bar, "x", "Close this conversation (it is kept)\nShift-click: close them all", function()
      if IsShiftKeyDown() then WH.CloseAll() else WH.Close(Who_()) end
    end)
    H.close:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    H.fold = Btn(bar, "_", "Fold / unfold the window", function() WH.Fold() end)
    H.fold:SetPoint("RIGHT", H.close, "LEFT", -2, 0)
    H.whob = Btn(bar, "?", "/who - level, guild and zone", function() if Who_() then SendWho("n-" .. Who_()) end end)
    H.whob:SetPoint("RIGHT", H.fold, "LEFT", -8, 0)
    H.target = Btn(bar, "T", "Target them (when near)", function() if Who_() then TargetByName(Who_(), true) end end)
    H.target:SetPoint("RIGHT", H.whob, "LEFT", -2, 0)
    H.invite = Btn(bar, "+", "Invite to your group", function() if Who_() then InviteByName(Who_()) end end)
    H.invite:SetPoint("RIGHT", H.target, "LEFT", -2, 0)
    -- the green "+3": new messages waiting; click it to go to the oldest one
    local badge = CreateFrame("Button", nil, bar)
    badge:SetHeight(18)
    badge:SetWidth(1)
    badge:SetPoint("RIGHT", H.invite, "LEFT", -8, 0)
    badge:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    badge:SetBackdropColor(.05, .45, .12, 1)
    badge:SetBackdropBorderColor(.3, 1, .4, 1)
    badge.text = badge:CreateFontString(nil, "OVERLAY")
    badge.text:SetFont(pfUI.font_default, 12, "OUTLINE")
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badge.text:SetTextColor(.6, 1, .6)
    badge:SetScript("OnClick", function() WH.GoNew() end)
    badge:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText("New messages", .4, 1, .5)
      -- oldest first: the order Tab and this button take them in
      local list = {}
      for _, n in ipairs(WH.order) do
        local c = WH.windows[n]
        if c.open and (c.unread or 0) > 0 then table.insert(list, c) end
      end
      table.sort(list, function(a, b) return (a.since or 0) < (b.since or 0) end)
      for _, c in ipairs(list) do
        GameTooltip:AddDoubleLine((Hex(Who(c.who)) or "|cffffffff") .. c.who .. "|r  " .. (c.last or ""), "+" .. c.unread, 1, 1, 1, .4, 1, .5)
      end
      GameTooltip:AddLine("Click: go to the oldest one (Tab in the box: the next)", .7, .7, .7)
      GameTooltip:Show()
    end)
    badge:SetScript("OnLeave", function() GameTooltip:Hide() end)
    badge:Hide()
    H.badge = badge
    H.title:SetPoint("RIGHT", badge, "LEFT", -4, 0)

    -- the tabs down the left (the mouse wheel scrolls them when there are many)
    local list = CreateFrame("Frame", nil, H)
    list:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 2, -3)
    list:SetPoint("BOTTOMLEFT", H, "BOTTOMLEFT", 3, 4)
    list:SetWidth(tonumber(S().tabwidth) or 120)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function()
      WH.scroll = WH.scroll - arg1
      WH.Layout()
    end)
    H.list = list
    list.more = list:CreateFontString(nil, "OVERLAY")
    list.more:SetFont(pfUI.font_default, 10, "OUTLINE")
    list.more:SetPoint("BOTTOM", list, "BOTTOM", 0, 0)
    list.more:SetTextColor(.6, .6, .6)
    local line = H:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(.2, .2, .24, 1)
    line:SetWidth(1)
    line:SetPoint("TOPLEFT", list, "TOPRIGHT", 2, 0)
    line:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 2, 0)

    -- the picked conversation goes here
    local page = CreateFrame("Frame", nil, H)
    page:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
    page:SetPoint("BOTTOMRIGHT", H, "BOTTOMRIGHT", -4, 26)
    H.page = page

    -- the box to answer in (one, for whoever is picked)
    local eb = CreateFrame("EditBox", nil, H)
    -- (an edit box with no font shows no text and errors on typing in 1.12)
    if eb.SetFontObject and ChatFontNormal then eb:SetFontObject(ChatFontNormal) end
    if eb.SetFont then eb:SetFont(Font()) end
    eb:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", -2, -22)
    eb:SetPoint("BOTTOMRIGHT", H, "BOTTOMRIGHT", -16, 4)
    eb:SetHeight(18)
    eb:SetAutoFocus(false)
    if eb.SetTextInsets then eb:SetTextInsets(4, 4, 0, 0) end
    eb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    eb:SetBackdropColor(0, 0, 0, .6)
    eb:SetBackdropBorderColor(.25, .25, .28, 1)
    eb:SetScript("OnEnterPressed", function()
      local text = this:GetText()
      if text and text ~= "" and WH.active then WH.Send(WH.active, text) end
      this:SetText("")
    end)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    -- Tab: the next one with something unread (or just the next one); Shift-Tab goes back
    eb:SetScript("OnTabPressed", function() WH.Next(IsShiftKeyDown() and -1 or 1) end)
    eb:SetScript("OnEditFocusGained", function() this.focused = true WH.Seen(WH.windows[WH.active]) end)
    -- (1.12 edit boxes have no HasFocus: the focus is noted here)
    eb:SetScript("OnEditFocusLost", function() this.focused = nil end)
    H.edit = eb

    -- the corner grip: drag to size
    local grip = CreateFrame("Button", nil, H)
    grip:SetWidth(12)
    grip:SetHeight(12)
    grip:SetPoint("BOTTOMRIGHT", H, "BOTTOMRIGHT", -1, 1)
    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetAllPoints(grip)
    grip.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    grip.tex:SetVertexColor(.4, .4, .45, .6)
    grip:SetScript("OnMouseDown", function() H:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
      H:StopMovingOrSizing()
      S().hubwidth, S().hubheight = tostring(math.floor(H:GetWidth() + .5)), tostring(math.floor(H:GetHeight() + .5))
      WH.Layout()
    end)
    H.grip = grip

    -- unread tabs (and the window edge, while you are not typing in it) pulse
    -- (green, like the "+3" badge, which pulses with them)
    H:SetScript("OnUpdate", function()
      local r, g, b = .3, 1, .4
      local a = .55 + .45 * math.abs(math.sin(GetTime() * 3))
      if H.badge:IsShown() then
        H.badge:SetBackdropBorderColor(r, g, b, a)
        H.badge:SetBackdropColor(.05, .3 + .2 * a, .12, 1)
      end
      local any
      for _, c in pairs(WH.windows) do
        if c.unread and c.unread > 0 and c.tab:IsShown() then
          any = true
          c.tab:SetBackdropBorderColor(r, g, b, a)
        end
      end
      local lit = any and not H.edit.focused
      if lit then H:SetBackdropBorderColor(r, g, b, a)
      elseif this.lit then H:SetBackdropBorderColor(.2, .2, .24, 1) end
      this.lit = lit
    end)
    H:SetScript("OnSizeChanged", function() WH.Layout() end)
    -- (19 Nov 2026: "no window opens with the test") a new frame counts as shown in the real client: made hidden,
    -- it is placed and shown like any other
    H:Hide()
    WH.hub = H
    return H
  end

  local function Place()
    local x, y = tonumber(S().x), tonumber(S().y)
    H:ClearAllPoints()
    if x and y then H:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    else H:SetPoint("CENTER", UIParent, "CENTER", 200, 80) end
  end

  -- one person: a tab and a page of lines
  local function Make(name)
    Hub()
    local c = { who = name, unread = 0 }
    local tab = CreateFrame("Button", nil, H.list)
    tab:SetHeight(TABH)
    tab:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetWidth(14)
    tab.icon:SetHeight(14)
    tab.icon:SetPoint("LEFT", tab, "LEFT", 3, 0)
    tab.count = tab:CreateFontString(nil, "OVERLAY")
    tab.count:SetFont(pfUI.font_default, 10, "OUTLINE")
    tab.count:SetPoint("RIGHT", tab, "RIGHT", -4, 0)
    tab.count:SetTextColor(.4, 1, .5)
    tab.text = tab:CreateFontString(nil, "OVERLAY")
    tab.text:SetFont(pfUI.font_default, 11, "OUTLINE")
    tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 3, 0)
    tab.text:SetPoint("RIGHT", tab.count, "LEFT", -2, 0)
    tab.text:SetJustifyH("LEFT")
    tab.who = name
    tab:SetScript("OnClick", function()
      if arg1 == "RightButton" then WH.Close(this.who) else WH.Select(this.who) end
    end)
    tab:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText(this.who, 1, 1, 1)
      GameTooltip:AddLine("Click: show   Right-click: close (it is kept)", .7, .7, .7)
      GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tab:Hide()
    c.tab = tab

    local msg = CreateFrame("ScrollingMessageFrame", nil, H.page)
    -- (19 Nov 2026, mechanism: "new whisper window per person seems to not be working") a font straight away: the 1.12
    -- client refuses AddMessage on a message frame with none, and the kept conversation goes in before WH.Paint
    if msg.SetFontObject and ChatFontNormal then msg:SetFontObject(ChatFontNormal) end
    if msg.SetFont then msg:SetFont(Font()) end
    msg:SetAllPoints(H.page)
    if msg.SetFading then msg:SetFading(false) end
    if msg.SetMaxLines then msg:SetMaxLines(200) end
    if msg.SetJustifyH then msg:SetJustifyH("LEFT") end
    msg:EnableMouseWheel(true)
    msg:SetScript("OnMouseWheel", function()
      if arg1 > 0 then if this.ScrollUp then this:ScrollUp() end elseif this.ScrollDown then this:ScrollDown() end
    end)
    msg:SetScript("OnMouseDown", function() WH.Seen(WH.windows[WH.active]) end)
    msg:Hide()
    c.msg = msg
    c.edit = H.edit
    function c:IsShown() return self.open and H:IsShown() end
    return c
  end

  -- the tabs in order, the ones that do not fit scrolled away
  function WH.Layout()
    if not H then return end
    local open = {}
    for _, name in ipairs(WH.order) do if WH.windows[name].open then table.insert(open, name) end end
    local fit = math.max(1, math.floor(((H.list:GetHeight() or 0) - 12) / (TABH + 1)))
    if table.getn(open) <= fit then fit = table.getn(open) end
    WH.fit = fit
    local most = math.max(0, table.getn(open) - fit)
    if WH.scroll > most then WH.scroll = most end
    if WH.scroll < 0 then WH.scroll = 0 end
    local y = 0
    for i, name in ipairs(open) do
      local tab = WH.windows[name].tab
      tab:ClearAllPoints()
      if i > WH.scroll and i <= WH.scroll + fit then
        tab:SetPoint("TOPLEFT", H.list, "TOPLEFT", 0, -y)
        tab:SetPoint("TOPRIGHT", H.list, "TOPRIGHT", 0, -y)
        tab:Show()
        y = y + TABH + 1
      else
        tab:Hide()
      end
    end
    -- how many are scrolled away, with their unread count
    local hidden, waiting = 0, 0
    for i, name in ipairs(open) do
      if i <= WH.scroll or i > WH.scroll + fit then
        hidden = hidden + 1
        waiting = waiting + (WH.windows[name].unread or 0)
      end
    end
    if hidden > 0 then
      H.list.more:SetText(hidden .. " more" .. (waiting > 0 and ("  |cff66ff66+" .. waiting .. "|r") or "") .. "  (scroll)")
    else
      H.list.more:SetText("")
    end
    WH.PaintBadge()
  end

  -- a tab's look, and the bar when it is the picked one
  function WH.Paint(c)
    if not c then return end
    local class, level, guild = Who(c.who)
    local hex = Hex(class)
    local active = WH.active == c.who
    SetIcon(c.tab.icon, class)
    c.tab.text:SetText((hex or "|cffffffff") .. c.who .. "|r")
    c.tab.count:SetText((c.unread or 0) > 0 and ("+" .. c.unread) or "")
    local r, g, b = Accent()
    if active then
      c.tab:SetBackdropColor(r * .35, g * .35, b * .35, 1)
      c.tab:SetBackdropBorderColor(r, g, b, 1)
    else
      c.tab:SetBackdropColor(.1, .1, .12, 1)
      if (c.unread or 0) == 0 then c.tab:SetBackdropBorderColor(.2, .2, .24, 1) end
    end
    local font, size = Font()
    if c.msg.SetFont then c.msg:SetFont(font, size, "") end
    if not active then return end
    SetIcon(H.icon, class)
    local extra = ""
    if level and level ~= 0 then extra = " |cff999999" .. level .. "|r" end
    if guild and guild ~= "" then extra = extra .. " |cff66cc66<" .. guild .. ">|r" end
    if c.test then extra = extra .. " |cff888888(test)|r" end
    H.title:SetText((hex or "|cffffffff") .. c.who .. "|r" .. extra)
    local bg = c.test and .1 or .06
    H:SetBackdropColor(bg, bg, .08, .94)
    H.bar.bg:SetVertexColor(.12, .12, .15, 1)
    if H.edit.SetFont then H.edit:SetFont(font, size, "") end
  end
  function WH.PaintAll() for _, c in pairs(WH.windows) do WH.Paint(c) end WH.PaintBadge() end

  -- ---------------------------------------------------------------- messages

  local function Stamp(t) return "|cff888888" .. date("%H:%M", t) .. "|r " end
  -- one line in someone's page (dir: "in", "out", "sys")
  local function Line(c, dir, text, t)
    local r, g, b = 1, .5, 1
    local who
    if dir == "out" then
      r, g, b = .75, .55, .9
      who = "|cff999999" .. (ME or "Me") .. ":|r "
    elseif dir == "sys" then
      r, g, b = .7, .7, .7
      who = ""
    else
      who = (Hex(Who(c.who)) or "|cffffffff") .. c.who .. ":|r "
    end
    c.msg:AddMessage(Stamp(t) .. who .. text, r, g, b)
  end

  -- keep the conversation (the last lines per person)
  local function Keep(name, dir, text, t)
    -- (the made-up test conversations are not kept)
    if WH.windows[name] and WH.windows[name].test then return end
    local s = Store()
    s[name] = s[name] or {}
    table.insert(s[name], { t = t, dir = dir, msg = text })
    local keep = tonumber(S().history) or 50
    while table.getn(s[name]) > keep do table.remove(s[name], 1) end
  end

  -- someone's tab: made (with the kept lines) and in the list
  local function Ensure(name)
    local c = WH.windows[name]
    if not c then
      c = Make(name)
      WH.windows[name] = c
      table.insert(WH.order, name)
      for _, e in ipairs(Store()[name] or {}) do Line(c, e.dir, e.msg, e.t) end
      if table.getn(Store()[name] or {}) > 0 then c.msg:AddMessage("|cff666666- earlier -|r") end
    end
    if not c.open then
      c.open = true
      WH.Layout()
    end
    return c
  end

  local function ShowHub()
    if not H:IsShown() then
      H:SetWidth(tonumber(S().hubwidth) or 440)
      H:SetHeight(H.folded and 24 or (tonumber(S().hubheight) or 230))
      Place()
      H:Show()
      WH.Layout()
    end
  end

  -- pick whose conversation is shown
  function WH.Select(name)
    local c = WH.windows[name]
    if not c then return end
    local old = WH.active and WH.windows[WH.active]
    WH.active = name
    for _, o in pairs(WH.windows) do if o ~= c then o.msg:Hide() end end
    if not H.folded then c.msg:Show() end
    if old and old ~= c then WH.Paint(old) end
    -- scrolled away? bring its tab into view
    local i = 0
    for _, n in ipairs(WH.order) do
      if WH.windows[n].open then i = i + 1 end
      if n == name then break end
    end
    if i <= WH.scroll then WH.scroll = i - 1 WH.Layout()
    elseif i > WH.scroll + (WH.fit or 1) then WH.scroll = i - (WH.fit or 1) WH.Layout() end
    WH.Seen(c)
  end

  -- open someone's tab, pick it and show the window
  function WH.Open(name, quiet)
    if not name then return end
    local c = Ensure(name)
    ShowHub()
    WH.Select(name)
    if not quiet and not H.folded then H.edit:SetFocus() end
    return c
  end

  function WH.Add(name, dir, text, t)
    t = t or time()
    if not (name and text) then return end
    Keep(name, dir, text, t)
    local c = WH.windows[name]
    if not (c and c:IsShown()) and UnitAffectingCombat("player") and S().combat == "wait" then
      -- (a tab made earlier keeps its lines: this one goes in it too)
      if c then
        if dir == "in" and (c.unread or 0) == 0 then c.msg:AddMessage("|cff33ff33--------  new  --------|r") end
        Line(c, dir, text, t)
        if dir == "in" then WH.Mark(c, text) end
      end
      WH.queue[name] = true
      return
    end
    local fresh = not c
    c = Ensure(name)
    -- (a new tab showed the kept lines, this one among them)
    local wasHidden = not H:IsShown()
    -- (20 Nov 2026, user: "it shows on this bar with green +1 ... when you open it will go to the new message. Or start
    -- in order of oldest new message to newest") unread unless it is the conversation you are looking at
    local viewing = WH.active == name and H:IsShown() and not H.folded
    local unread = dir == "in" and not viewing
    -- a "new" line where the unread part starts
    if not fresh and unread and (c.unread or 0) == 0 then c.msg:AddMessage("|cff33ff33--------  new  --------|r") end
    -- (a new tab showed the kept lines, this one among them)
    if not fresh then Line(c, dir, text, t) end
    if wasHidden then
      if UnitAffectingCombat("player") and S().combat == "fold" then H.folded = true WH.ApplyFold() end
      ShowHub()
    end
    -- a new whisper never takes the tab you are on: it is picked only when nothing is, or the window was shut
    if wasHidden or not WH.active or not WH.windows[WH.active].open then
      WH.Select(name)
    elseif WH.active == name and dir == "out" then
      WH.Seen(c)
    end
    if unread then WH.Mark(c, text) end
    WH.Paint(c)
    WH.Layout()
    return c
  end

  -- one more unread line for someone (the oldest new one is answered first)
  WH.seq = 0
  function WH.Mark(c, text)
    if (c.unread or 0) == 0 then
      WH.seq = WH.seq + 1
      c.since = WH.seq
    end
    c.unread = (c.unread or 0) + 1
    c.last = text
  end

  function WH.Seen(c)
    if not c then return end
    c.unread = 0
    c.since = nil
    WH.Paint(c)
    WH.Layout()
  end

  -- the open tab waiting longest with something new
  function WH.Oldest(skip)
    local best
    for _, n in ipairs(WH.order) do
      local c = WH.windows[n]
      if c.open and n ~= skip and (c.unread or 0) > 0 and (not best or (c.since or 0) < (WH.windows[best].since or 0)) then best = n end
    end
    return best
  end
  function WH.Unread()
    local total, people = 0, 0
    for _, c in pairs(WH.windows) do
      if c.open and (c.unread or 0) > 0 then total = total + c.unread people = people + 1 end
    end
    return total, people
  end

  -- Tab: the oldest new message first (or just the next tab); Shift-Tab: the tab before
  function WH.Next(dir)
    if dir == 1 then
      local o = WH.Oldest(WH.active)
      if o then WH.Select(o) return o end
    end
    local open = {}
    local at = 1
    for _, n in ipairs(WH.order) do
      if WH.windows[n].open then
        table.insert(open, n)
        if n == WH.active then at = table.getn(open) end
      end
    end
    local n = table.getn(open)
    if n < 2 then return end
    local i = math.mod(at - 1 + dir + n * 2, n) + 1
    WH.Select(open[i])
    return open[i]
  end

  -- the green "+3" on the bar, and while folded the newest line in the title
  function WH.PaintBadge()
    if not H then return end
    local total, people = WH.Unread()
    local b = H.badge
    if total == 0 then
      b:Hide()
      b:SetWidth(1)
      if H.folded and WH.active then WH.Paint(WH.windows[WH.active]) end
      return
    end
    b.text:SetText("+" .. total .. (people > 1 and ("  |cffccffcc" .. people .. " people|r") or ""))
    b:SetWidth(math.floor((b.text:GetStringWidth() or 20) + 14))
    b:Show()
    if H.folded then
      -- the newest of the new lines
      local newest
      for _, c in pairs(WH.windows) do
        if c.open and (c.unread or 0) > 0 and (not newest or (c.since or 0) > (newest.since or 0)) then newest = c end
      end
      if newest then
        SetIcon(H.icon, (Who(newest.who)))
        H.title:SetText((Hex(Who(newest.who)) or "|cffffffff") .. newest.who .. ":|r |cffffffff" .. (newest.last or "") .. "|r")
      end
    end
  end

  -- open on the oldest new message
  function WH.GoNew()
    if not H then return end
    if H.folded then H.folded = false WH.ApplyFold() end
    local o = WH.Oldest()
    if o then WH.Select(o) end
    H.edit:SetFocus()
  end

  function WH.ApplyFold()
    if not H then return end
    if H.folded then
      H:SetHeight(24)
      H.list:Hide() H.page:Hide() H.edit:Hide() H.grip:Hide()
    else
      H:SetHeight(tonumber(S().hubheight) or 230)
      H.list:Show() H.page:Show() H.edit:Show() H.grip:Show()
      local c = WH.active and WH.windows[WH.active]
      if c then c.msg:Show() end
      WH.Layout()
    end
  end
  -- fold (true), unfold (false) or flip (nil) the window
  function WH.Fold(_, fold)
    if not H then return end
    if fold == nil then fold = not H.folded end
    local was = H.folded
    H.folded = fold
    WH.ApplyFold()
    -- unfolding goes to the oldest new message
    if was and not fold then
      local o = WH.Oldest()
      if o then WH.Select(o) end
    end
    WH.Layout()
  end

  -- close someone's tab (the conversation is kept); the window goes with the last one
  function WH.Close(name)
    local c = name and WH.windows[name]
    if not c then return end
    c.open = nil
    c.unread = 0
    c.tab:Hide()
    c.msg:Hide()
    if WH.active == name then
      WH.active = nil
      for _, n in ipairs(WH.order) do if WH.windows[n].open then WH.Select(n) break end end
    end
    if not WH.active then H:Hide() end
    WH.Layout()
  end
  function WH.CloseAll()
    for name in pairs(WH.windows) do WH.Close(name) end
    if H then H:Hide() end
  end

  -- send from the window (the test conversation only talks to itself)
  function WH.Send(name, text)
    local c = WH.windows[name]
    if c and c.test then
      WH.Add(name, "out", text)
      WH.Add(name, "in", "(test) You said: " .. text)
      return
    end
    SendChatMessage(text, "WHISPER", nil, name)
  end

  -- made-up conversations to try the window (nothing is sent): one picked, two waiting
  WH.TEST = "Thrall"
  WH.TESTS = { "Bidwell", "Needsalot" }
  function WH.Test()
    local c = Ensure(WH.TEST)
    c.test = true
    WH.Open(WH.TEST, true)
    WH.Add(WH.TEST, "in", "Hey, are you coming to Onyxia tonight?")
    WH.Add(WH.TEST, "out", "Yes, after dinner")
    WH.Add(WH.TEST, "in", "Great - bring fire resistance gear (this is a test: type here, nothing is sent)")
    for i, who in ipairs(WH.TESTS) do
      Ensure(who).test = true
      WH.Add(who, "in", i == 1 and "bid 50" or "need for main spec pls")
    end
    WH.Seen(c)
    WH.Paint(c)
    return c
  end

  -- ---------------------------------------------------------------- whispers in the main chat

  -- with "also in chat" off, the chat windows stop listening to whispers
  -- (and listen again when it is back on)
  function WH.ApplyChat()
    local off = S().mode == "window" and S().alsochat == "0"
    WH.removed = WH.removed or {}
    for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
      local f = _G["ChatFrame" .. i]
      if f and f.messageTypeList then
        local has
        for _, m in pairs(f.messageTypeList) do if m == "WHISPER" then has = true end end
        if off and has then
          ChatFrame_RemoveMessageGroup(f, "WHISPER")
          WH.removed[i] = true
        elseif not off and WH.removed[i] and not has then
          ChatFrame_AddMessageGroup(f, "WHISPER")
          WH.removed[i] = nil
        end
      end
    end
  end

  -- ---------------------------------------------------------------- events

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_AFK", "CHAT_MSG_DND",
                       "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "WHO_LIST_UPDATE" }) do ev:RegisterEvent(e) end
  function WH.OnEvent(evt, a1, a2)
    if evt == "PLAYER_ENTERING_WORLD" then WH.ApplyChat() return end
    if evt == "PLAYER_REGEN_ENABLED" then
      -- the ones that waited for the fight to end
      for name in pairs(WH.queue) do
        local c = Ensure(name)
        ShowHub()
        if not WH.active or not WH.windows[WH.active].open then WH.Select(name) end
        WH.Paint(c)
      end
      WH.queue = {}
      if H and H.folded and H:IsShown() then WH.Fold(nil, false) end
      WH.Layout()
      return
    end
    if evt == "WHO_LIST_UPDATE" then WH.PaintAll() return end
    if S().mode ~= "window" then return end
    if evt == "CHAT_MSG_WHISPER" then
      local c = WH.Add(a2, "in", a1)
      if c and S().sound and S().sound ~= "none" then
        local CT = pfUI.sctB and pfUI.sctB.SCT
        if CT and CT.PlaySound then CT.PlaySound(S().sound) else PlaySound(S().sound) end
      end
    elseif evt == "CHAT_MSG_WHISPER_INFORM" then
      WH.Add(a2, "out", a1)
    elseif (evt == "CHAT_MSG_AFK" or evt == "CHAT_MSG_DND") and WH.windows[a2] then
      WH.Add(a2, "sys", (evt == "CHAT_MSG_AFK" and "is away: " or "does not want to be disturbed: ") .. (a1 or ""))
    end
  end
  ev:SetScript("OnEvent", function() WH.OnEvent(event, arg1, arg2) end)

  _G.SLASH_OCTOWHISPERS1 = "/whispers"
  _G.SlashCmdList.OCTOWHISPERS = function(msg)
    if msg == "close" then WH.CloseAll() return end
    if msg == "test" then WH.Test() return end
    -- reopen everyone you talked to (the kept conversations)
    local first
    for name in pairs(Store()) do Ensure(name) first = first or name end
    if not first then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: no whispers yet (/whispers test shows a test window).")
      return
    end
    WH.Open(WH.active or first, true)
  end
end)
