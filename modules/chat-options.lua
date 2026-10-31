pfUI:RegisterModule("chat-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Chat section (phase 1 of docs\chat-spec.md, 23 Oct
  -- 2026). User: "I want to add prat to our addon ... menu feels messy could
  -- we use a preview here also ? with window toggles etc to test whats
  -- what". Every setting of pfUI's Chat page (hidden from the topic list and
  -- Find now) on three pages, each with the same pinned preview: your chat
  -- panels with their tabs and typing box, showing a line of every kind
  -- drawn with your settings. Click a line, a tab, the timestamps or the
  -- typing box for its card; Shift + wheel over the lines = chat font size;
  -- the switches over it turn real windows on and off (lit while on).
  -- Prat is GPL-3: its option list was read for names only, nothing copied.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local CH = {}
  pfUI.chatOcto = CH

  local function TX() return C.chat.text end
  local function GL() return C.chat.global end
  local function LF() return C.chat.left end
  local function RT() return C.chat.right end
  local function BB() return C.chat.bubbles end
  local function PL() return C.chat.plus end
  local function Px(v) return v .. " px" end
  local function Reload() if pfUI.gui then pfUI.gui.settingChanged = true end end
  local function Refresh() if pfUI.chat and pfUI.chat.RefreshChat then pcall(pfUI.chat.RefreshChat, pfUI.chat) end end

  -- the panels' size and colours, live
  function CH.Apply()
    local c = pfUI.chat
    if not c then return end
    if c.left then c.left:SetWidth(tonumber(LF().width) or 380) c.left:SetHeight(tonumber(LF().height) or 180) end
    if c.right then c.right:SetWidth(tonumber(RT().width) or 380) c.right:SetHeight(tonumber(RT().height) or 180) end
    for _, p in ipairs({ c.left, c.right }) do
      if p and p.backdrop then
        local bg = GL().custombg == "1" and GL().background or C.appearance.border.background
        local ed = GL().custombg == "1" and GL().border or C.appearance.border.color
        local r, g, b, a = GetStringColor(bg)
        p.backdrop:SetBackdropColor(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or .8)
        r, g, b, a = GetStringColor(ed)
        p.backdrop:SetBackdropBorderColor(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 1)
      end
    end
    for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
      local f = _G["ChatFrame" .. i]
      if f and f.SetMaxLines then f:SetMaxLines(tonumber(GL().maxlines) or 128) end
    end
    Refresh()
    if CH.Layout then CH.Layout() end
  end
  local function Up() CH.Apply() end

  local function Chk(p, label, desc, group, key, after) return O.PfChk(p, label, desc, group, key, after or Up) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt, after) return O.PfSld(p, label, desc, min, max, step, group, key, after or Up, fmt) end
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
  local function Edit(p, label, desc, group, key, after)
    return W.Edit(p, label, desc, function() return group()[key] end, function(v)
      group()[key] = v or ""
      ;(after or Up)()
    end, 200)
  end

  -- ---------------------------------------------------------------- windows

  -- a chat window by its name (GetChatWindowInfo), shown or not
  local function WindowNamed(name)
    for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
      local n, _, _, _, _, _, shown = GetChatWindowInfo(i)
      if n == name then return _G["ChatFrame" .. i], i, shown end
    end
  end
  local function Shown(i)
    local f = _G["ChatFrame" .. i]
    local _, _, _, _, _, _, shown = GetChatWindowInfo(i)
    return f and (shown or f.isDocked) and f:IsShown()
  end
  -- a closed window back, docked (FCF_OpenNewWindow does this for a new one)
  local function Open(i)
    local f, tab = _G["ChatFrame" .. i], _G["ChatFrame" .. i .. "Tab"]
    if not f then return end
    f:Show()
    if tab then tab:Show() end
    SetChatWindowShown(i, 1)
    FCF_DockFrame(f)
  end
  local function Close(i)
    local f = _G["ChatFrame" .. i]
    if not f or f == DEFAULT_CHAT_FRAME then return end
    FCF_Close(f)
    SetChatWindowShown(i, nil)
  end

  CH.WHISPERS = "Whispers"
  CH.TOGGLES = {
    { key = "spam", label = "Loot & Spam window", tip = "The second chat panel, with loot, experience and reputation.",
      on = function() return RT().enable == "1" end,
      set = function(v) if pfUI.chat and pfUI.chat.SetupRightChat then pfUI.chat.SetupRightChat(v) end Refresh() end },
    { key = "whispers", label = "Whispers tab", tip = "Whispers get a tab of their own in the left chat.",
      on = function() local f, _, shown = WindowNamed(CH.WHISPERS) return f and shown and true end,
      set = function(v)
        local f, i = WindowNamed(CH.WHISPERS)
        if v then
          if not f then
            FCF_OpenNewWindow(CH.WHISPERS)
            f, i = WindowNamed(CH.WHISPERS)
          else
            Open(i)
          end
          if f then
            ChatFrame_RemoveAllMessageGroups(f)
            ChatFrame_AddMessageGroup(f, "WHISPER")
          end
        elseif i then
          Close(i)
        end
        Refresh()
      end },
    { key = "combat", label = "Combat log tab", tip = "The game's combat log in its own tab.",
      on = function() return Shown(2) and true end,
      set = function(v) if v then GL().combathide = "0" Open(2) else Close(2) end Refresh() end },
    { key = "time", label = "Timestamps", tip = "The time in front of every line.",
      on = function() return TX().time == "1" end, set = function(v) TX().time = v and "1" or "0" end },
    { key = "class", label = "Class colours", tip = "Names in their class colour.",
      on = function() return TX().classcolor == "1" end, set = function(v) TX().classcolor = v and "1" or "0" end },
    { key = "short", label = "Short channels", tip = "Channels as their number: [2] instead of [2. Trade].",
      on = function() return TX().channelnumonly == "1" end, set = function(v) TX().channelnumonly = v and "1" or "0" end },
  }

  -- ---------------------------------------------------------------- sample lines

  local SAMPLES = {
    { "GUILD", "Thrall", "SHAMAN", "Raid at 8 - bring flasks and pots" },
    { "PARTY", "Jaina", "MAGE", "Water? |cffffffff|Hitem:8079:0:0:0|h[Conjured Crystal Water]|h|r", link = true },
    { "WHISPER", "Valeera", "ROGUE", "Can you open this lockbox?" },
    { "WHISPER_INFORM", "Valeera", "ROGUE", "Sure, on my way" },
    { "RAID", "Garrosh", "WARRIOR", "Pull in 5" },
    { "CHANNEL", "Rexxar", "HUNTER", "LFM Molten Core, need healers", channel = "2. Trade" },
    { "SAY", "Uther", "PALADIN", "Light be with you" },
    { "GUILD", "Anduin", "PRIEST", "Guide: www.example.com/raid", url = "www.example.com/raid" },
    { "YELL", "Gul'dan", "WARLOCK", "Summons at the stone!" },
    { "SAY", "Malfurion", "DRUID", "Anyone seen %s? Need a buff", me = true },
    { "SYSTEM", nil, nil, "Malfurion has come online." },
  }
  local SPAM = {
    { "LOOT", nil, nil, "You receive loot: |cff1eff00|Hitem:2771:0:0:0|h[Tin Ore]|h|rx2.", link = true },
    { "COMBAT_XP_GAIN", nil, nil, "Ogre dies, you gain 245 experience." },
    { "COMBAT_FACTION_CHANGE", nil, nil, "Your Orgrimmar reputation has increased by 25." },
    { "SKILL", nil, nil, "Your skill in Mining has increased to 142." },
  }
  -- which card a line opens
  local CARD = { WHISPER = "Whisper windows", WHISPER_INFORM = "Whisper windows", SYSTEM = "Lines", LOOT = "Loot & Spam window",
    COMBAT_XP_GAIN = "Loot & Spam window", COMBAT_FACTION_CHANGE = "Loot & Spam window", SKILL = "Loot & Spam window" }
  local TAGS = { GUILD = "G", OFFICER = "O", PARTY = "P", RAID = "R", RAID_LEADER = "RL", RAID_WARNING = "RW",
    BATTLEGROUND = "BG", SAY = "S", YELL = "Y" }

  local function Hex(r, g, b) return string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)) end
  local function TypeColor(kind)
    local key = kind == "CHANNEL" and "CHANNEL1" or kind
    local t = ChatTypeInfo and ChatTypeInfo[key]
    if t and t.r then return t.r, t.g, t.b end
    return 1, 1, 1
  end
  local function ColorOf(str)
    local r, g, b = GetStringColor(str or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1
  end

  -- a sample line as pfUI would show it: time, message
  function CH.Format(s)
    local kind, who, class, msg = s[1], s[2], s[3], s[4]
    if s.me then msg = string.format(msg, UnitName("player") or "you") end
    local br = TX().bracket or "[]"
    local bl, brr = string.sub(br, 1, 1), string.sub(br, 2, 2)
    local r, g, b = TypeColor(kind)
    local col = Hex(r, g, b)
    if s.url and TX().detecturl == "1" then msg = string.gsub(msg, s.url, "|cffccccff[" .. s.url .. "]|r" .. col) end
    local name = ""
    if who then
      local nc = col
      if TX().classcolor == "1" and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        nc = Hex(c.r, c.g, c.b)
      end
      -- (chat-plus.lua: the level next to the name)
      local lv = (PL() and PL().levels == "1") and ("|cff999999:" .. (s.level or 60) .. "|r") or ""
      name = bl .. nc .. who .. "|r" .. lv .. col .. brr
    end
    -- your name and your words highlighted in the message
    local plus = pfUI.chatPlus
    if plus and plus.Highlight and who then msg = plus.Highlight(msg) .. col end
    local text
    if kind == "WHISPER" or kind == "WHISPER_INFORM" then
      if GL().whispermod == "1" then
        local wr, wg, wb = ColorOf(GL().whisper)
        local wc = kind == "WHISPER" and Hex(wr, wg, wb) or col
        text = wc .. "[W] " .. name .. wc .. ": " .. msg
      else
        text = col .. name .. (kind == "WHISPER" and " whispers: " or " -> ") .. msg
      end
    elseif kind == "CHANNEL" then
      local tag = TX().channelnumonly == "1" and string.gsub(s.channel or "", "^(%d+)%..*", "%1") or (s.channel or "")
      -- (your own tag for that channel wins: chat-plus.lua)
      local _, _, cname = string.find(s.channel or "", "^%d+%. (.+)$")
      local own = plus and plus.Tag and plus.Tag(cname)
      if own then tag = own end
      text = col .. bl .. tag .. brr .. " " .. name .. ": " .. msg
    elseif TAGS[kind] then
      text = col .. bl .. TAGS[kind] .. brr .. " " .. name .. ": " .. msg
    else
      text = col .. msg
    end
    local stamp = ""
    if TX().time == "1" then
      local tb = TX().timebracket or "[]"
      local tr, tg, tbb = ColorOf(TX().timecolor)
      stamp = Hex(tr, tg, tbb) .. string.sub(tb, 1, 1) .. date(TX().timeformat or "%H:%M") .. string.sub(tb, 2, 2) .. "|r"
    end
    return stamp, text
  end

  -- the same lines, as the game would send them, into your real chat
  -- (local only: nothing is sent to anyone)
  function CH.TestLines()
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if not frame then return end
    for _, s in ipairs(SAMPLES) do
      local kind, who, msg = s[1], s[2], s[4]
      if s.me then msg = string.format(msg, UnitName("player") or "you") end
      local r, g, b = TypeColor(kind)
      local text
      local link = who and ("|Hplayer:" .. who .. "|h[" .. who .. "]|h") or nil
      if kind == "WHISPER" then text = string.format(CHAT_WHISPER_GET or "%s whispers: ", link) .. msg
      elseif kind == "WHISPER_INFORM" then text = string.format(CHAT_WHISPER_INFORM_GET or "To %s: ", link) .. msg
      elseif kind == "CHANNEL" then text = "[" .. (s.channel or "2") .. "] " .. link .. ": " .. msg
      elseif link and _G["CHAT_" .. kind .. "_GET"] then text = string.format(_G["CHAT_" .. kind .. "_GET"], link) .. msg
      else text = msg end
      frame:AddMessage(text, r, g, b)
    end
    CH.testAt = GetTime()
  end

  -- ---------------------------------------------------------------- preview

  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  function CH.Open(card)
    local page = (card == "Timestamps" or card == "Channel names" or card == "Names" or card == "Links"
      or card == "Whispers" or card == "Text" or card == "Highlights" or card == "Sounds" or card == "Filters") and "chmessages"
      or ((card == "Invites" or card == "Scrolling" or card == "Search") and "chinput")
      or ((card == "Whisper windows" or card == "Window look") and "chwhispers")
      or ((card == "Typing box" or card == "Chat bubbles") and "chinput") or "chwindows"
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection(page, card) else O:Open(page) end
  end
  CH.previews = {}

  local function Preview(p)
    W.Pin(p, "Preview", "Your chat with a line of every kind, drawn with your settings. Click a line, a tab, the times "
      .. "or the typing box for its settings; hold Shift and scroll the mouse wheel over the lines for bigger or smaller "
      .. "chat text. The switches turn real windows on and off. Click this bar to fold it away.", function(pp)
      -- the switches, lit while on
      local trow = W.Row(pp, 24, 0, 2)
      local tbtns = {}
      local x = 0
      for _, t in ipairs(CH.TOGGLES) do
        local b = W.Button(trow, t.label, 10, 22)
        local w = math.floor((b.label:GetStringWidth() or 60) + 18)
        b:SetWidth(w)
        b:SetPoint("LEFT", trow, "LEFT", x, 0)
        b.t = t
        b:SetScript("OnClick", function()
          local ok = pcall(this.t.set, not this.t.on())
          if CH.Layout then CH.Layout() end
          W.Lit(this, this.t.on() and true or false)
          if not ok then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: could not switch " .. this.t.label) end
        end)
        W.Tip(b, t.label, t.tip .. " Click to switch.")
        table.insert(tbtns, b)
        x = x + w + 4
      end

      local box = (W.ZoomBox or W.Box)(pp, 230)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local base = holder:GetFrameLevel()
      local ar, ag, ab = Accent()

      local function Panel(name)
        local f = CreateFrame("Button", nil, holder)
        f:SetFrameLevel(base + 2)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f.dock = CreateFrame("Frame", nil, f)
        f.dock:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
        f.dock:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
        f.dock:SetHeight(16)
        f.dock:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        f.tabs, f.lines = {}, {}
        f.name = name
        f:RegisterForClicks("LeftButtonUp")
        f:SetScript("OnClick", function() CH.Open(this.name == "spam" and "Loot & Spam window" or "Left window") end)
        f:EnableMouseWheel(true)
        return f
      end
      local left, right = Panel("left"), Panel("spam")
      left:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
      right:SetPoint("TOPRIGHT", box, "TOPRIGHT", -8, -8)

      -- the typing box under the left panel
      local edit = CreateFrame("Button", nil, holder)
      edit:SetFrameLevel(base + 3)
      edit:SetHeight(18)
      edit:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
      edit:SetBackdropColor(0, 0, 0, .8)
      edit:SetBackdropBorderColor(.3, .3, .3, 1)
      edit.text = edit:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      edit.text:SetPoint("LEFT", edit, "LEFT", 6, 0)
      edit.text:SetText("|cffffd100Guild:|r Typing here...")
      edit:SetScript("OnClick", function() CH.Open("Typing box") end)
      W.Tip(edit, "Typing box", "Click: its size. Press Enter in game to type.")

      local function Tab(panel, i)
        local t = panel.tabs[i]
        if t then return t end
        t = CreateFrame("Button", nil, panel.dock)
        t:SetHeight(14)
        t.text = t:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        t.text:SetPoint("CENTER", t, "CENTER", 0, 0)
        t:SetScript("OnClick", function() CH.Open("Tabs and dock") end)
        W.Tip(t, "Chat tab", "Click: tabs and the dock.")
        panel.tabs[i] = t
        return t
      end
      local function Line(panel, i)
        local l = panel.lines[i]
        if l then return l end
        l = CreateFrame("Button", nil, panel)
        l:SetFrameLevel(base + 4)
        l.hl = l:CreateTexture(nil, "HIGHLIGHT")
        l.hl:SetAllPoints(l)
        l.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        l.hl:SetVertexColor(ar, ag, ab, .18)
        l.stamp = CreateFrame("Button", nil, l)
        l.stamp:SetFrameLevel(base + 5)
        l.stamp.text = l.stamp:CreateFontString(nil, "OVERLAY")
        l.stamp.text:SetPoint("LEFT", l.stamp, "LEFT", 0, 0)
        l.stamp:SetScript("OnClick", function() CH.Open("Timestamps") end)
        l.text = l:CreateFontString(nil, "OVERLAY")
        l.text:SetJustifyH("LEFT")
        l:SetScript("OnClick", function() CH.Open(this.card or "Channel names") end)
        l:EnableMouseWheel(true)
        l:SetScript("OnMouseWheel", function()
          if IsShiftKeyDown() then
            local cf = ChatFrame1
            local _, size = cf:GetFont()
            size = math.max(8, math.min(24, math.floor((size or 12) + .5) + (arg1 or 0)))
            if FCF_SetChatWindowFontSize then FCF_SetChatWindowFontSize(cf, size) end
            if CH.Layout then CH.Layout() end
          elseif pfUI.plates and pfUI.plates.PassWheel then
            pfUI.plates.PassWheel(this)
          end
        end)
        l:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:AddLine(this.card or "Channel names")
          GameTooltip:AddLine("Click: its settings", 1, 1, 1)
          GameTooltip:AddLine("Shift + mouse wheel: chat text size", 1, 1, 1)
          GameTooltip:Show()
        end)
        l:SetScript("OnLeave", function() GameTooltip:Hide() end)
        panel.lines[i] = l
        return l
      end

      local function Fill(panel, list, tabs, w, h, show)
        if not show then panel:Hide() return end
        panel:Show()
        panel:SetWidth(w)
        panel:SetHeight(h)
        -- colours: your own, or pfUI's
        local custom = GL().custombg == "1"
        local r, g, b, a = GetStringColor(custom and GL().background or C.appearance.border.background)
        panel:SetBackdropColor(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or .8)
        r, g, b, a = GetStringColor(custom and GL().border or C.appearance.border.color)
        panel:SetBackdropBorderColor(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 1)
        if GL().tabdock == "1" then panel.dock:SetBackdropColor(0, 0, 0, .6) else panel.dock:SetBackdropColor(0, 0, 0, 0) end
        local tx = 4
        for i = 1, 4 do
          local t = Tab(panel, i)
          local label = tabs[i]
          if label then
            t.text:SetFont(pfUI.font_default, 10, "OUTLINE")
            t.text:SetText(label)
            if i == 1 then t.text:SetTextColor(ar, ag, ab) else t.text:SetTextColor(.75, .75, .75) end
            t:SetWidth((t.text:GetStringWidth() or 40) + 10)
            t:ClearAllPoints()
            t:SetPoint("LEFT", panel.dock, "LEFT", tx, 0)
            tx = tx + t:GetWidth() + 2
            t:Show()
          else
            t:Hide()
          end
        end
        -- lines in the chat's own font, at its size (a little smaller to fit)
        local font, size = ChatFrame1:GetFont()
        size = tonumber(size) or 12
        local fs = math.max(7, size * .8)
        local flags = ""
        local y = -20
        for i, s in ipairs(list) do
          local l = Line(panel, i)
          local stamp, text = CH.Format(s)
          l.card = CARD[s[1]] or (s.url and "Links") or (s.link and "Links") or "Channel names"
          l.stamp.text:SetFont(font or pfUI.font_default, fs, flags)
          l.stamp.text:SetText(stamp)
          local sw = stamp ~= "" and ((l.stamp.text:GetStringWidth() or 0) + 3) or 0
          l.stamp:SetWidth(math.max(1, sw))
          l.stamp:SetHeight(fs + 2)
          l.stamp:ClearAllPoints()
          l.stamp:SetPoint("LEFT", l, "LEFT", 0, 0)
          if sw > 0 then l.stamp:Show() else l.stamp:Hide() end
          l.text:SetFont(font or pfUI.font_default, fs, flags)
          if TX().outline == "1" then l.text:SetShadowOffset(1, -1) l.text:SetShadowColor(0, 0, 0, 1)
          else l.text:SetShadowOffset(0, 0) end
          l.text:ClearAllPoints()
          l.text:SetPoint("LEFT", l, "LEFT", sw, 0)
          l.text:SetPoint("RIGHT", l, "RIGHT", 0, 0)
          l.text:SetText(text)
          l:ClearAllPoints()
          l:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, y)
          l:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, y)
          l:SetHeight(fs + 3)
          y = y - (fs + 3)
          if -y > h - 4 then l:Hide() else l:Show() end
        end
        for i = table.getn(list) + 1, table.getn(panel.lines) do panel.lines[i]:Hide() end
      end

      local function Layout()
        local spam = RT().enable == "1"
        local avail = box:GetWidth() or 640
        if avail <= 0 then avail = 640 end
        local lw, lh = tonumber(LF().width) or 380, tonumber(LF().height) or 180
        local rw, rh = tonumber(RT().width) or 380, tonumber(RT().height) or 180
        local total = lw + (spam and (rw + 20) or 0)
        local k = math.min(1, (avail - 24) / total, 190 / math.max(lh, spam and rh or 0))
        local tabs = { "General" }
        if Shown(2) then table.insert(tabs, "Combat Log") end
        local wf, _, wshown = WindowNamed(CH.WHISPERS)
        if wf and wshown then table.insert(tabs, CH.WHISPERS) end
        Fill(left, SAMPLES, tabs, lw * k, lh * k, true)
        Fill(right, SPAM, { "Loot & Spam" }, rw * k, rh * k, spam)
        edit:ClearAllPoints()
        edit:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -4)
        local iw = tonumber(TX().input_width) or 0
        edit:SetWidth(iw > 0 and iw * k or lw * k)
        edit.text:SetFont(pfUI.font_default, 10, "OUTLINE")
        for _, b in ipairs(tbtns) do W.Lit(b, b.t.on() and true or false) end
      end
      table.insert(CH.previews, { Layout = Layout, holder = holder })
      CH.Layout = function() for _, pv in ipairs(CH.previews) do if pv.holder:IsVisible() then pv.Layout() end end end
      holder:SetScript("OnShow", function() Layout() end)
      holder:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + 1
        Layout()
      end)
      Layout()

      local band = W.Row(pp, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local kc = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(kc .. "Click|r a line, tab, time or the typing box  its settings     " .. kc .. "Shift + wheel|r  chat text size     "
        .. kc .. "Move frames|r  move the panels")
      W.HowTo(pp, band, how:GetText(), nil, 0)
      W.Buttons(pp, {
        { "Show test lines in my chat", CH.TestLines, nil, "A line of every kind in your real chat, so you see the real thing. Only you see them.",
          on = function() return CH.testAt and GetTime() - CH.testAt < 2 end },
      })
    end)
  end

  -- ---------------------------------------------------------------- looks

  CH.LOOKS = {
    { "octo", "Octo", { time = "1", timeformat = "%H:%M", channelnumonly = "1", classcolor = "1", custombg = "1",
      background = ".06,.06,.06,.85", border = "0,0,0,1", tabdock = "1", frameshadow = "1" } },
    { "clean", "Clean", { time = "0", channelnumonly = "1", classcolor = "1", custombg = "1", background = "0,0,0,0.25",
      border = "0,0,0,0", tabdock = "0", frameshadow = "0" } },
    { "classic", "Classic", { time = "0", channelnumonly = "0", classcolor = "0", custombg = "0", tabdock = "0", frameshadow = "1" } },
    { "minimal", "Minimal", { time = "1", timeformat = "%H:%M", channelnumonly = "1", classcolor = "1", custombg = "1",
      background = "0,0,0,0", border = "0,0,0,0", tabdock = "0", frameshadow = "0" } },
  }
  local function Where(k)
    if k == "custombg" or k == "background" or k == "border" or k == "tabdock" or k == "frameshadow" then return GL() end
    return TX()
  end
  function CH.CurrentLook()
    for _, l in ipairs(CH.LOOKS) do
      local same = true
      for k, v in pairs(l[3]) do if Where(k)[k] ~= v then same = false end end
      if same then return l[1] end
    end
  end
  function CH.ApplyLook(key)
    for _, l in ipairs(CH.LOOKS) do
      if l[1] == key then for k, v in pairs(l[3]) do Where(k)[k] = v end end
    end
    -- (the dock background and shadow are made at login)
    Reload()
    CH.Apply()
  end
  local function Looks(p)
    local row = W.Row(p, 24, 0, 6)
    local btns = {}
    for i, l in ipairs(CH.LOOKS) do
      local b = W.Button(row, l[2], 150, 22)
      b:SetPoint("LEFT", row, "LEFT", (i - 1) * 156, 0)
      b.key = l[1]
      b:SetScript("OnClick", function() CH.ApplyLook(this.key) O:Refresh() end)
      W.Tip(b, l[2], "Timestamps, channel names, colours, background and dock in one click.")
      btns[i] = b
    end
    local function Paint()
      local cur = CH.CurrentLook()
      for _, b in ipairs(btns) do W.Pick(b, b.key == cur) end
    end
    row:SetScript("OnUpdate", function()
      if (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + .5
      Paint()
    end)
    Paint()
    table.insert(p.items, { Refresh = Paint })
  end

  -- ---------------------------------------------------------------- pages

  local TIMEFORMATS = { { key = "%H:%M", label = "13:45" }, { key = "%H:%M:%S", label = "13:45:12" },
    { key = "%I:%M %p", label = "01:45 PM" }, { key = "%I:%M:%S %p", label = "01:45:12 PM" }, { key = "%M:%S", label = "45:12" } }
  local BRACKETS = { { key = "[]", label = "[ ]" }, { key = "()", label = "( )" }, { key = "<>", label = "< >" },
    { key = "{}", label = "{ }" }, { key = "  ", label = "None" } }

  local function BuildWindows(p)
    W.Heading(p, "Chat", { on = O.ModuleSwitch("chat", "Chat"), about = "Your chat panels, their tabs and windows. The preview shows a line of every kind with "
      .. "your settings; the switches over it turn real windows on and off." })
    Preview(p)
    W.Card(p, "Looks", { tip = "Timestamps, channel names, colours, background and dock in one click. Some parts take a reload." })
    Looks(p)
    W.Card(p, "Left window", { tip = "The main chat panel. Move it with Move frames." })
    Sld(p, "Width", nil, 200, 900, 1, LF, "width", Px)
    Sld(p, "Height", nil, 80, 600, 1, LF, "height", Px)
    Chk(p, "My own colours", "Off: pfUI's panel colours.", GL, "custombg")
    Color(p, "Background", nil, GL, "background")
    Color(p, "Border", nil, GL, "border")
    Chk(p, "Shadow", "A soft shadow round the panels. Takes a reload.", GL, "frameshadow", Reload)
    W.Card(p, "Loot & Spam window", { tip = "A second panel on the right for loot, experience, reputation and skills." })
    W.Check(p, "Use it", nil, function() return RT().enable == "1" end, function(v)
      if pfUI.chat and pfUI.chat.SetupRightChat then pfUI.chat.SetupRightChat(v) else RT().enable = v and "1" or "0" end
      Up()
    end)
    Sld(p, "Width", nil, 200, 900, 1, RT, "width", Px)
    Sld(p, "Height", nil, 80, 600, 1, RT, "height", Px)
    W.Card(p, "Tabs and dock", { tip = "The tabs over each chat panel." })
    Chk(p, "Dock background", "A dark strip behind the tabs. Takes a reload.", GL, "tabdock", Reload)
    Chk(p, "Tabs on mouse-over only", "Takes a reload.", GL, "tabmouse", Reload)
    Chk(p, "Tabs flash on new messages", nil, GL, "chatflash")
    Chk(p, "Hide the combat log", "Closes any window that mostly shows combat.", GL, "combathide")
    W.Card(p, "Lines", { tip = "How many lines a window keeps, fading and scrolling." })
    Sld(p, "Lines kept", nil, 128, 1000, 1, GL, "maxlines")
    Chk(p, "Fade old lines", nil, GL, "fadeout")
    Sld(p, "Fade after", nil, 5, 600, 5, GL, "fadetime", function(v) return v .. " s" end)
    Sld(p, "Mouse wheel speed", "Lines a wheel step scrolls.", 1, 10, 1, GL, "scrollspeed")
    Chk(p, "Sticky channels", "Enter keeps the last channel you typed in (whisper, officer, raid warning, channels).", GL, "sticky", Reload)
    Chk(p, "Keep chat history", "Your chat comes back after a reload or relog.", TX, "history", Reload)
  end

  local function BuildMessages(p)
    W.Heading(p, "Messages", { about = "How every line reads: the time in front, channel tags, names, links and whispers." })
    Preview(p)
    O.CardTabs(p, {
      { "lines", "How lines read", "INV_Scroll_03", { "Timestamps", "Channel names", "Names", "Links", "Text" } },
      { "alerts", "Whispers and alerts", "INV_Misc_Bell_01", { "Whispers", "Highlights", "Sounds" } },
      { "filters", "Filters", "INV_Misc_Spyglass_02", { "Filters" } },
    })
    W.Card(p, "Timestamps")
    Chk(p, "Show the time", nil, TX, "time")
    Drop(p, "Format", nil, TIMEFORMATS, TX, "timeformat")
    Edit(p, "Own format", "Like %H:%M:%S (hours, minutes, seconds; %I = 12-hour, %p = AM / PM).", TX, "timeformat")
    Drop(p, "Brackets", "Takes a reload.", BRACKETS, TX, "timebracket", Reload)
    Color(p, "Colour", "Takes a reload.", TX, "timecolor", Reload)
    W.Card(p, "Channel names")
    Chk(p, "Channel numbers only", "[2] instead of [2. Trade].", TX, "channelnumonly")
    Drop(p, "Brackets", "Round the tags and names. Takes a reload.", BRACKETS, TX, "bracket", Reload)
    Edit(p, "Own tags", "Your own short tag per channel, like: Trade=T, LookingForGroup=LFG, World=W, LocalDefense=LD. "
      .. "A channel listed here shows its tag instead of its number.", PL, "tags")
    W.Card(p, "Names")
    Chk(p, "Class colours", nil, TX, "classcolor")
    Chk(p, "Level next to names", "From everyone the game has shown you (group, target, mouse-over, /who).", PL, "levels")
    Chk(p, "Colour unknown classes", nil, TX, "tintunknown")
    Color(p, "Unknown class colour", nil, TX, "unknowncolor")
    Chk(p, "Look up unknown classes", "Asks /who for names it has not seen. Experimental.", TX, "whosearchunknown")
    Chk(p, "Clickable names", "Names in system messages become links.", TX, "playerlinks", Reload)
    W.Card(p, "Links")
    Chk(p, "Web links", "Addresses become links you can copy.", TX, "detecturl")
    Chk(p, "Item tooltip on mouse-over", "Takes a reload.", TX, "mouseover", Reload)
    W.Card(p, "Whispers", { tip = "Incoming whispers stand out. Whisper windows of their own come in phase 3." })
    Chk(p, "Own whisper look", "[W] tags and their own colour. Takes a reload.", GL, "whispermod", Reload)
    Color(p, "Incoming whisper colour", "Takes a reload.", GL, "whisper", Reload)
    W.Card(p, "Text")
    Chk(p, "Text shadow", "Takes a reload.", TX, "outline", Reload)

    -- chat-plus.lua (Prat's ideas)
    local CT = pfUI.sctB and pfUI.sctB.SCT
    local sounds = { { key = "none", label = "No sound" } }
    for _, s in ipairs(CT and CT.SOUNDS or { { key = "TellMessage", label = "Whisper" }, { key = "RaidWarning", label = "Raid warning" } }) do
      if s.key and s.key ~= "none" then table.insert(sounds, { key = s.key, label = s.label }) end
    end
    local function Sound(p2, label, key)
      W.Dropdown(p2, label, "Picking one plays it.", sounds, function() return PL()[key] or "none" end, function(v)
        PL()[key] = v
        if pfUI.chatPlus then pfUI.chatPlus.Play(v) end
      end)
    end
    W.Card(p, "Highlights", { tip = "Your name and words you pick stand out in chat, with a sound and a popup if you like." })
    Chk(p, "My name", "Your name in other people's messages.", PL, "mention")
    Color(p, "Name colour", nil, PL, "mentioncolor")
    Edit(p, "Words", "Words to highlight, like: Onyxia, summon, guild bank (at least 3 letters each).", PL, "words")
    Color(p, "Word colour", nil, PL, "wordcolor")
    Sound(p, "Sound", "mentionsound")
    Chk(p, "Popup", "The line in big letters at the top of the screen for a few seconds.", PL, "mentionpopup")
    W.Buttons(p, { { "Try the popup", function()
      if pfUI.chatPlus then pfUI.chatPlus.Popup("Malfurion: Anyone seen " .. (UnitName("player") or "you") .. "?") pfUI.chatPlus.Play(PL().mentionsound) end
    end, 120, nil, on = function() return pfChatMention and pfChatMention:IsShown() end } })
    W.Card(p, "Sounds", { tip = "A sound when a message of that kind comes in (not your own)." })
    if pfUI.chatPlus then
      for _, k in ipairs(pfUI.chatPlus.KINDS) do Sound(p, k[2], "sound_" .. k[1]) end
    end
    W.Card(p, "Filters", { tip = "Less spam: lines from players that have a word you hide, or say the same thing again too soon." })
    Edit(p, "Hide lines with", "Words, like: gold, cheap, www (lines from players only).", PL, "hide")
    Sld(p, "Same line again within", "0 = off.", 0, 120, 5, PL, "throttle", function(v) return v == 0 and "off" or (v .. " s") end)
    O.TabFilter(p)
  end

  -- chat-whispers.lua: windows of their own
  local function WS() return C.chat.whisper end
  local function BuildWhispers(p)
    W.Heading(p, "Whispers", { on = O.ModuleSwitch("chat-whispers", "Whisper windows"), about = "Each person who whispers you gets a small window of their own - class, level, "
      .. "guild, the conversation and a box to answer in - or a tab in the left chat." })
    Preview(p)
    local WHm = pfUI.whispers
    W.Card(p, "Whisper windows", { tip = "How whispers show up." })
    Drop(p, "Whispers go", nil, { { key = "window", label = "In a window per person" }, { key = "tab", label = "In a Whispers tab" },
      { key = "off", label = "In the chat only" } }, WS, "mode", function()
      -- the tab follows the choice
      for _, t in ipairs(CH.TOGGLES) do
        if t.key == "whispers" then
          local want = WS().mode == "tab"
          if t.on() ~= want then pcall(t.set, want) end
        end
      end
      if WHm then WHm.ApplyChat() end
      if CH.Layout then CH.Layout() end
    end)
    W.Check(p, "Also in the chat", "Off: whispers show only in their windows.", function() return WS().alsochat == "1" end,
      function(v) WS().alsochat = v and "1" or "0" if WHm then WHm.ApplyChat() end end)
    Drop(p, "In combat", "What a new whisper does while you fight.", { { key = "pop", label = "Opens at once" },
      { key = "fold", label = "Opens folded" }, { key = "wait", label = "Waits until the fight ends" } }, WS, "combat", function() end)
    local CT = pfUI.sctB and pfUI.sctB.SCT
    local sounds = { { key = "none", label = "No sound" } }
    for _, s in ipairs(CT and CT.SOUNDS or { { key = "TellMessage", label = "Whisper" } }) do
      if s.key and s.key ~= "none" then table.insert(sounds, { key = s.key, label = s.label }) end
    end
    W.Dropdown(p, "Sound", "On a new whisper (the game plays its own too). Picking one plays it.", sounds,
      function() return WS().sound or "none" end, function(v)
        WS().sound = v
        if pfUI.chatPlus then pfUI.chatPlus.Play(v) end
      end)
    W.Buttons(p, {
      { "Open a test window", function() if WHm then WHm.Test() end end, 150,
        "A made-up conversation with Thrall: try the window, type in it - nothing is sent.",
        on = function() return WHm and WHm.windows[WHm.TEST] and WHm.windows[WHm.TEST]:IsShown() end },
      { "Close all", function() if WHm then WHm.CloseAll() end end, 100, "Every whisper window (conversations are kept)." },
    })
    W.Card(p, "Window look", { tip = "Drag a window's title to move it (new ones open from there), its corner to size it." })
    local function Re() if WHm then for _, f in pairs(WHm.windows) do WHm.Paint(f) end end end
    Sld(p, "Width", nil, 200, 700, 10, WS, "width", Px, Re)
    Sld(p, "Height", nil, 110, 600, 10, WS, "height", Px, Re)
    Sld(p, "Text size", nil, 8, 20, 1, WS, "fontsize", Px, Re)
    Sld(p, "Lines kept per person", "Shown again when their window opens.", 0, 200, 10, WS, "history")
    W.Live(p, function()
      return "|cffffd100/whispers|r reopens everyone you talked to   |cffffd100/whispers close|r closes them   "
        .. "|cffffd100/whispers test|r a test window"
    end)
  end

  -- (31 Oct 2026, user: menus "overwhelming": Tools had three small cards on a
  -- page of its own - they are under Typing now)
  local function ToolCards(p)
    W.Card(p, "Invites")
    Chk(p, "Alt-click a name to invite", nil, PL, "altinvite")
    Chk(p, "Invite on a whispered word", "Someone whispering just that word gets an invite (when you can invite).", PL, "autoinvite")
    Edit(p, "The word", nil, PL, "inviteword")
    W.Card(p, "Scrolling")
    Chk(p, "Shift / Ctrl + wheel jumps", "Shift + wheel: top or bottom. Ctrl + wheel: a page.", PL, "wheeljump")
    W.Card(p, "Search")
    Sld(p, "Lines kept for /find", nil, 50, 1000, 50, PL, "findlines")
    W.Live(p, function()
      return "|cffffd100/find word|r  the last lines with that word, from every window\n"
        .. "|cffffd100/tt message|r  whisper your target (no message: starts one)\n"
        .. "|cffffd100/clear|r  empties the window you are looking at (|cffffd100/clear all|r: every window)\n"
        .. "|cffffd100Copy|r  the small note button on the left chat's tabs copies the chat (pfUI's)"
    end, 4)
  end

  local function BuildInput(p)
    W.Heading(p, "Typing and tools", { about = "The box you type in, speech bubbles, invites, scrolling, searching and commands." })
    Preview(p)
    W.Card(p, "Typing box")
    Sld(p, "Width", "0 = as wide as the bar it sits on. Takes a reload.", 0, 1000, 1, TX, "input_width", Px, Reload)
    Sld(p, "Height", "0 = 22. Takes a reload.", 0, 40, 1, TX, "input_height", Px, Reload)
    W.Card(p, "Chat bubbles")
    W.Check(p, "Bubbles", "Speech bubbles over players who talk near you.",
      function() return GetCVar("chatBubbles") == "1" end, function(v) SetCVar("chatBubbles", v and "1" or "0") end)
    W.Check(p, "Party bubbles", nil,
      function() return GetCVar("chatBubblesParty") == "1" end, function(v) SetCVar("chatBubblesParty", v and "1" or "0") end)
    Chk(p, "Bubble borders", "Takes a reload.", BB, "borders", Reload)
    Sld(p, "Bubble opacity", "Takes a reload.", 0, 1, .05, BB, "alpha", function(v) return math.floor(v * 100 + .5) .. "%" end, Reload)
    ToolCards(p)
  end

  -- the arrow on the bottom-right bar (25 Oct 2026: off for the user, wanted
  -- by a friend for the Loot & Spam window): on / off and what it shows and
  -- hides. Move frames: right-click that bar opens this page.
  local function BuildArrow(p)
    W.Heading(p, "Panel arrow", {
      on = { function() return C.panel.arrow == "1" end, function(v)
        C.panel.arrow = v and "1" or "0"
        if pfUI.panel and pfUI.panel.ArrowApply then pfUI.panel.ArrowApply() end
      end, "The small arrow at the right end of the bottom-right bar." },
      about = "The small arrow at the right end of the bottom-right bar (time and fps), as pfUI always had it: a "
        .. "click opens or shuts the window above it. Loot & Spam: the window opens with Loot & Spam in it, and on "
        .. "shutting Loot & Spam goes back to a tab in the left chat. Meters: the window opens with your meter "
        .. "windows docked in it, side by side. In Move frames, right-click that bar to come here." })
    W.Card(p, "What the arrow opens", { tip = "One or the other." })
    W.Dropdown(p, "The window above the bar holds", nil,
      { { key = "chat", label = "Loot & Spam (as before)" }, { key = "meters", label = "Meter windows, docked" } },
      function() return C.panel.arrowmode or "chat" end,
      function(v) if pfUI.panel and pfUI.panel.ArrowMode then pfUI.panel.ArrowMode(v) else C.panel.arrowmode = v end end)
    -- (which meter windows dock: Meters > Windows, "Where your windows go")
    W.Buttons(p, { { "Open / shut it now", function() if pfUI.panel and pfUI.panel.ArrowToggle then pfUI.panel.ArrowToggle() end end,
      150, "What a click on the arrow does.", role = "go" },
      { "Which meter windows dock  >", function()
        if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("mtwindows", "Where your windows go") else O:Open("mtwindows") end
      end, 200, "Meters > Windows: tick the meter windows that sit in the panel's window.", role = "open" } })
  end

  -- (replaced first: AddPage rebuilds the topic list)
  O.replaced[T["Chat"]] = true
  O:AddPage("Chat", "chwindows", "Windows", BuildWindows)
  O:AddPage("Chat", "chmessages", "Messages", BuildMessages)
  O:AddPage("Chat", "chwhispers", "Whispers", BuildWhispers)
  O:AddPage("Chat", "chinput", "Typing and tools", BuildInput)
  O:AddPage("Chat", "chpanel", "Panel arrow", BuildArrow)
end)
