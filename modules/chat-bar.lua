pfUI:RegisterModule("chat-bar", "vanilla:tbc", function ()
  -- pfUI Octo :: NEW STYLE chat (23 Nov 2026; user: "combine the chats so you can quick toggle between this window and
  -- the original window ... with a new top bar on the chat", then "keep this optional in chat options make it clear at
  -- the top OLD CHAT OR NEW STYLE"). C.chat.style = "old" (pfUI's chat + the floating whisper window) | "new":
  --   a bar across the top of the left chat, in place of the tab strip that only showed on mouse-over:
  --     [General v]    your chat (the v menu picks General / Combat Log / any docked window). Click it while a
  --                    conversation shows = back to chat; click it on chat = back to the last conversation (quick toggle)
  --     [Whispers +3]  the whisper window INSIDE the chat (chat-whispers.lua WH.Embed): the oldest new one first
  --     G O P R B S    guild / officer / party / raid / battleground / say history (chat-history.lua), live, talk there
  --     + T ?          invite / target / who, while a whisper shows
  --     History v      old whispers
  --     <              folds the bar to one small arrow, > brings it back
  -- New whispers never cover your chat: the Whispers button counts and pulses green.
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

  -- ---------------------------------------------------------------- the bar

  local bar = CreateFrame("Frame", "pfChatTopBar", chat)
  CB.bar = bar
  local top = chat.panelTop
  if top then bar:SetAllPoints(top) else
    bar:SetPoint("TOPLEFT", chat, "TOPLEFT", 3, -3)
    bar:SetPoint("TOPRIGHT", chat, "TOPRIGHT", -3, -3)
    bar:SetHeight(18)
  end
  bar:SetFrameLevel(chat:GetFrameLevel() + 8)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bar.bg:SetVertexColor(.08, .08, .1, .9)
  bar.rule = bar:CreateTexture(nil, "BORDER")
  bar.rule:SetTexture("Interface\\Buttons\\WHITE8X8")
  bar.rule:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  bar.rule:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  bar.rule:SetHeight(1)
  bar:Hide()

  local btns = {}
  CB.btns = btns
  -- a word button: grey, white on hover, lit (accent underline) when it is what shows
  local function Button(key, label, tip, onClick, r, g, b)
    local x = CreateFrame("Button", nil, bar)
    x:SetHeight(bar:GetHeight() > 4 and bar:GetHeight() or 18)
    x:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    x.text = x:CreateFontString(nil, "OVERLAY")
    x.text:SetFont(pfUI.font_default, 11, "OUTLINE")
    x.text:SetPoint("CENTER", x, "CENTER", 0, 0)
    x.color = { r or .78, g or .78, b or .78 }
    x.line = x:CreateTexture(nil, "OVERLAY")
    x.line:SetTexture("Interface\\Buttons\\WHITE8X8")
    x.line:SetPoint("BOTTOMLEFT", x, "BOTTOMLEFT", 2, 0)
    x.line:SetPoint("BOTTOMRIGHT", x, "BOTTOMRIGHT", -2, 0)
    x.line:SetHeight(2)
    x.line:Hide()
    x.hl = x:CreateTexture(nil, "BACKGROUND")
    x.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    x.hl:SetAllPoints(x)
    x.hl:SetVertexColor(1, 1, 1, 0)
    x.key, x.tip = key, tip
    x:SetScript("OnClick", function() onClick(this, arg1) end)
    x:SetScript("OnEnter", function()
      this.hl:SetVertexColor(1, 1, 1, .06)
      if this.tip then
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(this.label or "", 1, 1, 1)
        GameTooltip:AddLine(type(this.tip) == "function" and this.tip() or this.tip, .75, .75, .75, 1)
        GameTooltip:Show()
      end
    end)
    x:SetScript("OnLeave", function() this.hl:SetVertexColor(1, 1, 1, 0) GameTooltip:Hide() end)
    function x:SetLabel(t)
      self.text:SetText(t)
      self:SetWidth(math.floor((self.text:GetStringWidth() or 20) + 12))
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
  end)

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
  end, .9, .55, 1)

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
    end, k.color[1], k.color[2], k.color[3])
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
  Button("history", "History v", "Everyone you whispered with in the kept days. Pick one for the whole conversation.",
    function(self) if WH() then WH().HistoryMenu(self) end CB.Paint() end)
  Button("who", "?", "/who - level, guild and zone", function() if Who() then SendWho("n-" .. Who()) end end)
  Button("target", "T", "Target them (when near)", function() if Who() then TargetByName(Who(), true) end end)
  Button("invite", "+", "Invite to your group", function() if Who() then InviteByName(Who()) end end)
  btns.chat.label = "Chat"
  btns.whispers.label = "Whispers"
  btns.history.label = "History"
  btns.fold.label = "Fold the bar"
  btns.who.label, btns.target.label, btns.invite.label = "Who", "Target", "Invite"

  -- buttons in their places; the ones that do not fit drop off the right
  function CB.Layout()
    if not CB.On() then bar:Hide() return end
    bar:Show()
    local folded = S().barfolded == "1"
    for _, b in pairs(btns) do b:ClearAllPoints() b:Hide() end
    if folded then
      btns.fold:SetLabel(">")
      btns.fold:SetPoint("LEFT", bar, "LEFT", 0, 0)
      btns.fold:Show()
      bar.bg:SetWidth(btns.fold:GetWidth())
      bar.bg:ClearAllPoints()
      bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
      bar.bg:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
      bar.rule:Hide()
      return
    end
    bar.bg:ClearAllPoints()
    bar.bg:SetAllPoints(bar)
    bar.rule:Show()
    btns.fold:SetLabel("<")
    local width = (bar:GetRight() or 0) - (bar:GetLeft() or 0)
    if width < 50 then width = bar:GetWidth() or 300 end
    -- right side first
    local right = { btns.fold, btns.history }
    if Who() then table.insert(right, btns.who) table.insert(right, btns.target) table.insert(right, btns.invite) end
    local x = 0
    for _, b in ipairs(right) do
      b:SetPoint("RIGHT", bar, "RIGHT", -x, 0)
      b:Show()
      x = x + b:GetWidth()
    end
    local room = width - x - 6
    local left = { btns.chat, btns.whispers }
    for _, b in ipairs(CB.chanBtns) do
      if CHH() and CHH().On(b.histKind.key) then table.insert(left, b) end
    end
    local lx = 0
    for i, b in ipairs(left) do
      if lx + b:GetWidth() <= room then
        b:SetPoint("LEFT", bar, "LEFT", lx, 0)
        b:Show()
        lx = lx + b:GetWidth() + (i == 2 and 6 or 0)
      end
    end
    CB.Paint()
  end

  -- what shows is lit; counts on Whispers and the channels
  function CB.Paint()
    if not bar:IsShown() then return end
    local w = WH()
    local showing = w and w.Showing()
    local ar, ag, ab = Accent()
    bar.rule:SetVertexColor(ar, ag, ab, .5)
    btns.chat:SetLabel(ChatName() .. " |cff888888v|r")
    local total = w and w.Unread and w.Unread() or 0
    btns.whispers:SetLabel("Whispers" .. (total > 0 and ("  |cff66ff66+" .. total .. "|r") or ""))
    for key, b in pairs(btns) do
      local lit = (key == "chat" and not showing)
        or (key == "whispers" and showing and w.windows[showing] and not w.windows[showing].chan)
        or (string.sub(key, 1, 1) == "#" and showing == key)
      if lit then
        b.line:SetVertexColor(ar, ag, ab, 1)
        b.line:Show()
        b.text:SetTextColor(1, 1, 1)
      else
        b.line:Hide()
        b.text:SetTextColor(b.color[1], b.color[2], b.color[3])
      end
      -- channels with new lines while you look elsewhere: brighter, with a count
      if b.histKind and w then
        local c = w.windows["#" .. b.histKind.key]
        local n = c and c.unread or 0
        b:SetLabel(b.histKind.short .. (n > 0 and ("|cff999999" .. (n > 99 and "+" or n) .. "|r") or ""))
      end
    end
    CB.pulse = total > 0
    bar:SetScript("OnUpdate", CB.pulse and CB.Pulse or nil)
    if not CB.pulse then btns.whispers.hl:SetVertexColor(1, 1, 1, 0) end
  end
  -- unread whispers: the Whispers button breathes green
  function CB.Pulse()
    if (this.t or 0) > GetTime() then return end
    this.t = GetTime() + .05
    local a = .08 + .14 * math.abs(math.sin(GetTime() * 3))
    btns.whispers.hl:SetVertexColor(.3, 1, .4, a)
  end

  -- ---------------------------------------------------------------- old / new

  -- the tab strip that only showed on mouse-over is kept away while the bar stands in its place
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
    if w and w.Embed then
      if on and not w.embedded then w.Embed(true) elseif not on and w.embedded then w.Embed(false) end
    end
    if on then
      if w then w.onChange = CB.Paint end
      CB.Layout()
    else
      bar:Hide()
    end
  end
  -- (bar and window placed again when the chat changes size)
  chat:SetScript("OnSizeChanged", function() if bar:IsShown() then CB.Layout() end end)

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
