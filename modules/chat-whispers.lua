pfUI:RegisterModule("chat-whispers", "vanilla:tbc", function ()
  -- pfUI Octo :: whisper windows (chat phase 3, docs\chat-spec.md, 23 Oct
  -- 2026; the user asked for "automatic whisper window options" from Prat -
  -- Prat hands this to WIM; both are other people's code, nothing copied).
  -- Each person who whispers you (or you whisper) gets a small window of their
  -- own: their class icon, name in class colour, level and guild (pfUI's
  -- unit scan), the conversation with times, a box to answer in, buttons to
  -- invite / target / who / minimise / close. New messages light the edge and
  -- count while you are not looking; windows cascade from where you drag the
  -- first one. In combat they can wait until it ends, or open folded.
  -- The last lines per person are kept (pfUI_cache.whispers) for next time.
  -- Settings C.chat.whisper; options: Chat > Whispers.
  local WH = { windows = {}, order = {}, queue = {} }
  pfUI.whispers = WH
  local function S() return C.chat.whisper end
  local ME = UnitName("player")

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

  -- ---------------------------------------------------------------- a window

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

  local count = 0
  local function Make(name)
    count = count + 1
    local f = CreateFrame("Frame", "pfWhisperWindow" .. count, UIParent)
    f.who = name
    f:SetFrameStrata("MEDIUM")
    f:SetWidth(tonumber(S().width) or 320)
    f:SetHeight(tonumber(S().height) or 200)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetMovable(true)
    f:SetResizable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    if f.SetMinResize then f:SetMinResize(200, 110) end
    f:SetScript("OnMouseDown", function() WH.Seen(this) end)

    -- the header: drag to move (the first window's place is remembered)
    local head = CreateFrame("Button", nil, f)
    head:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    head:SetHeight(22)
    head.bg = head:CreateTexture(nil, "BACKGROUND")
    head.bg:SetAllPoints(head)
    head.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() local w = this:GetParent() w:SetMovable(true) w:StartMoving() end)
    head:SetScript("OnDragStop", function()
      local w = this:GetParent()
      w:StopMovingOrSizing()
      if w == WH.windows[WH.order[1]] then
        S().x, S().y = tostring(math.floor(w:GetLeft() + .5)), tostring(math.floor(w:GetTop() + .5))
      end
    end)
    head:SetScript("OnClick", function() WH.Fold(this:GetParent()) end)
    f.head = head
    f.icon = head:CreateTexture(nil, "ARTWORK")
    f.icon:SetWidth(16)
    f.icon:SetHeight(16)
    f.icon:SetPoint("LEFT", head, "LEFT", 4, 0)
    f.title = head:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(pfUI.font_default, 12, "OUTLINE")
    f.title:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
    f.title:SetJustifyH("LEFT")

    f.close = Btn(head, "x", "Close (the conversation is kept)", function() WH.Close(this:GetParent():GetParent().who) end)
    f.close:SetPoint("RIGHT", head, "RIGHT", -2, 0)
    f.fold = Btn(head, "_", "Fold / unfold", function() WH.Fold(this:GetParent():GetParent()) end)
    f.fold:SetPoint("RIGHT", f.close, "LEFT", -2, 0)
    f.whob = Btn(head, "?", "/who - level, guild and zone", function() SendWho("n-" .. this:GetParent():GetParent().who) end)
    f.whob:SetPoint("RIGHT", f.fold, "LEFT", -2, 0)
    f.target = Btn(head, "T", "Target them (when near)", function() TargetByName(this:GetParent():GetParent().who, true) end)
    f.target:SetPoint("RIGHT", f.whob, "LEFT", -2, 0)
    f.invite = Btn(head, "+", "Invite to your group", function() InviteByName(this:GetParent():GetParent().who) end)
    f.invite:SetPoint("RIGHT", f.target, "LEFT", -2, 0)

    -- the conversation
    local msg = CreateFrame("ScrollingMessageFrame", nil, f)
    -- (19 Nov 2026, mechanism: "new whisper window per person seems to not be working") a font straight away: the 1.12
    -- client refuses AddMessage on a message frame with none, and the kept conversation went in before WH.Paint set it
    if msg.SetFontObject and ChatFontNormal then msg:SetFontObject(ChatFontNormal) end
    if msg.SetFont then msg:SetFont(Font()) end
    msg:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 5, -3)
    msg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 26)
    if msg.SetFading then msg:SetFading(false) end
    if msg.SetMaxLines then msg:SetMaxLines(200) end
    if msg.SetJustifyH then msg:SetJustifyH("LEFT") end
    msg:EnableMouseWheel(true)
    msg:SetScript("OnMouseWheel", function()
      if arg1 > 0 then if this.ScrollUp then this:ScrollUp() end elseif this.ScrollDown then this:ScrollDown() end
    end)
    msg:SetScript("OnMouseDown", function() WH.Seen(this:GetParent()) end)
    f.msg = msg

    -- the box to answer in
    local eb = CreateFrame("EditBox", nil, f)
    -- (an edit box with no font shows no text and errors on typing in 1.12)
    if eb.SetFontObject and ChatFontNormal then eb:SetFontObject(ChatFontNormal) end
    if eb.SetFont then eb:SetFont(Font()) end
    eb:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
    eb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 4)
    eb:SetHeight(18)
    eb:SetAutoFocus(false)
    if eb.SetTextInsets then eb:SetTextInsets(4, 4, 0, 0) end
    eb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    eb:SetBackdropColor(0, 0, 0, .6)
    eb:SetBackdropBorderColor(.25, .25, .28, 1)
    eb:SetScript("OnEnterPressed", function()
      local text = this:GetText()
      local w = this:GetParent()
      if text and text ~= "" then WH.Send(w.who, text) end
      this:SetText("")
    end)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function() this.focused = true WH.Seen(this:GetParent()) end)
    -- (1.12 edit boxes have no HasFocus: the focus is noted here)
    eb:SetScript("OnEditFocusLost", function() this.focused = nil end)
    f.edit = eb

    -- the corner grip: drag to size
    local grip = CreateFrame("Button", nil, f)
    grip:SetWidth(12)
    grip:SetHeight(12)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetAllPoints(grip)
    grip.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    grip.tex:SetVertexColor(.4, .4, .45, .6)
    grip:SetScript("OnMouseDown", function() local w = this:GetParent() w:SetResizable(true) w:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
      local w = this:GetParent()
      w:StopMovingOrSizing()
      S().width, S().height = tostring(math.floor(w:GetWidth() + .5)), tostring(math.floor(w:GetHeight() + .5))
    end)
    f.grip = grip

    -- the edge flashes while there is something unread
    f:SetScript("OnUpdate", function()
      if not this.unread or this.unread == 0 then return end
      local r, g, b = Accent()
      local a = .55 + .45 * math.abs(math.sin(GetTime() * 3))
      this:SetBackdropBorderColor(r, g, b, a)
    end)
    return f
  end

  -- a window's look and title from who they are
  function WH.Paint(f)
    local class, level, guild = Who(f.who)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
      f.icon:SetTexture(pfUI.media["img:classicons"])
      f.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      f.icon:Show()
    else
      f.icon:Hide()
    end
    local name = c and string.format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), f.who) or f.who
    local extra = ""
    if level and level ~= 0 then extra = " |cff999999" .. level .. "|r" end
    if guild and guild ~= "" then extra = extra .. " |cff66cc66<" .. guild .. ">|r" end
    if f.unread and f.unread > 0 then extra = extra .. "  |cffffd100(" .. f.unread .. " new)|r" end
    f.title:SetText(name .. extra)
    local bg = f.test and .1 or .06
    f:SetBackdropColor(bg, bg, .08, .94)
    f.head.bg:SetVertexColor(.12, .12, .15, 1)
    if not f.unread or f.unread == 0 then f:SetBackdropBorderColor(.2, .2, .24, 1) end
    local font, size = Font()
    if f.msg.SetFont then f.msg:SetFont(font, size, "") end
    if f.edit.SetFont then f.edit:SetFont(font, size, "") end
  end

  -- where the next window opens: under the last one, cascading
  local function Place(f)
    local n = 0
    for _, other in pairs(WH.windows) do if other ~= f and other:IsShown() then n = n + 1 end end
    local x, y = tonumber(S().x), tonumber(S().y)
    f:ClearAllPoints()
    if x and y then
      f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + n * 24, y - n * 24)
    else
      f:SetPoint("CENTER", UIParent, "CENTER", 200 + n * 24, 80 - n * 24)
    end
  end

  -- ---------------------------------------------------------------- messages

  local function Stamp(t) return "|cff888888" .. date("%H:%M", t) .. "|r " end
  -- one line in someone's window (dir: "in", "out", "sys")
  local function Line(f, dir, text, t)
    local r, g, b = 1, .5, 1
    local who
    if dir == "out" then
      r, g, b = .75, .55, .9
      who = "|cff999999" .. (ME or "Me") .. ":|r "
    elseif dir == "sys" then
      r, g, b = .7, .7, .7
      who = ""
    else
      local class = Who(f.who)
      local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
      who = (c and string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) or "|cffffffff")
        .. f.who .. ":|r "
    end
    f.msg:AddMessage(Stamp(t) .. who .. text, r, g, b)
  end

  -- keep the conversation (the last lines per person)
  local function Keep(name, dir, text, t)
    local s = Store()
    s[name] = s[name] or {}
    table.insert(s[name], { t = t, dir = dir, msg = text })
    local keep = tonumber(S().history) or 50
    while table.getn(s[name]) > keep do table.remove(s[name], 1) end
  end

  -- someone's window: made (with the kept lines) and shown
  function WH.Open(name, quiet)
    if not name then return end
    local f = WH.windows[name]
    if not f then
      f = Make(name)
      WH.windows[name] = f
      table.insert(WH.order, name)
      WH.Paint(f)
      for _, e in ipairs(Store()[name] or {}) do Line(f, e.dir, e.msg, e.t) end
      if table.getn(Store()[name] or {}) > 0 then f.msg:AddMessage("|cff666666- earlier -|r") end
    end
    if not f:IsShown() then
      f:SetWidth(tonumber(S().width) or 320)
      f:SetHeight(tonumber(S().height) or 200)
      Place(f)
      f:Show()
    end
    WH.Paint(f)
    if not quiet then f.edit:SetFocus() end
    return f
  end

  function WH.Add(name, dir, text, t)
    t = t or time()
    if not (name and text) then return end
    local f = WH.windows[name]
    if not f or not f:IsShown() then
      local waiting = UnitAffectingCombat("player") and S().combat == "wait"
      if waiting then
        Keep(name, dir, text, t)
        -- (a window made earlier keeps its lines: this one goes in it too)
        if f then Line(f, dir, text, t) f.unread = (f.unread or 0) + (dir == "in" and 1 or 0) end
        WH.queue[name] = true
        return
      end
      f = WH.Open(name, true)
      if UnitAffectingCombat("player") and S().combat == "fold" then WH.Fold(f, true) end
    else
      Keep(name, dir, text, t)
      Line(f, dir, text, t)
      t = nil
    end
    if t then
      -- (a new window shows the kept lines; this one was not kept yet)
      Keep(name, dir, text, t)
      Line(f, dir, text, t)
    end
    if dir == "in" and not f.edit.focused then
      f.unread = (f.unread or 0) + 1
    end
    WH.Paint(f)
    return f
  end

  function WH.Seen(f)
    if not f then return end
    f.unread = 0
    WH.Paint(f)
  end

  function WH.Fold(f, fold)
    if not f then return end
    if fold == nil then fold = not f.folded end
    f.folded = fold
    if fold then
      f.fullHeight = f:GetHeight()
      f:SetHeight(24)
      f.msg:Hide() f.edit:Hide() f.grip:Hide()
    else
      f:SetHeight(f.fullHeight or tonumber(S().height) or 200)
      f.msg:Show() f.edit:Show() f.grip:Show()
    end
  end

  function WH.Close(name)
    local f = WH.windows[name]
    if f then f:Hide() f.unread = 0 end
  end
  function WH.CloseAll()
    for name in pairs(WH.windows) do WH.Close(name) end
  end

  -- send from a window (the test window only talks to itself)
  function WH.Send(name, text)
    local f = WH.windows[name]
    if f and f.test then
      WH.Add(name, "out", text)
      WH.Add(name, "in", "(test) You said: " .. text)
      return
    end
    SendChatMessage(text, "WHISPER", nil, name)
  end

  -- a made-up conversation to try the window (nothing is sent)
  WH.TEST = "Thrall"
  function WH.Test()
    local f = WH.Open(WH.TEST, true)
    f.test = true
    WH.Add(WH.TEST, "in", "Hey, are you coming to Onyxia tonight?")
    WH.Add(WH.TEST, "out", "Yes, after dinner")
    WH.Add(WH.TEST, "in", "Great - bring fire resistance gear (this is a test window: type here, nothing is sent)")
    WH.Paint(f)
    return f
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
      for name in pairs(WH.queue) do WH.Open(name, true) WH.Paint(WH.windows[name]) end
      WH.queue = {}
      for _, f in pairs(WH.windows) do if f.folded and f:IsShown() then WH.Fold(f, false) end end
      return
    end
    if evt == "WHO_LIST_UPDATE" then
      for _, f in pairs(WH.windows) do WH.Paint(f) end
      return
    end
    if S().mode ~= "window" then return end
    if evt == "CHAT_MSG_WHISPER" then
      local f = WH.Add(a2, "in", a1)
      if f and S().sound and S().sound ~= "none" then
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
    local n = 0
    for name in pairs(Store()) do WH.Open(name, true) n = n + 1 end
    if n == 0 then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: no whispers yet (/whispers test shows a test window).") end
  end
end)
