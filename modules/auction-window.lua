pfUI:RegisterModule("auction-window", "vanilla", function ()
  -- pfUI Octo :: the auction house window (15 Nov 2026, modules/auction.lua is the engine).
  -- Four tabs: Browse (search every page, sort by price each, bid / buy out), Sell (your bag
  -- items, stacks of any size, prices from what is up now and from the item's history), My
  -- auctions (cancel), My bids (bid again / buy out). Opens in place of the game's window at
  -- an auctioneer; "Game window" in the title bar shows the original beside it.
  local AH = pfUI.auction
  if not AH then return end
  local UI = { tab = "browse", lists = {} }
  AH.ui = UI
  local function S() return C.auction end
  local WHITE = "Interface\\Buttons\\WHITE8X8"
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
        GameTooltip:AddLine(this.tip, 1, 1, 1, 1)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function() this:SetBackdropBorderColor(.3, .3, .34, 1) GameTooltip:Hide() end)
    b.tip = tip
    function b.Able(on)
      b.off = not on
      b.text:SetTextColor(on and 1 or .45, on and 1 or .45, on and 1 or .45)
    end
    function b.Lit(on)
      if on then local r, g, bl = Accent() b:SetBackdropColor(r * .45, g * .45, bl * .45, 1) else b:SetBackdropColor(.12, .12, .15, 1) end
    end
    return b
  end
  local function Edit(parent, w, onEnter, hint)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetWidth(w)
    e:SetHeight(22)
    e:SetAutoFocus(false)
    e:SetFont(pfUI.font_default, 12, "")
    e:SetTextInsets(6, 6, 0, 0)
    Flat(e, 1, .3)
    e:SetBackdropColor(.03, .03, .04, 1)
    e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    e:SetScript("OnEnterPressed", function() this:ClearFocus() if onEnter then onEnter(this) end end)
    if hint then
      e.hint = Text(e, 11)
      e.hint:SetPoint("LEFT", e, "LEFT", 7, 0)
      e.hint:SetTextColor(.45, .45, .5)
      e.hint:SetText(hint)
      e:SetScript("OnTextChanged", function()
        if this:GetText() == "" then this.hint:Show() else this.hint:Hide() end
        if this.changed then this.changed(this) end
      end)
    else
      e:SetScript("OnTextChanged", function() if this.changed then this.changed(this) end end)
    end
    return e
  end
  local function Label(parent, text, size)
    local t = Text(parent, size or 11)
    t:SetTextColor(.62, .62, .67)
    t:SetText(text)
    return t
  end

  -- a list: cols = { { title, width, justify, sortkey } }, draw(row, d) fills row.cell[i] / row.icon
  local function NewList(parent, cols, shown, draw, onPick)
    local l = CreateFrame("Frame", nil, parent)
    l.cols, l.data, l.offset, l.rows, l.shown = cols, {}, 0, {}, shown
    Flat(l, .6)
    local x = 6
    l.heads = {}
    for ii, c in ipairs(cols) do
      local i = ii
      local h = CreateFrame("Button", nil, l)
      h:SetHeight(18)
      h:SetWidth(c[2])
      h:SetPoint("TOPLEFT", l, "TOPLEFT", x, -2)
      h.text = Text(h, 11, c[3])
      h.text:SetAllPoints(h)
      h.text:SetTextColor(.62, .62, .67)
      h.text:SetText(c[1])
      h:SetScript("OnClick", function()
        if not cols[i][4] then return end
        if l.sortBy == cols[i][4] then l.desc = not l.desc else l.sortBy, l.desc = cols[i][4], false end
        l.Sort()
        l.Paint()
      end)
      l.heads[i] = h
      c.x = x
      x = x + c[2] + 6
    end
    for rr = 1, shown do
      local r = CreateFrame("Button", nil, l)
      r:SetHeight(18)
      r:SetPoint("TOPLEFT", l, "TOPLEFT", 2, -22 - (rr - 1) * 18)
      r:SetPoint("RIGHT", l, "RIGHT", -2, 0)
      r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      r.hl = r:CreateTexture(nil, "BACKGROUND")
      r.hl:SetAllPoints(r)
      r.hl:SetTexture(1, 1, 1, .07)
      r.hl:Hide()
      r.pick = r:CreateTexture(nil, "BACKGROUND")
      r.pick:SetAllPoints(r)
      r.pick:Hide()
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetWidth(16)
      r.icon:SetHeight(16)
      r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
      r.icon:SetTexCoord(.07, .93, .07, .93)
      r.cell = {}
      for i, c in ipairs(cols) do
        local t = Text(r, 12, c[3])
        t:SetPoint("LEFT", r, "LEFT", c.x - 2 + (i == 1 and 20 or 0), 0)
        t:SetWidth(c[2] - (i == 1 and 20 or 0))
        t:SetHeight(18)
        r.cell[i] = t
      end
      r:SetScript("OnEnter", function()
        this.hl:Show()
        local d = this.d
        if d and d.link then
          local _, _, item = string.find(d.link, "(item:%d+:%d*:%d*:%d*)")
          if item then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item)
            GameTooltip:Show()
          end
        end
      end)
      r:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
      r:SetScript("OnClick", function()
        if not this.d then return end
        if IsShiftKeyDown() and this.d.link and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
          ChatFrameEditBox:Insert(this.d.link)
          return
        end
        l.sel = this.d
        l.Paint()
        if onPick then onPick(this.d, arg1) end
      end)
      l.rows[rr] = r
    end
    l:SetHeight(26 + shown * 18)
    l:EnableMouseWheel(true)
    l:SetScript("OnMouseWheel", function()
      local max = math.max(0, table.getn(l.data) - l.shown)
      l.offset = math.max(0, math.min(max, l.offset - (arg1 or 0) * 3))
      l.Paint()
    end)
    l.count = Text(l, 10, "RIGHT")
    l.count:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", -6, 3)
    l.count:SetTextColor(.5, .5, .55)
    function l.Sort()
      local key, desc = l.sortBy, l.desc
      if not key then return end
      table.sort(l.data, function(a, b)
        local va, vb = a[key], b[key]
        if va == vb then return (a.name or "") < (b.name or "") end
        if va == nil then return false end
        if vb == nil then return true end
        if desc then return va > vb end
        return va < vb
      end)
    end
    function l.Paint()
      local n = table.getn(l.data)
      if l.offset > math.max(0, n - l.shown) then l.offset = math.max(0, n - l.shown) end
      local ar, ag, ab = Accent()
      for i = 1, l.shown do
        local r, d = l.rows[i], l.data[i + l.offset]
        r.d = d
        if d then
          draw(r, d)
          if l.sel == d then r.pick:SetTexture(ar, ag, ab, .28) r.pick:Show() else r.pick:Hide() end
          r:Show()
        else
          r:Hide()
        end
      end
      for i, h in ipairs(l.heads) do
        local c = l.cols[i]
        h.text:SetText(c[1] .. ((l.sortBy and c[4] == l.sortBy) and (l.desc and " v" or " ^") or ""))
      end
      l.count:SetText(n > l.shown and ((l.offset + 1) .. " - " .. math.min(n, l.offset + l.shown) .. " of " .. n) or (n > 0 and (n .. "") or ""))
    end
    function l.Set(data, keep)
      l.data = data or {}
      if not keep then l.offset = 0 end
      -- (the picked one stays picked while it is still listed)
      local had = false
      for _, d in ipairs(l.data) do if d == l.sel then had = true end end
      if not had then l.sel = nil end
      l.Sort()
      l.Paint()
    end
    return l
  end
  local function ItemCell(r, d, count)
    r.icon:SetTexture(d.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    local cr, cg, cb = 1, 1, 1
    if d.quality and GetItemQualityColor then cr, cg, cb = GetItemQualityColor(d.quality) end
    r.cell[1]:SetText(d.name .. ((count and count > 1) and ("  |cffffffffx" .. count .. "|r") or ""))
    if d.color then r.cell[1]:SetText("|c" .. d.color .. d.name .. "|r" .. ((count and count > 1) and ("  x" .. count) or ""))
    elseif type(cr) == "number" then r.cell[1]:SetTextColor(cr, cg, cb) else r.cell[1]:SetTextColor(1, 1, 1) end
  end

  -- ---------------------------------------------------------------- the window

  local f = CreateFrame("Frame", "pfAuction", UIParent)
  UI.frame = f
  f:SetWidth(880)
  f:SetHeight(560)
  f:SetPoint("LEFT", UIParent, "LEFT", 40, 30)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  Flat(f, .97)
  f:Hide()
  table.insert(UISpecialFrames, "pfAuction")
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
  f.title:SetText("Auction House")
  f.money = Text(f.bar, 12, "RIGHT")
  f.close = Btn(f.bar, "X", 24, function() f:Hide() end, "Close the auction house (Esc).")
  f.close:SetPoint("RIGHT", f.bar, "RIGHT", -4, 0)
  f.game = Btn(f.bar, "Game window", 100, function()
    local a = rawget(_G, "AuctionFrame")
    if not a or not a.IsShown then return end
    AH.hideGame = nil
    if a:IsShown() then a:Hide() else ShowUIPanel(a) end
  end, "Show or hide the game's own auction window beside this one.")
  f.game:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.opts = Btn(f.bar, "Options", 70, function()
    if pfUI.gui and pfUI.octoui and pfUI.octoui.Options then
      if not pfUI.gui:IsShown() then pfUI.gui:Show() end
      pfUI.octoui.Options:Open("auction")
    end
  end)
  f.opts:SetPoint("RIGHT", f.game, "LEFT", -6, 0)
  f.money:SetPoint("RIGHT", f.opts, "LEFT", -14, 0)
  f.note = Text(f, 12)
  f.note:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
  f.note:SetWidth(520)
  f.note:SetTextColor(1, .82, .3)
  function UI.Note(text)
    f.note:SetText(text or "")
    UI.noteAt = GetTime() + 6
  end
  AH.onNote = UI.Note

  UI.TABS = { { "browse", "Browse" }, { "sell", "Sell" }, { "owner", "My auctions" }, { "bidder", "My bids" } }
  UI.pages, UI.tabBtn = {}, {}
  local tx = 150
  for _, t in ipairs(UI.TABS) do
    local key = t[1]
    local b = Btn(f.bar, t[2], 96, function() UI.Open(key) end)
    b:SetPoint("LEFT", f.bar, "LEFT", tx, 0)
    tx = tx + 100
    UI.tabBtn[key] = b
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 34)
    p:Hide()
    UI.pages[key] = p
  end

  -- ---------------------------------------------------------------- Browse

  local B = UI.pages.browse
  UI.q = { quality = nil, class = nil, usable = false, exact = false }
  UI.QUALITY = { { nil, "Any quality" }, { 2, "Uncommon +" }, { 3, "Rare +" }, { 4, "Epic +" } }
  local function PctCell(d)
    local v = d.unit and AH.Value(d.key)
    if not v or v <= 0 then return "" end
    local p = d.unit / v * 100
    local col = (p <= 80 and "|cff40e060") or (p <= 120 and "|cffffffff") or "|cffff7060"
    return col .. math.floor(p + .5) .. "%|r"
  end
  local function Search(first)
    local name = B.name:GetText()
    local q = { name = name, minLevel = tonumber(B.min:GetText()), maxLevel = tonumber(B.max:GetText()), quality = UI.q.quality,
      class = UI.q.class, usable = UI.q.usable, exact = UI.q.exact and name ~= "", first = first,
      maxUnit = AH.ParseMoney(B.maxp:GetText()) }
    UI.Recent(name)
    AH.Search(q, function(s) UI.Status() end, function(why) UI.Status(why) end)
    UI.Status()
  end
  UI.Search = Search
  B.name = Edit(B, 220, function() Search() end, "Item name (Enter = search)")
  B.name:SetPoint("TOPLEFT", B, "TOPLEFT", 0, 0)
  B.min = Edit(B, 34, function() Search() end, "lvl")
  B.min:SetPoint("LEFT", B.name, "RIGHT", 6, 0)
  B.max = Edit(B, 34, function() Search() end, "to")
  B.max:SetPoint("LEFT", B.min, "RIGHT", 4, 0)
  B.maxp = Edit(B, 86, function() Search() end, "max each")
  B.maxp:SetPoint("LEFT", B.max, "RIGHT", 6, 0)
  B.quality = Btn(B, "Any quality", 92, function(b)
    UI.qi = math.mod(UI.qi or 1, table.getn(UI.QUALITY)) + 1
    UI.q.quality = UI.QUALITY[UI.qi][1]
    b.text:SetText(UI.QUALITY[UI.qi][2])
  end, "Click to step: any, uncommon and better, rare and better, epic and better.")
  B.quality:SetPoint("LEFT", B.maxp, "RIGHT", 6, 0)
  B.class = Btn(B, "Any kind", 110, function(b)
    local W = pfUI.octoui and pfUI.octoui.W
    if not W or not W.Menu or not GetAuctionItemClasses then return end
    local opts = { { key = 0, label = "Any kind" } }
    for i, name in ipairs({ GetAuctionItemClasses() }) do table.insert(opts, { key = i, label = name }) end
    if W.CloseMenus then W.CloseMenus() end
    local m = W.Menu(b, opts, 150, function(key)
      UI.q.class = (key ~= 0) and key or nil
      b.text:SetText(key == 0 and "Any kind" or opts[key + 1].label)
    end)
    if m and m.Show then m:Show() end
  end, "Weapons, armour, trade goods...")
  B.class:SetPoint("LEFT", B.quality, "RIGHT", 6, 0)
  B.usable = Btn(B, "Usable", 62, function(b) UI.q.usable = not UI.q.usable b.Lit(UI.q.usable) end, "Only what this character can use.")
  B.usable:SetPoint("LEFT", B.class, "RIGHT", 6, 0)
  B.exact = Btn(B, "Exact", 54, function(b) UI.q.exact = not UI.q.exact b.Lit(UI.q.exact) end, "Only the item with exactly this name.")
  B.exact:SetPoint("LEFT", B.usable, "RIGHT", 6, 0)
  B.go = Btn(B, "Search", 76, function() if AH.Searching() then AH.Stop() else Search() end end, "Every page of the search. Click again to stop.")
  B.go:SetPoint("LEFT", B.exact, "RIGHT", 6, 0)
  B.list = NewList(B, { { "Item", 290, "LEFT", "name" }, { "Lvl", 30, "RIGHT", "level" }, { "Time left", 86, "LEFT", "left" },
    { "Seller", 100, "LEFT", "owner" }, { "Bid each", 104, "RIGHT", "bidunit" }, { "Buyout each", 104, "RIGHT", "unit" },
    { "Of usual", 60, "RIGHT" } }, 22, function(r, d)
    ItemCell(r, d, d.count)
    r.cell[2]:SetText(d.level > 0 and d.level or "")
    r.cell[3]:SetText(AH.LEFT[d.left] or "")
    r.cell[4]:SetText(d.owner or "")
    r.cell[5]:SetText(AH.Money(d.bidunit) .. (d.high and " |cff40e060*|r" or ""))
    r.cell[6]:SetText(d.unit and AH.Money(d.unit) or "|cff808080-|r")
    r.cell[7]:SetText(PctCell(d))
    for i = 2, 4 do r.cell[i]:SetTextColor(.8, .8, .84) end
  end, function(d, button)
    UI.PaintBuy()
    -- (Alt + click = buy it out at once; Ctrl + click = bid)
    if IsAltKeyDown() then UI.Buy("buyout") elseif IsControlKeyDown() then UI.Buy("bid") end
  end)
  B.list:SetPoint("TOPLEFT", B, "TOPLEFT", 0, -28)
  B.list:SetPoint("RIGHT", B, "RIGHT", 0, 0)
  B.list.sortBy = "unit"
  B.status = Text(B, 11)
  B.status:SetPoint("TOPLEFT", B.list, "BOTTOMLEFT", 4, -8)
  B.status:SetTextColor(.62, .62, .67)
  B.buy = Btn(B, "Buyout", 190, function() UI.Buy("buyout") end, "Buy the picked auction out. Alt + click a row does it in one go.")
  B.buy:SetPoint("TOPRIGHT", B.list, "BOTTOMRIGHT", 0, -4)
  B.bid = Btn(B, "Bid", 190, function() UI.Buy("bid") end, "Bid on the picked auction. Ctrl + click a row does it in one go.")
  B.bid:SetPoint("RIGHT", B.buy, "LEFT", -6, 0)
  function UI.Status(why)
    local s = AH.scan
    local n = table.getn(AH.rows)
    if s then
      B.status:SetText("Searching: page " .. (s.page + 1) .. (s.pages > 0 and (" of " .. s.pages) or "") .. "   " .. n .. " found so far")
      B.go.text:SetText("Stop")
    else
      B.status:SetText((why and why ~= "done") and (n .. " found (" .. why .. ")") or (n .. " found" .. (AH.total > 0 and (" in " .. AH.total .. " auctions") or "")))
      B.go.text:SetText("Search")
    end
  end
  function UI.PaintBuy()
    local d = UI.List().sel
    local kind = UI.tab == "bidder" and UI.pages.bidder or B
    local bid, buy = kind.bid, kind.buy
    if not bid then return end
    if d then
      bid.text:SetText("Bid  " .. AH.Money(d.next))
      buy.text:SetText(d.buyout > 0 and ("Buyout  " .. AH.Money(d.buyout)) or "No buyout")
      bid.Able(AH.CanBuy(d, "bid") == "ok")
      buy.Able(AH.CanBuy(d, "buyout") == "ok")
    else
      bid.text:SetText("Bid") buy.text:SetText("Buyout")
      bid.Able(false) buy.Able(false)
    end
  end
  function UI.List() return UI.lists[UI.tab] or B.list end
  function UI.Buy(how)
    local d = UI.List().sel
    local ok, why = AH.Buy(d, how)
    if not ok then UI.Note("Cannot " .. (how == "buyout" and "buy" or "bid") .. ": " .. tostring(why) .. ".")
    elseif why then UI.Note(why .. "...")
    else UI.Note((how == "buyout" and "Bought " or "Bid on ") .. d.name .. " for " .. AH.Money(AH.Cost(d, how), true) .. ".") end
    UI.Refresh()
  end
  -- the last searches, newest first (per account)
  function UI.Recent(name)
    if not name or name == "" then return end
    local st = AH.Store()
    st.recent = st.recent or {}
    for i, n in ipairs(st.recent) do if string.lower(n) == string.lower(name) then table.remove(st.recent, i) break end end
    table.insert(st.recent, 1, name)
    while table.getn(st.recent) > 15 do table.remove(st.recent) end
  end
  B.recent = Btn(B, "Recent", 66, function(b)
    local W = pfUI.octoui and pfUI.octoui.W
    local list = AH.Store().recent or {}
    if not W or not W.Menu or table.getn(list) == 0 then return end
    local opts = {}
    for _, n in ipairs(list) do table.insert(opts, { key = n, label = n }) end
    if W.CloseMenus then W.CloseMenus() end
    local m = W.Menu(b, opts, 200, function(key) B.name:SetText(key) Search() end)
    if m and m.Show then m:Show() end
  end, "Your last searches.")
  B.recent:SetPoint("LEFT", B.go, "RIGHT", 6, 0)
  UI.lists.browse = B.list

  -- ---------------------------------------------------------------- Sell

  local P = UI.pages.sell
  P.items = NewList(P, { { "In your bags", 250, "LEFT", "name" } }, 24, function(r, d)
    ItemCell(r, d, d.total)
  end, function(d) UI.PickSell(d) end)
  P.items:SetPoint("TOPLEFT", P, "TOPLEFT", 0, 0)
  P.items:SetWidth(270)
  P.items.sortBy = "name"
  P.box = CreateFrame("Frame", nil, P)
  P.box:SetPoint("TOPLEFT", P.items, "TOPRIGHT", 10, 0)
  P.box:SetPoint("BOTTOMRIGHT", P, "BOTTOMRIGHT", 0, 0)
  P.head = Text(P.box, 15)
  P.head:SetPoint("TOPLEFT", P.box, "TOPLEFT", 4, -2)
  P.head:SetText("Pick an item on the left")
  local function Field(label, y, w, hint)
    local l = Label(P.box, label)
    l:SetPoint("TOPLEFT", P.box, "TOPLEFT", 4, y - 5)
    local e = Edit(P.box, w, function() UI.PaintSell() end, hint)
    e:SetPoint("TOPLEFT", P.box, "TOPLEFT", 120, y)
    e.changed = function() UI.PaintSell() end
    return e
  end
  P.size = Field("Stack size", -34, 60)
  P.stacks = Field("Number of stacks", -62, 60)
  P.bidp = Field("Starting price each", -90, 130, "1g 20s 5c")
  P.buyp = Field("Buyout each", -118, 130, "1g 20s 5c")
  P.maxb = Btn(P.box, "All I have", 90, function() UI.FillStacks() end, "As many stacks of this size as your bags hold.")
  P.maxb:SetPoint("LEFT", P.stacks, "RIGHT", 6, 0)
  P.hours = {}
  local hl = Label(P.box, "Lasts")
  hl:SetPoint("TOPLEFT", P.box, "TOPLEFT", 4, -151)
  for i, h in ipairs({ 2, 8, 24 }) do
    local hours = h
    local b = Btn(P.box, hours .. " h", 50, function() UI.hours = hours UI.PaintSell() end)
    b:SetPoint("TOPLEFT", P.box, "TOPLEFT", 120 + (i - 1) * 54, -146)
    P.hours[hours] = b
  end
  P.info = Text(P.box, 12)
  P.info:SetPoint("TOPLEFT", P.box, "TOPLEFT", 330, -34)
  P.info:SetWidth(250)
  P.info:SetJustifyV("TOP")
  P.look = Btn(P.box, "Look up prices", 120, function() UI.Lookup() end, "Searches the auction house for this item to see what it sells for now.")
  P.look:SetPoint("TOPLEFT", P.box, "TOPLEFT", 4, -180)
  P.under = Btn(P.box, "Undercut cheapest", 130, function() UI.Price("under") end, "Just under the cheapest other seller (how much: Options).")
  P.under:SetPoint("LEFT", P.look, "RIGHT", 6, 0)
  P.usual = Btn(P.box, "Usual price", 100, function() UI.Price("value") end, "The item's usual price from the history.")
  P.usual:SetPoint("LEFT", P.under, "RIGHT", 6, 0)
  P.last = Btn(P.box, "My last price", 100, function() UI.Price("saved") end, "What you asked last time.")
  P.last:SetPoint("LEFT", P.usual, "RIGHT", 6, 0)
  P.sum = Text(P.box, 12)
  P.sum:SetPoint("TOPLEFT", P.box, "TOPLEFT", 4, -212)
  P.sum:SetWidth(580)
  P.post = Btn(P.box, "Post", 160, function() UI.Post() end)
  P.post:SetPoint("TOPLEFT", P.box, "TOPLEFT", 4, -236)
  P.rivals = NewList(P.box, { { "On the auction house now", 200, "LEFT", "name" }, { "Seller", 110, "LEFT", "owner" }, { "Time left", 86, "LEFT", "left" },
    { "Buyout each", 110, "RIGHT", "unit" } }, 10, function(r, d)
    ItemCell(r, d, d.count)
    r.cell[2]:SetText(d.owner or "")
    r.cell[3]:SetText(AH.LEFT[d.left] or "")
    r.cell[4]:SetText(d.unit and AH.Money(d.unit) or "|cff808080-|r")
    if d.owner == UnitName("player") then r.cell[2]:SetTextColor(.4, .9, .5) else r.cell[2]:SetTextColor(.8, .8, .84) end
  end)
  P.rivals:SetPoint("TOPLEFT", P.box, "TOPLEFT", 0, -268)
  P.rivals:SetPoint("RIGHT", P.box, "RIGHT", 0, 0)
  P.rivals.sortBy = "unit"
  UI.hours = 24
  UI.lists.sell = P.items
  local function SetMoney(e, copper) e:SetText(copper and copper > 0 and AH.Money(copper, true) or "") end
  function UI.PickSell(d)
    UI.sell = d
    P.head:SetText((d.color and ("|c" .. d.color) or "") .. d.name .. "|r   |cff9a9aa0" .. d.total .. " in your bags|r")
    local sug = AH.Suggest(d.key, d.name)
    local biggest = 1
    for _, s in ipairs(d.slots) do if s.count > biggest then biggest = s.count end end
    local size = (sug.saved and sug.saved.size) or biggest
    if size > d.total then size = d.total end
    P.size:SetText(tostring(size))
    P.stacks:SetText(tostring(S().allstacks == "1" and math.floor(d.total / size) or 1))
    UI.hours = (sug.saved and sug.saved.hours) or tonumber(S().hours) or 24
    if sug.saved then SetMoney(P.bidp, sug.saved.bid) SetMoney(P.buyp, sug.saved.buyout) else P.bidp:SetText("") P.buyp:SetText("") end
    UI.PaintSell()
    if S().autolookup ~= "0" then UI.Lookup() end
  end
  function UI.FillStacks()
    local d = UI.sell
    local size = tonumber(P.size:GetText())
    if d and size and size > 0 then P.stacks:SetText(tostring(math.floor(d.total / size))) UI.PaintSell() end
  end
  function UI.Lookup()
    local d = UI.sell
    if not d then return end
    AH.Search({ name = d.name, exact = true }, function() UI.PaintSell() end, function()
      -- (first look at an item with no price yet: start from the cheapest)
      if UI.sell == d and P.buyp:GetText() == "" then UI.Price("under", true) end
      UI.PaintSell()
    end)
  end
  -- which = under | value | saved
  function UI.Price(which, quiet)
    local d = UI.sell
    if not d then return end
    local sug = AH.Suggest(d.key, d.name)
    local buy
    if which == "under" then buy = AH.Undercut(sug.other) or sug.value
    elseif which == "value" then buy = sug.value
    elseif sug.saved then buy = sug.saved.buyout end
    if not buy or buy <= 0 then
      if not quiet then UI.Note("No price known for this yet: look it up first.") end
      return
    end
    SetMoney(P.buyp, buy)
    local share = (tonumber(S().bidshare) or 95) / 100
    SetMoney(P.bidp, (which == "saved" and sug.saved.bid) or math.max(1, math.floor(buy * share)))
    UI.PaintSell()
  end
  function UI.SellNumbers()
    local d = UI.sell
    if not d then return nil end
    local size, stacks = tonumber(P.size:GetText()), tonumber(P.stacks:GetText())
    local bid, buy = AH.ParseMoney(P.bidp:GetText()), AH.ParseMoney(P.buyp:GetText()) or 0
    if not size or not stacks or size < 1 or stacks < 1 then return nil, "Fill in the stack size and how many." end
    if size * stacks > d.total then return nil, "You have only " .. d.total .. "." end
    if not bid or bid < 1 then
      if buy > 0 then bid = math.max(1, math.floor(buy * (tonumber(S().bidshare) or 95) / 100)) else return nil, "Fill in a price." end
    end
    if buy > 0 and buy < bid then return nil, "The buyout is under the starting price." end
    return { size = size, stacks = stacks, bid = bid, buy = buy }
  end
  function UI.PaintSell()
    for h, b in pairs(P.hours) do b.Lit(h == UI.hours) end
    local d = UI.sell
    if not d then P.post.Able(false) P.sum:SetText("") P.info:SetText("") P.rivals.Set({}) return end
    local sug = AH.Suggest(d.key, d.name)
    local value, days = AH.Value(d.key)
    P.info:SetText("Cheapest now:  " .. (sug.other and AH.Money(sug.other) or (AH.Searching() and "|cff9a9aa0looking...|r" or "|cff9a9aa0none seen|r"))
      .. "\nUsual price:  " .. (value and (AH.Money(value) .. "  |cff9a9aa0(" .. days .. (days == 1 and " day" or " days") .. ")|r") or "|cff9a9aa0not known yet|r")
      .. "\nMy last price:  " .. ((sug.saved and sug.saved.buyout > 0) and AH.Money(sug.saved.buyout) or "|cff9a9aa0-|r"))
    local rows = {}
    for _, r in ipairs(AH.rows) do if r.key == d.key then table.insert(rows, r) end end
    P.rivals.Set(rows, true)
    local n, why = UI.SellNumbers()
    if AH.job then
      P.sum:SetText("|cffffd24dPosting: " .. AH.job.posted .. " up, " .. AH.job.left .. " to go...|r")
      P.post.text:SetText("Stop")
      P.post.Able(true)
    elseif n then
      P.sum:SetText(n.stacks .. (n.stacks == 1 and " stack of " or " stacks of ") .. n.size .. "   each stack: start " .. AH.Money(n.bid * n.size)
        .. (n.buy > 0 and ("   buyout " .. AH.Money(n.buy * n.size)) or "   no buyout")
        .. (n.buy > 0 and ("   |cff9a9aa0all sold = " .. AH.Money(n.buy * n.size * n.stacks, true) .. "|r") or ""))
      P.post.text:SetText("Post " .. n.stacks .. " x " .. n.size)
      P.post.Able(true)
    else
      P.sum:SetText("|cffff7060" .. (why or "") .. "|r")
      P.post.text:SetText("Post")
      P.post.Able(false)
    end
  end
  function UI.Post()
    if AH.job then AH.job.left = 0 return end
    local d = UI.sell
    local n, why = UI.SellNumbers()
    if not d or not n then UI.Note(why or "Nothing to post.") return end
    local ok, err = AH.Post(d.key, n.size, n.stacks, n.bid * n.size, n.buy * n.size, UI.hours)
    if not ok then UI.Note("Cannot post: " .. tostring(err) .. ".") end
    UI.PaintSell()
  end

  -- ---------------------------------------------------------------- My auctions / My bids

  local O = UI.pages.owner
  O.list = NewList(O, { { "Item", 320, "LEFT", "name" }, { "Time left", 90, "LEFT", "left" }, { "High bid", 120, "RIGHT", "bid" },
    { "Starting", 110, "RIGHT", "minBid" }, { "Buyout", 120, "RIGHT", "buyout" } }, 23, function(r, d)
    ItemCell(r, d, d.count)
    r.cell[2]:SetText(AH.LEFT[d.left] or "")
    r.cell[3]:SetText(d.bid > 0 and AH.Money(d.bid) or "|cff808080no bid|r")
    r.cell[4]:SetText(AH.Money(d.minBid))
    r.cell[5]:SetText(d.buyout > 0 and AH.Money(d.buyout) or "|cff808080-|r")
    r.cell[2]:SetTextColor(.8, .8, .84)
  end, function() UI.PaintOwner() end)
  O.list:SetPoint("TOPLEFT", O, "TOPLEFT", 0, 0)
  O.list:SetPoint("RIGHT", O, "RIGHT", 0, 0)
  O.cancel = Btn(O, "Cancel this auction", 190, function()
    local d = O.list.sel
    if not d then return end
    if AH.Cancel(d) then UI.Note("Cancelled " .. d.name .. ".") else UI.Note("That auction is gone.") end
  end, "Takes the picked auction down. You lose its deposit; an auction with a bid on it costs more.")
  O.cancel:SetPoint("TOPRIGHT", O.list, "BOTTOMRIGHT", 0, -4)
  O.sumText = Text(O, 11)
  O.sumText:SetPoint("TOPLEFT", O.list, "BOTTOMLEFT", 4, -8)
  O.sumText:SetTextColor(.62, .62, .67)
  function UI.PaintOwner() O.cancel.Able(O.list.sel ~= nil) end
  UI.lists.owner = O.list
  local D = UI.pages.bidder
  D.list = NewList(D, { { "Item", 300, "LEFT", "name" }, { "Time left", 90, "LEFT", "left" }, { "Seller", 110, "LEFT", "owner" },
    { "Bid now", 120, "RIGHT", "bid" }, { "Buyout", 120, "RIGHT", "buyout" }, { "", 60, "RIGHT" } }, 23, function(r, d)
    ItemCell(r, d, d.count)
    r.cell[2]:SetText(AH.LEFT[d.left] or "")
    r.cell[3]:SetText(d.owner or "")
    r.cell[4]:SetText(AH.Money(d.bid))
    r.cell[5]:SetText(d.buyout > 0 and AH.Money(d.buyout) or "|cff808080-|r")
    r.cell[6]:SetText(d.high and "|cff40e060yours|r" or "|cffff7060outbid|r")
    for i = 2, 3 do r.cell[i]:SetTextColor(.8, .8, .84) end
  end, function() UI.PaintBuy() end)
  D.list:SetPoint("TOPLEFT", D, "TOPLEFT", 0, 0)
  D.list:SetPoint("RIGHT", D, "RIGHT", 0, 0)
  D.buy = Btn(D, "Buyout", 190, function() UI.Buy("buyout") end)
  D.buy:SetPoint("TOPRIGHT", D.list, "BOTTOMRIGHT", 0, -4)
  D.bid = Btn(D, "Bid", 190, function() UI.Buy("bid") end, "Bid again on an auction you were outbid on.")
  D.bid:SetPoint("RIGHT", D.buy, "LEFT", -6, 0)
  UI.lists.bidder = D.list

  -- ---------------------------------------------------------------- showing

  function UI.Refresh(event)
    if not f:IsShown() then return end
    if UI.tab == "browse" then
      B.list.Set(AH.rows, true)
      UI.Status()
      UI.PaintBuy()
    elseif UI.tab == "sell" then
      if AH.bagsDirty or not UI.bagList then
        AH.bagsDirty = nil
        UI.bagList = AH.Bags()
        local keep
        for _, e in ipairs(UI.bagList) do if UI.sell and e.key == UI.sell.key then keep = e end end
        UI.sell = keep
        P.items.Set(UI.bagList, true)
        P.items.sel = keep
        P.items.Paint()
        if not keep then P.head:SetText("Pick an item on the left") end
      end
      UI.PaintSell()
    elseif UI.tab == "owner" then
      local rows = AH.Owned()
      O.list.Set(rows, true)
      local total, bids = 0, 0
      for _, r in ipairs(rows) do
        total = total + r.buyout
        if r.bid > 0 then bids = bids + 1 end
      end
      O.sumText:SetText(table.getn(rows) .. " auctions   " .. bids .. " with a bid   all buyouts together: " .. AH.Money(total))
      UI.PaintOwner()
    elseif UI.tab == "bidder" then
      D.list.Set(AH.Bids(), true)
      UI.PaintBuy()
    end
  end
  AH.onChange = UI.Refresh
  function UI.Open(tab)
    UI.tab = tab or UI.tab
    for key, p in pairs(UI.pages) do
      if key == UI.tab then p:Show() else p:Hide() end
      UI.tabBtn[key].Lit(key == UI.tab)
    end
    if UI.tab == "owner" or UI.tab == "bidder" then AH.Ask(UI.tab) end
    if UI.tab == "sell" then AH.bagsDirty = true end
    UI.Refresh()
  end
  function AH.Show()
    f:SetScale(tonumber(S().scale) or 1)
    local x, y = tonumber(S().x), tonumber(S().y)
    f:ClearAllPoints()
    if x and y then f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y) else f:SetPoint("LEFT", UIParent, "LEFT", 40, 30) end
    local r, g, b = Accent()
    f.wash:SetGradientAlpha("HORIZONTAL", r, g, b, .35, r, g, b, .04)
    f:Show()
    UI.Open(S().lasttab == "1" and UI.tab or "browse")
  end
  function AH.Hide() f:Hide() end
  f:SetScript("OnHide", function()
    if AH.open then
      AH.open = false
      PlaySound("AuctionWindowClose")
      CloseAuctionHouse()
    end
    local a = rawget(_G, "AuctionFrame")
    if a and a.IsShown and a:IsShown() then a:Hide() end
  end)
  f:SetScript("OnShow", function() PlaySound("AuctionWindowOpen") end)
  f:SetScript("OnUpdate", function()
    local now = GetTime()
    if (this.next or 0) > now then return end
    this.next = now + .25
    f.money:SetText(AH.Money(GetMoney()))
    if UI.noteAt and now > UI.noteAt then UI.noteAt = nil f.note:SetText("") end
    if UI.tab == "sell" and (AH.bagsDirty or AH.job or AH.Searching()) then UI.Refresh() end
  end)
end)
