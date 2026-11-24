pfUI:RegisterModule("chat-bar", "vanilla:tbc", function ()
  -- pfUI Octo :: NEW STYLE chat (23 Nov 2026; user: "combine the chats so you can quick toggle between this window and
  -- the original window ... with a new top bar on the chat", then "keep this optional in chat options make it clear at
  -- the top OLD CHAT OR NEW STYLE"). C.chat.style = "old" (pfUI's chat + the floating whisper window) | "new":
  --   a bar across the top of the left chat, in place of the tab strip that only showed on mouse-over:
  --     [General v]    your chat (right-click: pick a docked window). Click it while a conversation shows = back to
  --                    chat; click it on chat = back to the last conversation (quick toggle)
  --     [Whispers +3]  the whisper window over the chat (chat-whispers.lua WH.Embed): the oldest new one first
  --     G O P R B S    guild / officer / party / raid / battleground / say history (chat-history.lua), live, talk there
  --     + T ?          invite / target / who, while a whisper shows
  --     History v      old whispers
  --     <              folds the bar to one small arrow, > brings it back
  -- (24 Nov 2026, user: "make this bar look ALOT better the text is overlapping it looks cheap ... when the bar first
  -- loads up you have to minimize it and bring it back out to show the channels") Buttons are chained one after the
  -- other, so a longer label ("Loot & Spam") pushes the rest along instead of running into them; the room is measured
  -- from the chat panel's own width (at login the bar had no size yet and hid every channel), and the bar lays itself
  -- out again when it shows and a moment after login. Look: a dark gradient with a light top edge, small icons on
  -- Chat / Whispers / History, a coloured orb badge on each channel, thin dividers between the groups, and an accent
  -- underline with a soft glow under what shows.
  local CB = {}
  pfUI.chatBar = CB
  local function S() return C.chat end
  local chat = pfUI.chat and pfUI.chat.left
  if not chat then return end

  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function WH() return pfUI.whispers end
  local function CHH() return pfUI.chatHistory end
  function CB.On()
    if pfUI.blizz and pfUI.blizz.IsBlizz and pfUI.blizz.IsBlizz("chat") then return false end
    return S().style == "new" and WH() and WH().Embed and true or false
  end
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local FONT = pfUI.font_default

  -- ---------------------------------------------------------------- the bar

  local bar = CreateFrame("Frame", "pfChatTopBar", chat)
  CB.bar = bar
  -- (its own height: the room above the chat's first line - pfUI keeps font size x 1.5 + borders there)
  CB.H = math.max(18, math.floor((tonumber(C.global.font_size) or 12) * 1.5 + 2))
  bar:SetPoint("TOPLEFT", chat, "TOPLEFT", 2, -2)
  bar:SetPoint("TOPRIGHT", chat, "TOPRIGHT", -2, -2)
  bar:SetHeight(CB.H)
  bar:SetFrameLevel(chat:GetFrameLevel() + 8)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  bar.bg:SetTexture(WHITE)
  bar.bg:SetGradientAlpha("VERTICAL", .03, .03, .04, .96, .11, .11, .14, .96)
  bar.shine = bar:CreateTexture(nil, "BORDER")
  bar.shine:SetTexture(WHITE)
  bar.shine:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  bar.shine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
  bar.shine:SetHeight(1)
  bar.shine:SetVertexColor(1, 1, 1, .07)
  bar.rule = bar:CreateTexture(nil, "BORDER")
  bar.rule:SetTexture(WHITE)
  bar.rule:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  bar.rule:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  bar.rule:SetHeight(1)
  -- thin dividers between the groups (chat and whispers | channels | right side)
  bar.divs = {}
  for i = 1, 3 do
    local d = bar:CreateTexture(nil, "ARTWORK")
    d:SetTexture(WHITE)
    d:SetWidth(1)
    d:SetHeight(CB.H - 8)
    d:SetVertexColor(1, 1, 1, .12)
    d:Hide()
    bar.divs[i] = d
  end
  bar:Hide()

  local btns = {}
  CB.btns = btns
  local PAD = 7
  -- a button: [icon or badge] text, grey; white on hover; lit (accent underline + glow) when it is what shows
  local function Button(key, label, tip, onClick, r, g, b, icon, badge)
    local x = CreateFrame("Button", nil, bar)
    x:SetHeight(CB.H)
    x:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    x.hl = x:CreateTexture(nil, "BACKGROUND")
    x.hl:SetTexture(WHITE)
    x.hl:SetPoint("TOPLEFT", x, "TOPLEFT", 1, -2)
    x.hl:SetPoint("BOTTOMRIGHT", x, "BOTTOMRIGHT", -1, 2)
    x.hl:SetVertexColor(1, 1, 1, 0)
    x.glow = x:CreateTexture(nil, "BORDER")
    x.glow:SetTexture(pfUI.media["img:honor\\spark"])
    x.glow:SetBlendMode("ADD")
    x.glow:SetPoint("BOTTOM", x, "BOTTOM", 0, -4)
    x.glow:SetHeight(14)
    x.glow:Hide()
    x.line = x:CreateTexture(nil, "OVERLAY")
    x.line:SetTexture(WHITE)
    x.line:SetPoint("BOTTOMLEFT", x, "BOTTOMLEFT", 3, 0)
    x.line:SetPoint("BOTTOMRIGHT", x, "BOTTOMRIGHT", -3, 0)
    x.line:SetHeight(2)
    x.line:Hide()
    local lead = PAD
    if icon then
      x.icon = x:CreateTexture(nil, "ARTWORK")
      x.icon:SetTexture(icon)
      x.icon:SetTexCoord(.08, .92, .08, .92)
      x.icon:SetWidth(CB.H - 6)
      x.icon:SetHeight(CB.H - 6)
      x.icon:SetPoint("LEFT", x, "LEFT", PAD - 1, 0)
      lead = PAD - 1 + (CB.H - 6) + 4
    elseif badge then
      -- a little orb in the channel's colour
      x.badge = x:CreateTexture(nil, "ARTWORK")
      x.badge:SetTexture(pfUI.media["img:plates\\cp-orb"])
      x.badge:SetWidth(9)
      x.badge:SetHeight(9)
      x.badge:SetPoint("LEFT", x, "LEFT", 5, 0)
      x.badge:SetVertexColor(r or 1, g or 1, b or 1, 1)
      lead = 5 + 9 + 3
    end
    x.lead = lead
    x.text = x:CreateFontString(nil, "OVERLAY")
    x.text:SetFont(FONT, 11, "OUTLINE")
    x.text:SetPoint("LEFT", x, "LEFT", lead, 0)
    x.text:SetJustifyH("LEFT")
    x.color = { r or .78, g or .78, b or .78 }
    x.key, x.tip = key, tip
    x:SetScript("OnClick", function() onClick(this, arg1) end)
    x:SetScript("OnEnter", function()
      this.hl:SetVertexColor(1, 1, 1, .07)
      if this.tip then
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(this.label or "", 1, 1, 1)
        GameTooltip:AddLine(type(this.tip) == "function" and this.tip() or this.tip, .75, .75, .75, 1)
        GameTooltip:Show()
      end
    end)
    x:SetScript("OnLeave", function() this.hl:SetVertexColor(1, 1, 1, 0) GameTooltip:Hide() end)
    -- its width follows its text (a chained neighbour moves along)
    function x:SetLabel(t)
      if self.shown == t then return end
      self.shown = t
      self.text:SetText(t)
      local tw = self.text:GetStringWidth() or 0
      if tw < 1 then tw = string.len(t or "") * 6 end
      self:SetWidth(math.floor(self.lead + tw + PAD))
      self.glow:SetWidth(math.max(20, tw + 16))
    end
    x.label = label
    x:SetLabel(label)
    btns[key] = x
    return x
  end

  -- the docked chat windows (General, Combat Log, ...): the name of the shown one, and a menu
  function CB.Docked()
    local out = {}
    for i = 1, (_G.NUM_CHAT_WINDOWS or 7) do
      local f = _G["ChatFrame" .. i]
      local name = GetChatWindowInfo and GetChatWindowInfo(i)
      if f and name and name ~= "" and (i == 1 or f.isDocked) then table.insert(out, { key = i, label = name, frame = f }) end
    end
    return out
  end
  function CB.ShowChat(i)
    local w = WH()
    if w and w.HideView then w.HideView() end
    local f = i and _G["ChatFrame" .. i]
    if f then
      _G.SELECTED_CHAT_FRAME = f
      if FCF_SelectDockFrame then FCF_SelectDockFrame(f) end
    end
    CB.Paint()
  end
  local function ChatName()
    local f = _G.SELECTED_CHAT_FRAME or _G.ChatFrame1
    local name = f and f.GetID and GetChatWindowInfo and GetChatWindowInfo(f:GetID())
    return (name and name ~= "") and name or "Chat"
  end

  Button("chat", "Chat", function()
    return "Left-click: your chat - or, when it already shows, back to the last conversation (quick toggle).\n"
      .. "Right-click: pick a chat window (General, Combat Log ...)."
  end, function(self, button)
    local w = WH()
    if button == "RightButton" then
      local W = pfUI.octoui and pfUI.octoui.W
      local list = CB.Docked()
      if W and W.Menu and table.getn(list) > 0 then
        if CB.menu then CB.menu:Hide() end
        CB.menu = W.Menu(self, list, 140, function(k) CB.ShowChat(k) end)
        if CB.menu then CB.menu:Show() end
      end
      return
    end
    if w and w.Showing() then
      CB.ShowChat()
    elseif w and w.lastView and w.windows[w.lastView] and w.windows[w.lastView].open then
      if w.windows[w.lastView].chan then w.OpenChannel(w.windows[w.lastView].chan.key) else w.Open(w.lastView, true) end
    end
    CB.Paint()
  end, .85, .85, .88, "Interface\\Icons\\INV_Misc_Note_01")

  Button("whispers", "Whispers", function()
    local w = WH()
    local total, people = 0, 0
    if w and w.Unread then total, people = w.Unread() end
    if total > 0 then return total .. " new from " .. people .. (people == 1 and " person" or " people") .. ". Click: the oldest first." end
    return "Your conversations, here in the chat. Click again: back to chat."
  end, function()
    local w = WH()
    if not w then return end
    local showing = w.Showing()
    if showing and not w.windows[showing].chan and (w.Unread() == 0) then CB.ShowChat() return end
    if not w.ShowWhispers() then w.HistoryMenu(btns.history) end
    CB.Paint()
  end, .92, .6, 1, "Interface\\Icons\\INV_Letter_15")

  CB.chanBtns = {}
  local CH0 = CHH()
  for _, k in ipairs(CH0 and CH0.KINDS or {}) do
    local kind = k
    local b = Button("#" .. k.key, k.short, function()
      local n = CHH() and table.getn(CHH().Lines(kind.key)) or 0
      return kind.name .. " history (" .. n .. " lines). Read it here and talk there from the box. Click again: back to chat."
    end, function()
      local w = WH()
      if not w then return end
      if w.Showing() == "#" .. kind.key then CB.ShowChat() else w.OpenChannel(kind.key) end
      CB.Paint()
    end, k.color[1], k.color[2], k.color[3], nil, true)
    b.label = k.name
    b.histKind = k
    table.insert(CB.chanBtns, b)
  end

  -- on the right: the person buttons (while a whisper shows), History, the fold arrow
  local function Who() local w = WH() local s = w and w.Showing() return s and not w.windows[s].chan and s or nil end
  Button("fold", "<", "Fold the bar to a small arrow (your chat stays as it is).", function()
    S().barfolded = S().barfolded == "1" and "0" or "1"
    CB.Layout()
  end)
  Button("history", "History", "Everyone you whispered with in the kept days. Pick one for the whole conversation.",
    function(self) if WH() then WH().HistoryMenu(self) end CB.Paint() end, .85, .85, .88, "Interface\\Icons\\INV_Misc_Book_09")
  Button("who", "?", "/who - level, guild and zone", function() if Who() then SendWho("n-" .. Who()) end end)
  Button("target", "T", "Target them (when near)", function() if Who() then TargetByName(Who(), true) end end)
  Button("invite", "+", "Invite to your group", function() if Who() then InviteByName(Who()) end end)
  btns.chat.label = "Chat"
  btns.whispers.label = "Whispers"
  btns.history.label = "History"
  btns.fold.label = "Fold the bar"
  btns.who.label, btns.target.label, btns.invite.label = "Who", "Target", "Invite"

  -- the bar's width: its own edges once laid out, else the chat panel's set width (at login nothing is laid out yet)
  function CB.Width()
    local l, r = bar:GetLeft(), bar:GetRight()
    if l and r and r - l > 50 then return r - l end
    local cl, cr = chat:GetLeft(), chat:GetRight()
    if cl and cr and cr - cl > 50 then return cr - cl - 4 end
    return (tonumber(C.chat.left.width) or 380) - 4
  end

  -- the labels as they are now (counts, the chat window's name)
  local function Labels()
    local w = WH()
    btns.chat:SetLabel(ChatName() .. "  |cff777777v|r")
    local total = w and w.Unread and w.Unread() or 0
    btns.whispers:SetLabel("Whispers" .. (total > 0 and ("  |cff66ff66" .. total .. "|r") or ""))
    btns.history:SetLabel("History  |cff777777v|r")
    btns.fold:SetLabel(S().barfolded == "1" and ">" or "<")
    for _, b in ipairs(CB.chanBtns) do
      local c = w and w.windows["#" .. b.histKind.key]
      local n = c and c.unread or 0
      b:SetLabel(b.histKind.short .. (n > 0 and ("|cff8a8a8a" .. (n > 99 and "+" or n) .. "|r") or ""))
    end
    return total
  end

  -- the buttons chained one after the other; channels that do not fit drop off the end
  function CB.Place()
    for _, b in pairs(btns) do b:ClearAllPoints() b:Hide() end
    for _, d in ipairs(bar.divs) do d:Hide() end
    if S().barfolded == "1" then
      btns.fold:SetPoint("LEFT", bar, "LEFT", 0, 0)
      btns.fold:Show()
      bar.bg:ClearAllPoints()
      bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
      bar.bg:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
      bar.bg:SetWidth(btns.fold:GetWidth())
      bar.rule:Hide()
      bar.shine:Hide()
      return
    end
    bar.bg:ClearAllPoints()
    bar.bg:SetAllPoints(bar)
    bar.rule:Show()
    bar.shine:Show()
    local width = CB.Width()
    -- right: fold arrow, History, then the person buttons, right to left
    -- (24 Nov 2026, user: opening Whispers "bumps off the R and B" - invite / target / who now sit in the conversation
    -- itself, chat-whispers.lua, so the bar never changes)
    local right = { btns.fold, btns.history }
    local rw, prev = 0, nil
    for _, b in ipairs(right) do
      if prev then b:SetPoint("RIGHT", prev, "LEFT", 0, 0) else b:SetPoint("RIGHT", bar, "RIGHT", 0, 0) end
      b:Show()
      rw = rw + b:GetWidth()
      prev = b
    end
    local rightEdge = prev
    -- left: your chat and Whispers, a divider, the channels
    btns.chat:SetPoint("LEFT", bar, "LEFT", 0, 0)
    btns.chat:Show()
    btns.whispers:SetPoint("LEFT", btns.chat, "RIGHT", 0, 0)
    btns.whispers:Show()
    local used = btns.chat:GetWidth() + btns.whispers:GetWidth()
    local room = width - rw - 10
    local d1 = bar.divs[1]
    d1:ClearAllPoints()
    d1:SetPoint("LEFT", btns.whispers, "RIGHT", 3, 0)
    d1:Show()
    used = used + 7
    local last, lastX = btns.whispers, 7
    for _, b in ipairs(CB.chanBtns) do
      if CHH() and CHH().On(b.histKind.key) and used + b:GetWidth() <= room then
        b:SetPoint("LEFT", last, "RIGHT", lastX, 0)
        b:Show()
        used = used + b:GetWidth() + (lastX > 0 and lastX or 0)
        last, lastX = b, 0
      end
    end
    -- a divider before the right side
    local d2 = bar.divs[2]
    d2:ClearAllPoints()
    d2:SetPoint("RIGHT", rightEdge, "LEFT", -3, 0)
    d2:Show()
  end

  -- what shows is lit; counts on Whispers and the channels
  local function Lit()
    local w = WH()
    local showing = w and w.Showing()
    local ar, ag, ab = Accent()
    bar.rule:SetVertexColor(ar, ag, ab, .45)
    for key, b in pairs(btns) do
      local lit = (key == "chat" and not showing)
        or (key == "whispers" and showing and w.windows[showing] and not w.windows[showing].chan)
        or (string.sub(key, 1, 1) == "#" and showing == key)
      if lit then
        b.line:SetVertexColor(ar, ag, ab, 1)
        b.line:Show()
        b.glow:SetVertexColor(ar, ag, ab, .55)
        b.glow:Show()
        b.text:SetTextColor(1, 1, 1)
        if b.icon then b.icon:SetVertexColor(1, 1, 1) end
      else
        b.line:Hide()
        b.glow:Hide()
        b.text:SetTextColor(b.color[1], b.color[2], b.color[3])
        if b.icon then b.icon:SetVertexColor(.75, .75, .75) end
      end
    end
  end

  -- everything: the labels, the places, what is lit
  function CB.Layout()
    if not CB.On() then bar:Hide() return end
    bar:Show()
    CB.Paint()
  end
  function CB.Paint()
    if not bar:IsShown() then return end
    local total = Labels()
    CB.Place()
    Lit()
    CB.pulse = total > 0
    bar:SetScript("OnUpdate", CB.Tick)
    if not CB.pulse then btns.whispers.hl:SetVertexColor(1, 1, 1, 0) end
  end
  -- unread whispers: the Whispers button breathes green; the first second after it shows, the bar lays itself
  -- out again once the game has given it its size
  function CB.Tick()
    local now = GetTime()
    if CB.relayAt and now >= CB.relayAt then
      CB.relayAt = nil
      CB.Paint()
      return
    end
    if not CB.pulse then
      if not CB.relayAt then this:SetScript("OnUpdate", nil) end
      return
    end
    if (this.t or 0) > now then return end
    this.t = now + .05
    local a = .07 + .13 * math.abs(math.sin(now * 3))
    btns.whispers.hl:SetVertexColor(.3, 1, .4, a)
  end
  bar:SetScript("OnShow", function()
    CB.relayAt = GetTime() + .3
    this:SetScript("OnUpdate", CB.Tick)
  end)

  -- ---------------------------------------------------------------- old / new

  -- the tab strip that only showed on mouse-over is kept away while the bar stands in its place
  local top = chat.panelTop
  local function HoldTabs(hold)
    if not top then return end
    if hold then
      if not top.pfShow then top.pfShow = top.Show end
      top.Show = function() end
      top:Hide()
    elseif top.pfShow then
      top.Show = top.pfShow
      top.pfShow = nil
    end
  end
  function CB.Apply()
    local on = CB.On()
    local w = WH()
    HoldTabs(on)
    -- (the conversation view hangs under the bar)
    if w then w.embedTop = on and bar or nil end
    if w and w.Embed then
      if on and not w.embedded then w.Embed(true) elseif not on and w.embedded then w.Embed(false) end
    end
    if on then
      if w then w.onChange = CB.Paint end
      CB.Layout()
      CB.relayAt = GetTime() + 1
      bar:SetScript("OnUpdate", CB.Tick)
    else
      bar:Hide()
    end
  end
  -- (bar and view placed again when the chat changes size; a hook, so the chat's own script stays)
  if HookScript then HookScript(chat, "OnSizeChanged", function() if bar:IsShown() then CB.Paint() end end) end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("UPDATE_CHAT_WINDOWS")
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then CB.Apply() elseif bar:IsShown() then CB.Paint() end
  end)
  -- (a picked chat window changes the Chat button's name)
  if _G.FCF_SelectDockFrame and hooksecurefunc then hooksecurefunc("FCF_SelectDockFrame", function() if bar:IsShown() then CB.Paint() end end) end

  -- switch from the options: "old" | "new", at once
  function CB.SetStyle(style)
    S().style = style
    CB.Apply()
  end
end)
