pfUI:RegisterModule("mail-window", "vanilla", function ()
  -- pfUI Octo :: the mailbox window (16 Nov 2026, modules/mail.lua is the engine). Inbox: every mail in
  -- one list (wheel to scroll), Collect all with a choice of what, a letter pane with Take / Reply /
  -- Return / Delete. Send: To with names suggested, many items at once (right-click them in your bags),
  -- money or cash on delivery. "Game window" in the title bar swaps to the game's own.
  local M = pfUI.mail
  if not M then return end
  local UI = { tab = "inbox", top = 0, rows = {}, slots = {} }
  M.ui = UI
  local function S() return C.mail end
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local ROWS, ROWH = 10, 40
  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function Flat(f, a, edge)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(.06, .06, .08, a or .96)
    f:SetBackdropBorderColor(edge or .22, edge or .22, (edge or .22) + .04, 1)
  end
  local function Text(f, size, justify)
    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(pfUI.font_default, size or 12, "")
    t:SetJustifyH(justify or "LEFT")
    return t
  end
  local function Btn(parent, label, w, fn, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w or 90)
    b:SetHeight(22)
    Flat(b, 1, .3)
    b:SetBackdropColor(.12, .12, .15, 1)
    b.text = Text(b, 12, "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b.fn = fn
    b:SetScript("OnClick", function() if this.fn and not this.off then this.fn(this) end end)
    b:SetScript("OnEnter", function()
      if not this.off then this:SetBackdropBorderColor(Accent()) end
      if this.tip then
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(this.tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function()
      if not this.lit then this:SetBackdropBorderColor(.3, .3, .34, 1) end
      GameTooltip:Hide()
    end)
    b.tip = tip
    function b.Off(state)
      b.off = state
      b.text:SetTextColor(state and .45 or 1, state and .45 or 1, state and .45 or 1)
    end
    function b.Lit(state)
      b.lit = state
      if state then b:SetBackdropBorderColor(Accent()) else b:SetBackdropBorderColor(.3, .3, .34, 1) end
    end
    return b
  end
  local function Box(parent, w, h, multi)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetWidth(w)
    e:SetHeight(h or 22)
    e:SetAutoFocus(false)
    e:SetFont(pfUI.font_default, 12, "")
    e:SetTextInsets(6, 6, multi and 4 or 0, multi and 4 or 0)
    Flat(e, 1, .3)
    e:SetBackdropColor(.03, .03, .04, 1)
    if multi then e:SetMultiLine(true) e:SetMaxLetters(500) end
    e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    return e
  end

  -- ---------------------------------------------------------------- the window

  local f = CreateFrame("Frame", "pfMail", UIParent)
  UI.frame = f
  f:SetWidth(760)
  f:SetHeight(540)
  f:SetPoint("LEFT", UIParent, "LEFT", 40, 40)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  Flat(f, .97)
  f:Hide()
  table.insert(UISpecialFrames, "pfMail")
  f.bar = CreateFrame("Frame", nil, f)
  f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  f.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  f.bar:SetHeight(30)
  f.bar:EnableMouse(true)
  f.bar:RegisterForDrag("LeftButton")
  f.bar:SetScript("OnDragStart", function() f:StartMoving() end)
  f.bar:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local x, y = f:GetLeft(), f:GetTop()
    if x and y then S().x, S().y = tostring(math.floor(x + .5)), tostring(math.floor(y + .5)) end
  end)
  f.wash = f.bar:CreateTexture(nil, "BACKGROUND")
  f.wash:SetAllPoints(f.bar)
  f.wash:SetTexture(WHITE)
  f.title = Text(f.bar, 15)
  f.title:SetPoint("LEFT", f.bar, "LEFT", 12, 0)
  f.title:SetText("Mail")
  f.money = Text(f.bar, 12, "RIGHT")
  f.close = Btn(f.bar, "X", 24, function() f:Hide() end, "Close the mailbox (Esc).")
  f.close:SetPoint("RIGHT", f.bar, "RIGHT", -4, 0)
  f.game = Btn(f.bar, "Game window", 100, function()
    local g = rawget(_G, "MailFrame")
    if not g then return end
    UI.handoff = true
    f:Hide()
    UI.handoff = nil
    ShowUIPanel(g)
    if not g:IsShown() then g:Show() end
  end, "Swap to the game's own mail window. The next visit opens this one again.")
  f.game:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.opts = Btn(f.bar, "Options", 70, function()
    if pfUI.gui and pfUI.octoui and pfUI.octoui.Options then
      if not pfUI.gui:IsShown() then pfUI.gui:Show() end
      pfUI.octoui.Options:Open("mail")
    end
  end)
  f.opts:SetPoint("RIGHT", f.game, "LEFT", -6, 0)
  f.money:SetPoint("RIGHT", f.opts, "LEFT", -14, 0)
  f.note = Text(f, 12)
  f.note:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
  f.note:SetWidth(560)
  f.note:SetTextColor(1, .82, .3)
  function UI.Note(text)
    f.note:SetText(text or "")
    UI.noteAt = GetTime() + 8
  end
  M.onNote = UI.Note

  UI.pages, UI.tabBtn = {}, {}
  local tx = 64
  for _, t in ipairs({ { "inbox", "Inbox" }, { "send", "Send" } }) do
    local key = t[1]
    local b = Btn(f.bar, t[2], 70, function() UI.Open(key) end)
    b:SetPoint("LEFT", f.bar, "LEFT", tx, 0)
    tx = tx + 73
    UI.tabBtn[key] = b
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 30)
    p:Hide()
    UI.pages[key] = p
  end
  function UI.Open(key)
    UI.tab = key
    for k, p in pairs(UI.pages) do
      if k == key then p:Show() else p:Hide() end
      UI.tabBtn[k].Lit(k == key)
    end
    UI.Refresh()
  end

  -- ---------------------------------------------------------------- inbox

  local IN = UI.pages.inbox
  IN.list = CreateFrame("Frame", nil, IN)
  IN.list:SetPoint("TOPLEFT", IN, "TOPLEFT", 0, -30)
  IN.list:SetWidth(430)
  IN.list:SetHeight(ROWS * ROWH + 4)
  Flat(IN.list, 1, .18)
  IN.list:SetBackdropColor(.03, .03, .04, 1)
  IN.list:EnableMouseWheel(true)
  IN.list:SetScript("OnMouseWheel", function()
    UI.top = math.max(0, math.min(UI.top - arg1 * 3, math.max(0, table.getn(UI.mails or {}) - ROWS)))
    UI.Refresh()
  end)
  IN.count = Text(IN, 12)
  IN.count:SetPoint("TOPLEFT", IN, "TOPLEFT", 2, -6)
  IN.collect = Btn(IN, "Collect all", 100, function()
    if M.job then M.Stop("stopped.") else M.Collect(UI.kind or "all") end
  end, "Takes the gold and items out of every mail, top of the list down, and throws away the emptied letters. "
    .. "A mail that cannot be taken (marks you hold the most of, full bags, cash on delivery) is left and the rest still come.")
  IN.collect:SetPoint("TOPRIGHT", IN, "TOPRIGHT", 0, -2)
  UI.KINDS = { { "all", "Everything" }, { "gold", "Gold only" }, { "ah", "Auction house" }, { "system", "Not from players" } }
  UI.kindBtn = {}
  for k = table.getn(UI.KINDS), 1, -1 do
    local kind = UI.KINDS[k]
    local b = Btn(IN, kind[2], kind[1] == "system" and 110 or (kind[1] == "ah" and 92 or 74), function()
      UI.kind = kind[1]
      S().kind = kind[1]
      UI.Refresh()
    end, "What Collect all takes.")
    b:SetHeight(18)
    b.text:SetFont(pfUI.font_default, 11, "")
    UI.kindBtn[kind[1]] = b
  end
  -- the choice of what, left of Collect all
  local prev = IN.collect
  for k = table.getn(UI.KINDS), 1, -1 do
    local b = UI.kindBtn[UI.KINDS[k][1]]
    b:SetPoint("RIGHT", prev, "LEFT", -4, 0)
    prev = b
  end

  local function DaysText(d)
    if d < 1 then return "|cffff4040" .. math.max(1, math.floor(d * 24)) .. " h|r" end
    local n = math.floor(d)
    return (n < 3 and "|cffffa040" or "|cff40ff40") .. n .. (n == 1 and " day" or " days") .. "|r"
  end
  for r = 1, ROWS do
    local row = CreateFrame("Button", nil, IN.list)
    row:SetHeight(ROWH - 2)
    row:SetPoint("TOPLEFT", IN.list, "TOPLEFT", 2, -2 - (r - 1) * ROWH)
    row:SetPoint("TOPRIGHT", IN.list, "TOPRIGHT", -2, -2 - (r - 1) * ROWH)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture(WHITE)
    row.bg:SetVertexColor(1, 1, 1, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(32)
    row.icon:SetHeight(32)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetTexCoord(.08, .92, .08, .92)
    row.count = Text(row, 11, "RIGHT")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 0, 1)
    row.count:SetFont(pfUI.font_default, 11, "OUTLINE")
    row.who = Text(row, 13)
    row.who:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
    row.who:SetWidth(230)
    row.what = Text(row, 12)
    row.what:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 2)
    row.what:SetWidth(250)
    row.what:SetTextColor(.85, .85, .85)
    row.days = Text(row, 12, "RIGHT")
    row.days:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
    row.cash = Text(row, 12, "RIGHT")
    row.cash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 4)
    row:SetScript("OnEnter", function()
      local m = this.mail
      if not m then return end
      this.bg:SetVertexColor(1, 1, 1, .06)
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      if m.item and GameTooltip.SetInboxItem then GameTooltip:SetInboxItem(m.i)
      else GameTooltip:SetText(m.subject, 1, 1, 1) end
      GameTooltip:AddLine("Click: open the letter.  Right-click: take everything out of it.", .6, .6, .6, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
      GameTooltip:Hide()
      UI.Refresh()
    end)
    row:SetScript("OnClick", function()
      local m = this.mail
      if not m then return end
      if arg1 == "RightButton" then
        if M.job then return end
        M.TakeOne(m.i)
      elseif IsShiftKeyDown() and m.item and ChatFrameEditBox and ChatFrameEditBox:IsVisible() and m.itemName then
        ChatFrameEditBox:Insert(m.itemName)
      else
        UI.sel = m.sig
        GetInboxText(m.i)
      end
      UI.Refresh()
    end)
    UI.rows[r] = row
  end

  -- the letter
  local L = CreateFrame("Frame", nil, IN)
  IN.letter = L
  L:SetPoint("TOPLEFT", IN.list, "TOPRIGHT", 10, 0)
  L:SetPoint("BOTTOMRIGHT", IN, "BOTTOMRIGHT", 0, 0)
  Flat(L, 1, .18)
  L:SetBackdropColor(.03, .03, .04, 1)
  L.from = Text(L, 14)
  L.from:SetPoint("TOPLEFT", L, "TOPLEFT", 10, -10)
  L.from:SetWidth(270)
  L.subject = Text(L, 12)
  L.subject:SetPoint("TOPLEFT", L.from, "BOTTOMLEFT", 0, -4)
  L.subject:SetWidth(270)
  L.subject:SetTextColor(1, .82, 0)
  L.body = Text(L, 12)
  L.body:SetPoint("TOPLEFT", L.subject, "BOTTOMLEFT", 0, -10)
  L.body:SetWidth(270)
  L.body:SetHeight(180)
  L.body:SetJustifyV("TOP")
  L.body:SetTextColor(.9, .9, .9)
  L.item = CreateFrame("Button", nil, L)
  L.item:SetWidth(36)
  L.item:SetHeight(36)
  L.item:SetPoint("BOTTOMLEFT", L, "BOTTOMLEFT", 10, 40)
  Flat(L.item, 1, .3)
  L.item.icon = L.item:CreateTexture(nil, "ARTWORK")
  L.item.icon:SetPoint("TOPLEFT", L.item, "TOPLEFT", 1, -1)
  L.item.icon:SetPoint("BOTTOMRIGHT", L.item, "BOTTOMRIGHT", -1, 1)
  L.item.icon:SetTexCoord(.08, .92, .08, .92)
  L.item.count = Text(L.item, 11, "RIGHT")
  L.item.count:SetFont(pfUI.font_default, 11, "OUTLINE")
  L.item.count:SetPoint("BOTTOMRIGHT", L.item, "BOTTOMRIGHT", -2, 2)
  L.item:SetScript("OnEnter", function()
    if UI.cur and UI.cur.item then
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetInboxItem(UI.cur.i)
      GameTooltip:Show()
    end
  end)
  L.item:SetScript("OnLeave", function() GameTooltip:Hide() end)
  L.item:SetScript("OnClick", function()
    if not (UI.cur and UI.cur.item) or M.job then return end
    if UI.cur.cod > 0 then M.PayCOD(UI.cur.i) else TakeInboxItem(UI.cur.i) end
  end)
  L.cash = Text(L, 13)
  L.cash:SetPoint("LEFT", L.item, "RIGHT", 10, 0)
  L.take = Btn(L, "Take", 64, function()
    local m = UI.cur
    if not m or M.job then return end
    if m.cod > 0 then M.PayCOD(m.i) return end
    M.TakeOne(m.i)
  end, "Takes the gold and the item, then throws the letter away if it is empty. Cash on delivery: pays it and takes the item.")
  L.take:SetPoint("BOTTOMLEFT", L, "BOTTOMLEFT", 10, 10)
  L.reply = Btn(L, "Reply", 64, function()
    local m = UI.cur
    if not m or not m.reply then return end
    UI.Open("send")
    UI.to:SetText(m.sender)
    local s = m.subject
    if not string.find(s, "^Re: ") then s = "Re: " .. s end
    UI.subj:SetText(s)
    UI.body:SetFocus()
  end)
  L.reply:SetPoint("LEFT", L.take, "RIGHT", 6, 0)
  L.ret = Btn(L, "Return", 64, function()
    local m = UI.cur
    if not m or not m.reply or m.returned then return end
    ReturnInboxItem(m.i)
    UI.sel = nil
  end, "Sends it back to who sent it.")
  L.ret:SetPoint("LEFT", L.reply, "RIGHT", 6, 0)
  L.del = Btn(L, "Delete", 64, function()
    local m = UI.cur
    if not m then return end
    if m.item or m.money > 0 then
      if UI.delAt and GetTime() < UI.delAt then UI.delAt = nil
      else
        UI.delAt = GetTime() + 3
        UI.Note("It still holds something: click Delete again within 3 s to throw it all away.")
        return
      end
    end
    DeleteInboxItem(m.i)
    UI.sel = nil
  end, "Throws the letter away.")
  L.del:SetPoint("LEFT", L.ret, "RIGHT", 6, 0)

  local function Paint(m)
    local L_ = IN.letter
    UI.cur = m
    if not m then
      L_.from:SetText("|cff808080Pick a mail on the left.|r")
      L_.subject:SetText("")
      L_.body:SetText("Right-click a mail to take everything out of it at once.")
      L_.item:Hide()
      L_.cash:SetText("")
      for _, b in ipairs({ L_.take, L_.reply, L_.ret, L_.del }) do b.Off(true) end
      return
    end
    L_.from:SetText((m.kind == "ah" and "|cffffd24d" or (m.kind == "player" and "|cffffffff" or "|cff9fd5ff")) .. m.sender .. "|r"
      .. (m.returned and "  |cffff8080(sent back)|r" or ""))
    L_.subject:SetText(m.subject)
    local body = GetInboxText(m.i) or ""
    L_.body:SetText(body ~= "" and body or "|cff808080(no text)|r")
    if m.item then
      L_.item.icon:SetTexture(m.itemTex)
      L_.item.count:SetText((m.count or 1) > 1 and m.count or "")
      L_.item:Show()
    else L_.item:Hide() end
    local cash = ""
    if m.money > 0 then cash = M.Money(m.money) end
    if m.cod > 0 then cash = "|cffff6060Pay|r " .. M.Money(m.cod) end
    L_.cash:SetText(cash)
    -- a COD letter's button says what it does
    L_.take.text:SetText(m.cod > 0 and "|cffff8060Pay|r" or "Take")
    L_.take.Off(not (m.item or m.money > 0) or M.job and true)
    L_.reply.Off(not m.reply)
    L_.ret.Off(not m.reply or m.returned)
    L_.del.Off(false)
  end

  -- ---------------------------------------------------------------- send

  local SE = UI.pages.send
  local function Label(parent, text, x, y)
    local t = Text(parent, 12)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    t:SetText(text)
    t:SetTextColor(.75, .75, .8)
    return t
  end
  -- (16 Nov 2026, user: "make our send mail look more like this [the game's Send Mail] but with our style") laid
  -- out like the game's: To and Postage on top, Subject across, a big letter, the items under it, Amount to send
  -- in gold / silver / copper with Send money or C.O.D., your money, Send.
  local GOLD = { .98, .82, .3 }
  local function Gold(t) t:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) return t end
  Gold(Label(SE, "To:", 0, -8))
  UI.to = Box(SE, 230)
  UI.to:SetPoint("TOPLEFT", SE, "TOPLEFT", 64, -4)
  UI.price = Text(SE, 13, "RIGHT")
  UI.price:SetPoint("TOPRIGHT", SE, "TOPRIGHT", 0, -8)
  Gold(Label(SE, "Subject:", 0, -38))
  UI.subj = Box(SE, 300)
  UI.subj:SetPoint("TOPLEFT", SE, "TOPLEFT", 64, -34)
  UI.subj:SetPoint("TOPRIGHT", SE, "TOPRIGHT", 0, -34)
  -- the letter: the game's own parchment (Interface\Stationery\StationeryTest1/2, as its Send Mail) in a thin
  -- gold edge, dark ink. (16 Nov 2026, user screenshot: a multi-line edit box in 1.12 is only as tall as its
  -- text, so the letter was one line: the paper is a frame of its own now and the box writes on it.)
  local paper = CreateFrame("Button", nil, SE)
  UI.paper = paper
  paper:SetPoint("TOPLEFT", SE, "TOPLEFT", 0, -64)
  paper:SetPoint("TOPRIGHT", SE, "TOPRIGHT", 0, -64)
  paper:SetHeight(246)
  paper:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  paper:SetBackdropColor(.16, .12, .07, 1)
  paper:SetBackdropBorderColor(.55, .44, .24, 1)
  local pl = paper:CreateTexture(nil, "BORDER")
  pl:SetTexture("Interface\\Stationery\\StationeryTest1")
  pl:SetPoint("TOPLEFT", paper, "TOPLEFT", 1, -1)
  pl:SetPoint("BOTTOMRIGHT", paper, "BOTTOMRIGHT", -61, 1)
  local pr = paper:CreateTexture(nil, "BORDER")
  pr:SetTexture("Interface\\Stationery\\StationeryTest2")
  pr:SetPoint("TOPLEFT", pl, "TOPRIGHT", 0, 0)
  pr:SetPoint("BOTTOMRIGHT", paper, "BOTTOMRIGHT", -1, 1)
  UI.body = CreateFrame("EditBox", nil, paper)
  UI.body:SetPoint("TOPLEFT", paper, "TOPLEFT", 14, -12)
  UI.body:SetPoint("TOPRIGHT", paper, "TOPRIGHT", -14, -12)
  UI.body:SetHeight(220)
  UI.body:SetMultiLine(true)
  UI.body:SetAutoFocus(false)
  UI.body:SetFont(pfUI.font_default, 14, "")
  UI.body:SetTextColor(.2, .13, .05)
  UI.body:SetMaxLetters(500)
  UI.body:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  paper:SetScript("OnClick", function() UI.body:SetFocus() end)
  UI.bodyHint = Text(paper, 14)
  UI.bodyHint:SetPoint("TOPLEFT", paper, "TOPLEFT", 14, -12)
  UI.bodyHint:SetTextColor(.42, .32, .18)
  UI.bodyHint:SetText("Write your letter here...")
  UI.body:SetScript("OnTextChanged", function()
    if this:GetText() == "" then UI.bodyHint:Show() else UI.bodyHint:Hide() end
  end)
  UI.body:SetScript("OnEditFocusGained", function() UI.bodyHint:Hide() end)
  UI.body:SetScript("OnEditFocusLost", function() if this:GetText() == "" then UI.bodyHint:Show() end end)

  -- Amount to send: gold, silver, copper, each with its coin
  local MB = CreateFrame("Frame", nil, SE)
  MB:SetPoint("BOTTOMLEFT", SE, "BOTTOMLEFT", 0, 34)
  MB:SetWidth(330)
  MB:SetHeight(22)
  UI.moneyBox = MB
  local amt = Gold(Text(MB, 12))
  amt:SetPoint("LEFT", MB, "LEFT", 0, 0)
  amt:SetText("Amount to send:")
  UI.coins = {}
  local cx = 104
  -- (the coins are one sheet in 1.12, Interface\MoneyFrame\UI-MoneyIcons: gold, silver, copper a quarter each)
  for _, c in ipairs({ { "g", 54, 0 }, { "s", 34, .25 }, { "c", 34, .5 } }) do
    local e = Box(MB, c[2])
    e:SetPoint("LEFT", MB, "LEFT", cx, 0)
    e:SetNumeric(true)
    e:SetMaxLetters(c[1] == "g" and 6 or 2)
    e:SetJustifyH("RIGHT")
    local icon = MB:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\MoneyFrame\\UI-MoneyIcons")
    icon:SetTexCoord(c[3], c[3] + .25, 0, 1)
    icon:SetWidth(14)
    icon:SetHeight(14)
    icon:SetPoint("LEFT", e, "RIGHT", 3, 0)
    UI.coins[c[1]] = e
    cx = cx + c[2] + 22
  end
  -- Tab walks gold -> silver -> copper
  UI.coins.g:SetScript("OnTabPressed", function() UI.coins.s:SetFocus() end)
  UI.coins.s:SetScript("OnTabPressed", function() UI.coins.c:SetFocus() end)
  UI.coins.c:SetScript("OnTabPressed", function() UI.to:SetFocus() end)
  function UI.Cash()
    local function N(e) return tonumber(e:GetText() or "") or 0 end
    return N(UI.coins.g) * 10000 + N(UI.coins.s) * 100 + N(UI.coins.c)
  end
  function UI.ClearCash() for _, e in pairs(UI.coins) do e:SetText("") end end
  -- Send money / C.O.D., the lit one in use (the game's two round buttons)
  UI.sendMoney = Btn(SE, "Send money", 104, function() UI.mode = "send" UI.Refresh() end,
    "The money goes with the mail.")
  UI.sendMoney:SetPoint("LEFT", MB, "RIGHT", 6, 0)
  UI.cod = Btn(SE, "C.O.D.", 70, function() UI.mode = "cod" UI.Refresh() end,
    "Cash on delivery: they pay this much to take the items.")
  UI.cod:SetPoint("LEFT", UI.sendMoney, "RIGHT", 4, 0)
  UI.each = Btn(SE, "On the first mail", 130, function()
    S().codeach = S().codeach == "1" and "0" or "1"
    UI.Refresh()
  end, "With many items: cash on delivery on the first mail only, or on each one.")
  UI.each:SetPoint("LEFT", UI.cod, "RIGHT", 4, 0)

  -- the suggestions under To
  UI.sugg = CreateFrame("Frame", nil, SE)
  UI.sugg:SetPoint("TOPLEFT", UI.to, "BOTTOMLEFT", 0, -2)
  -- (16 Nov 2026) a dropdown of everyone you might mail (M.Names: mailed, group, friends, guild, alts, seen):
  -- class colour, a green dot when online, where they come from; Up / Down picks, Tab or Enter takes it
  UI.sugg:SetWidth(260)
  UI.sugg:SetFrameStrata("FULLSCREEN_DIALOG")
  Flat(UI.sugg, 1, .3)
  UI.sugg:Hide()
  UI.sugg.rows = {}
  UI.suggPick = 1
  local function PaintPick()
    for k, b in ipairs(UI.sugg.rows) do
      if k == UI.suggPick then b.bg:SetVertexColor(Accent()) b.bg:SetAlpha(.28) else b.bg:SetAlpha(0) end
    end
  end
  for k = 1, 10 do
    local b = CreateFrame("Button", nil, UI.sugg)
    b:SetHeight(20)
    b:SetPoint("TOPLEFT", UI.sugg, "TOPLEFT", 2, -2 - (k - 1) * 20)
    b:SetPoint("TOPRIGHT", UI.sugg, "TOPRIGHT", -2, -2 - (k - 1) * 20)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetTexture(WHITE)
    b.bg:SetAlpha(0)
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetTexture(WHITE)
    b.dot:SetWidth(6)
    b.dot:SetHeight(6)
    b.dot:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.text = Text(b, 12)
    b.text:SetPoint("LEFT", b, "LEFT", 18, 0)
    b.tag = Text(b, 11, "RIGHT")
    b.tag:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b.tag:SetTextColor(.55, .58, .62)
    b.k = k
    b:SetScript("OnEnter", function() UI.suggPick = this.k PaintPick() end)
    b:SetScript("OnClick", function()
      UI.to:SetText(this.name)
      UI.sugg:Hide()
      UI.subj:SetFocus()
    end)
    UI.sugg.rows[k] = b
  end
  function UI.ShowNames(typed)
    local list = M.Names(typed, 10)
    UI.suggList = list
    if table.getn(list) == 0 or (table.getn(list) == 1 and list[1].name == typed) then UI.sugg:Hide() return end
    for k, b in ipairs(UI.sugg.rows) do
      local e = list[k]
      if e then
        b.name = e.name
        local c = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
        b.text:SetText(e.name)
        if c then b.text:SetTextColor(c.r, c.g, c.b) else b.text:SetTextColor(1, 1, 1) end
        b.tag:SetText(M.TAGLABEL[e.tag] or "")
        if e.online then b.dot:SetVertexColor(.25, .9, .4, 1) else b.dot:SetVertexColor(.35, .35, .38, 1) end
        b:Show()
      else
        b:Hide()
      end
    end
    UI.suggPick = 1
    PaintPick()
    UI.sugg:SetHeight(4 + table.getn(list) * 20)
    UI.sugg:Show()
  end
  local function Take()
    local e = UI.sugg:IsShown() and UI.suggList and UI.suggList[UI.suggPick]
    if e then UI.to:SetText(e.name) end
    UI.sugg:Hide()
    UI.subj:SetFocus()
  end
  UI.to:SetScript("OnTextChanged", function() UI.ShowNames(this:GetText()) end)
  UI.to:SetScript("OnTabPressed", Take)
  UI.to:SetScript("OnEnterPressed", Take)
  UI.to:SetScript("OnEditFocusLost", function() UI.suggHideAt = GetTime() + .3 end)
  -- clicked into an empty To box: your alts and the people you mail, straight away
  UI.to:SetScript("OnEditFocusGained", function()
    UI.suggHideAt = nil
    UI.ShowNames(this:GetText())
  end)
  -- Up / Down move the pick. (16 Nov 2026, user: "when i right click the mailbox it does nothing": the 1.12 client
  -- has no OnArrowPressed script - not in WoW.exe - and setting it errored, so the window was never finished and
  -- the game's own mail window stays hidden. 1.12 has OnKeyDown; set in a pcall so a missing script can never
  -- stop the window again.)
  pcall(UI.to.SetScript, UI.to, "OnKeyDown", function()
    if not UI.sugg:IsShown() or not UI.suggList then return end
    local n = table.getn(UI.suggList)
    if arg1 == "UP" then UI.suggPick = UI.suggPick > 1 and UI.suggPick - 1 or n
    elseif arg1 == "DOWN" then UI.suggPick = UI.suggPick < n and UI.suggPick + 1 or 1
    else return end
    PaintPick()
  end)
  UI.subj:SetScript("OnTabPressed", function() UI.body:SetFocus() end)
  UI.subj:SetScript("OnEnterPressed", function() UI.body:SetFocus() end)

  -- attachments
  UI.SLOTS = 16
  local A = CreateFrame("Frame", nil, SE)
  SE.items = A
  -- under the letter, one strip of 16 slots across
  A:SetPoint("TOPLEFT", SE, "TOPLEFT", 0, -318)
  A:SetPoint("TOPRIGHT", SE, "TOPRIGHT", 0, -318)
  A:SetHeight(76)
  Flat(A, 1, .18)
  A:SetBackdropColor(.03, .03, .04, 1)
  A.head = Gold(Text(A, 12))
  A.head:SetPoint("TOPLEFT", A, "TOPLEFT", 10, -7)
  A.head:SetWidth(160)
  A.hint = Text(A, 11)
  A.hint:SetPoint("TOPRIGHT", A, "TOPRIGHT", -10, -7)
  A.hint:SetJustifyH("RIGHT")
  A.hint:SetTextColor(.6, .6, .6)
  A.hint:SetText("Right-click items in your bags or drop them here - one mail each. Click one to take it off.")
  for k = 1, UI.SLOTS do
    local b = CreateFrame("Button", nil, A)
    b:SetWidth(40)
    b:SetHeight(40)
    b:SetPoint("TOPLEFT", A, "TOPLEFT", 8 + (k - 1) * 45, -26)
    Flat(b, 1, .25)
    b:SetBackdropColor(.08, .08, .1, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b.count = Text(b, 11, "RIGHT")
    b.count:SetFont(pfUI.font_default, 11, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.k = k
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      if CursorHasItem() then UI.Drop() return end
      if M.items[this.k] and not M.sending then table.remove(M.items, this.k) UI.Refresh() end
    end)
    b:SetScript("OnReceiveDrag", function() UI.Drop() end)
    b:SetScript("OnEnter", function()
      local it = M.items[this.k]
      if it then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(it.bag, it.slot)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI.slots[k] = b
  end
  A:EnableMouse(true)
  A:SetScript("OnReceiveDrag", function() UI.Drop() end)
  A:SetScript("OnMouseUp", function() if CursorHasItem() then UI.Drop() end end)

  function UI.Add(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return false end
    for _, it in ipairs(M.items) do
      if it.bag == bag and it.slot == slot then return true end
    end
    if table.getn(M.items) >= UI.SLOTS then UI.Note("That is " .. UI.SLOTS .. " items: send these first.") return true end
    -- (soulbound and quest items cannot be mailed: the tooltip says so)
    if pfUI.mail.Bound and pfUI.mail.Bound(bag, slot) then UI.Note("That cannot be mailed (soulbound).") return true end
    local tex, count = GetContainerItemInfo(bag, slot)
    table.insert(M.items, { bag = bag, slot = slot, link = link, tex = tex, count = count })
    UI.Refresh()
    return true
  end
  -- the bag slot last picked up (the cursor knows the item, not where it came from)
  local pick = _G.PickupContainerItem
  if type(pick) == "function" and not UI.pickWrapped then
    UI.pickWrapped = true
    _G.PickupContainerItem = function(bag, slot)
      if not CursorHasItem() then UI.lastPick = { bag, slot } end
      return pick(bag, slot)
    end
  end
  function UI.Drop()
    if not CursorHasItem() or not UI.lastPick then return end
    local bag, slot = UI.lastPick[1], UI.lastPick[2]
    ClearCursor()
    UI.Add(bag, slot)
  end
  -- right-click in your bags while the Send tab is up: it is attached instead of used
  local use = _G.UseContainerItem
  if type(use) == "function" and not UI.useWrapped then
    UI.useWrapped = true
    _G.UseContainerItem = function(bag, slot, onSelf)
      if M.open and f:IsShown() and S().bagclick ~= "0" then
        if UI.tab ~= "send" then UI.Open("send") end
        if UI.Add(bag, slot) then return end
      end
      return use(bag, slot, onSelf)
    end
  end
  -- soulbound, from the bag tooltip
  local scan = CreateFrame("GameTooltip", "pfMailScan", UIParent, "GameTooltipTemplate")
  scan:SetOwner(UIParent, "ANCHOR_NONE")
  function M.Bound(bag, slot)
    scan:ClearLines()
    scan:SetOwner(UIParent, "ANCHOR_NONE")
    scan:SetBagItem(bag, slot)
    for k = 2, 4 do
      local line = _G["pfMailScanTextLeft" .. k]
      local t = line and line:GetText()
      if t and (t == ITEM_SOULBOUND or t == ITEM_BIND_QUEST or t == ITEM_CONJURED) then return true end
    end
    return false
  end

  UI.go = Btn(SE, "Send", 110, function()
    if M.sending then M.StopSend("stopped.") return end
    local money = UI.Cash()
    local cod = UI.mode == "cod" and money or 0
    if cod > 0 and table.getn(M.items) == 0 then UI.Note("Cash on delivery needs at least one item.") return end
    M.Send(UI.to:GetText(), UI.subj:GetText(), UI.body:GetText(), UI.mode == "cod" and 0 or money, cod, M.items, S().codeach == "1")
  end, "Sends it. With items: one mail for each, the text and money on the first.")
  UI.go:SetPoint("BOTTOMRIGHT", SE, "BOTTOMRIGHT", 0, 33)
  UI.clear = Btn(SE, "Clear", 70, function()
    if M.sending then return end
    M.items = {}
    for _, e in ipairs({ UI.to, UI.subj, UI.body }) do e:SetText("") end
    UI.ClearCash()
    UI.Refresh()
  end, "Empties the mail: name, subject, letter, money and items.")
  UI.clear:SetPoint("RIGHT", UI.go, "LEFT", -6, 0)
  M.onSent = function()
    M.items = {}
    UI.subj:SetText("")
    UI.body:SetText("")
    UI.ClearCash()
    UI.Refresh()
  end

  -- ---------------------------------------------------------------- paint

  function UI.Refresh()
    if not f:IsShown() then return end
    if UI.tab == "inbox" then
      local mails = M.List()
      UI.mails = mails
      local n = table.getn(mails)
      UI.top = math.max(0, math.min(UI.top, math.max(0, n - ROWS)))
      local gold, items = 0, 0
      for _, m in ipairs(mails) do
        gold = gold + m.money
        if m.item then items = items + 1 end
      end
      IN.count:SetText("|cffffffff" .. n .. "|r " .. (n == 1 and "mail" or "mails")
        .. (gold > 0 and ("   " .. M.Money(gold)) or "") .. (items > 0 and ("   |cffffffff" .. items .. "|r with items") or ""))
      local cur
      for r = 1, ROWS do
        local row, m = UI.rows[r], mails[UI.top + r]
        row.mail = m
        if m then
          row.icon:SetTexture(m.item and m.itemTex or m.icon or "Interface\\Icons\\INV_Letter_15")
          row.icon:SetDesaturated(M.skip[m.sig] and M.skip[m.sig] ~= "other" and 1 or nil)
          row.count:SetText(m.item and (m.count or 1) > 1 and m.count or "")
          local col = m.kind == "ah" and "|cffffd24d" or (m.kind == "player" and "|cffffffff" or "|cff9fd5ff")
          row.who:SetText(col .. m.sender .. "|r" .. (m.returned and "  |cffff8080sent back|r" or "")
            .. (m.read and "" or "  |cff40ff40new|r"))
          local why = M.skip[m.sig]
          row.what:SetText((why and why ~= "other" and why ~= "kept") and ("|cffff8060" .. why .. "|r") or m.subject)
          row.days:SetText(DaysText(m.days))
          row.cash:SetText(m.cod > 0 and ("|cffff6060COD|r " .. M.Money(m.cod)) or (m.money > 0 and M.Money(m.money) or ""))
          local sel = UI.sel == m.sig
          if sel then cur = m end
          if sel then
            local ar, ag, ab = Accent()
            row.bg:SetVertexColor(ar, ag, ab, .22)
          elseif MouseIsOver and MouseIsOver(row) then row.bg:SetVertexColor(1, 1, 1, .06)
          else row.bg:SetVertexColor(1, 1, 1, math.mod(r, 2) == 0 and .025 or 0) end
          row:Show()
        else
          row:Hide()
        end
      end
      if UI.sel and not cur then
        for _, m in ipairs(mails) do if m.sig == UI.sel then cur = m end end
      end
      Paint(cur)
      IN.collect.text:SetText(M.job and "Stop" or "Collect all")
      UI.kind = UI.kind or S().kind or "all"
      for _, k in ipairs(UI.KINDS) do UI.kindBtn[k[1]].Lit(UI.kind == k[1]) end
    else
      local n = table.getn(M.items)
      for k, b in ipairs(UI.slots) do
        local it = M.items[k]
        if it then
          b.icon:SetTexture(it.tex)
          b.count:SetText((it.count or 1) > 1 and it.count or "")
        else
          b.icon:SetTexture(nil)
          b.count:SetText("")
        end
      end
      SE.items.head:SetText(n == 0 and "Items" or ("Items: |cffffffff" .. n .. "|r " .. (n == 1 and "mail" or "mails")))
      UI.mode = UI.mode or "send"
      UI.sendMoney.Lit(UI.mode ~= "cod")
      UI.cod.Lit(UI.mode == "cod")
      UI.cod.text:SetText(UI.mode == "cod" and "|cffff8060C.O.D.|r" or "C.O.D.")
      UI.each.text:SetText(S().codeach == "1" and "On each mail" or "On the first mail")
      if UI.mode == "cod" and n > 1 then UI.each:Show() else UI.each:Hide() end
      local post = (GetSendMailPrice and GetSendMailPrice() or 30)
      UI.price:SetText("|cfffad14dPostage:|r  " .. M.Money(math.max(1, n) * post))
      if M.sending then
        UI.go.text:SetText("Stop (" .. (M.sending.sent) .. "/" .. table.getn(M.sending.queue) .. ")")
      else
        UI.go.text:SetText("Send")
      end
    end
  end
  M.onChange = UI.Refresh

  -- ---------------------------------------------------------------- open / close

  M.onShow = function()
    f:SetScale(tonumber(S().scale) or 1)
    local x, y = tonumber(S().x or ""), tonumber(S().y or "")
    if x and y then
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
    local g = rawget(_G, "MailFrame")
    if g and g:IsShown() then HideUIPanel(g) end
    f:Show()
    UI.sel = nil
    UI.Open("inbox")
    if S().autocollect == "1" then M.Collect(S().kind or "all") end
  end
  M.onHide = function()
    UI.handoff = true
    f:Hide()
    UI.handoff = nil
    M.items = {}
  end
  f:SetScript("OnHide", function()
    UI.sugg:Hide()
    if not UI.handoff and M.open then
      M.open = false
      CloseMail()
    end
  end)
  f:SetScript("OnUpdate", function()
    local now = GetTime()
    if (this.next or 0) > now then return end
    this.next = now + .2
    f.money:SetText(M.Money(GetMoney()))
    if UI.noteAt and now > UI.noteAt then UI.noteAt = nil f.note:SetText("") end
    if UI.suggHideAt and now > UI.suggHideAt then UI.suggHideAt = nil UI.sugg:Hide() end
    if M.dirty or M.job or M.sending then
      M.dirty = nil
      UI.Refresh()
    end
  end)
  f:SetScript("OnShow", function()
    local r, g, b = Accent()
    f.wash:SetVertexColor(r, g, b, .18)
  end)
end)
