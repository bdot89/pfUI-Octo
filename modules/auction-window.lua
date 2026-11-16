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
  -- (16 Nov 2026, user: "ours is a bit plain ... PROFESSIONAL") one colour language, as the options window's:
  -- green = go, gold = costs gold, red = takes something away; time left red when nearly over
  local ROLE = { go = { .16, .42, .22, .3, .75, .4 }, buy = { .45, .34, .08, .95, .75, .2 }, danger = { .42, .14, .12, .9, .35, .3 } }
  local function Role(b, role)
    local c = ROLE[role]
    if not c then return b end
    b.role = c
    b:SetBackdropColor(c[1], c[2], c[3], 1)
    b:SetBackdropBorderColor(c[4], c[5], c[6], 1)
    b:SetScript("OnLeave", function() this:SetBackdropBorderColor(this.role[4], this.role[5], this.role[6], 1) GameTooltip:Hide() end)
    local able = b.Able
    b.Able = function(on)
      able(on)
      if on then b:SetBackdropColor(c[1], c[2], c[3], 1) else b:SetBackdropColor(.1, .1, .12, 1) end
    end
    return b
  end
  local LEFTCOL = { "|cffff5a4a", "|cffffa040", "|cffe8e8a0", "|cff9ad0a0" }
  function UI.Left(left) return AH.LEFT[left] and ((LEFTCOL[left] or "") .. AH.LEFT[left] .. "|r") or "" end
  local ME
  function UI.Seller(name)
    ME = ME or UnitName("player")
    if not name then return "" end
    return name == ME and ("|cff40e060" .. name .. "|r") or name
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
      h.text:SetTextColor(Accent())
      h.text:SetText(c[1])
      h:SetScript("OnClick", function()
        if not cols[i][4] then return end
        if l.sortBy == cols[i][4] then l.desc = not l.desc else l.sortBy, l.desc = cols[i][4], false end
        l.Sort()
        l.Paint()
      end)
      l.heads[i] = h
      if i == 1 and c[5] then
        h:SetWidth(c[2] - 46)
        local sh = CreateFrame("Button", nil, l)
        sh:SetHeight(18)
        sh:SetWidth(46)
        sh:SetPoint("TOPLEFT", l, "TOPLEFT", x + c[2] - 46, -2)
        sh.text = Text(sh, 11, "RIGHT")
        sh.text:SetPoint("RIGHT", sh, "RIGHT", -4, 0)
        sh.text:SetTextColor(Accent())
        sh.text:SetText(c[5] == "total" and "Have" or "Stack")
        sh:SetScript("OnClick", function()
          if l.sortBy == cols[1][5] then l.desc = not l.desc else l.sortBy, l.desc = cols[1][5], true end
          l.Sort()
          l.Paint()
        end)
        l.stackHead = sh
      end
      c.x = x
      x = x + c[2] + 6
    end
    for rr = 1, shown do
      local r = CreateFrame("Button", nil, l)
      r:SetHeight(20)
      r:SetPoint("TOPLEFT", l, "TOPLEFT", 2, -24 - (rr - 1) * 20)
      -- (every other row a shade lighter: easier to follow across the columns)
      r.zebra = r:CreateTexture(nil, "BACKGROUND")
      r.zebra:SetAllPoints(r)
      r.zebra:SetTexture(1, 1, 1, .03)
      if math.mod(rr, 2) == 1 then r.zebra:Hide() end
      r:SetPoint("RIGHT", l, "RIGHT", -2, 0)
      r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      r.hl = r:CreateTexture(nil, "BACKGROUND")
      r.hl:SetAllPoints(r)
      r.hl:SetTexture(1, 1, 1, .09)
      r.hl:Hide()
      r.pick = r:CreateTexture(nil, "BACKGROUND")
      r.pick:SetAllPoints(r)
      r.pick:Hide()
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetWidth(18)
      r.icon:SetHeight(18)
      r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
      r.icon:SetTexCoord(.07, .93, .07, .93)
      r.cell = {}
      for i, c in ipairs(cols) do
        local t = Text(r, 12, c[3])
        -- (the first column: the icon, the name, and - when it has a 5th field - the stack's size in a
        -- column of its own at its right end; user, 16 Nov 2026: "x17 x2 looks awful")
        local stack = (i == 1 and c[5]) and 46 or 0
        t:SetPoint("LEFT", r, "LEFT", c.x - 2 + (i == 1 and 24 or 0), 0)
        t:SetWidth(c[2] - (i == 1 and 24 or 0) - stack)
        t:SetHeight(20)
        r.cell[i] = t
        if stack > 0 then
          r.stack = Text(r, 12, "RIGHT")
          r.stack:SetPoint("RIGHT", r, "LEFT", c.x - 2 + c[2], 0)
          r.stack:SetWidth(stack - 4)
          r.stack:SetHeight(20)
        end
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
    l:SetHeight(28 + shown * 20)
    l.rule = l:CreateTexture(nil, "ARTWORK")
    l.rule:SetHeight(1)
    l.rule:SetPoint("TOPLEFT", l, "TOPLEFT", 4, -21)
    l.rule:SetPoint("TOPRIGHT", l, "TOPRIGHT", -4, -21)
    do local ar, ag, ab = Accent() l.rule:SetTexture(ar, ag, ab, .55) end
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
    -- (the stack's size has its own column where the list has one; a single item shows a faint 1)
    local tail = ""
    if r.stack then
      r.stack:SetText((count and count > 1) and tostring(count) or "|cff5a5a601|r")
      r.stack:SetTextColor(1, 1, 1)
    elseif count and count > 1 then
      tail = "  |cffffffffx" .. count .. "|r"
    end
    r.cell[1]:SetText(d.name .. tail)
    if d.color then r.cell[1]:SetText("|c" .. d.color .. d.name .. "|r" .. tail)
    elseif type(cr) == "number" then r.cell[1]:SetTextColor(cr, cg, cb) else r.cell[1]:SetTextColor(1, 1, 1) end
  end

  -- ---------------------------------------------------------------- the window

  local f = CreateFrame("Frame", "pfAuction", UIParent)
  UI.frame = f
  f:SetWidth(1040)
  f:SetHeight(610)
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
  f.title:SetText("Auctions")
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

  UI.TABS = { { "browse", "Browse" }, { "shop", "Shopping" }, { "deals", "Deals" }, { "sell", "Sell" }, { "owner", "My auctions" }, { "bidder", "My bids" }, { "ledger", "Ledger" } }
  UI.pages, UI.tabBtn = {}, {}
  local tx = 112
  for _, t in ipairs(UI.TABS) do
    local key = t[1]
    local b = Btn(f.bar, t[2], 80, function() UI.Open(key) end)
    b:SetPoint("LEFT", f.bar, "LEFT", tx, 0)
    tx = tx + 83
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
    local text = B.name:GetText()
    -- (the box may hold several searches and words: "linen cloth/exact; silk cloth/max 2s" - AH.ParseQuery;
    -- the buttons and boxes beside it apply to each of them)
    local list = AH.ParseQuery(text, { minLevel = tonumber(B.min:GetText()), maxLevel = tonumber(B.max:GetText()), quality = UI.q.quality,
      class = UI.q.class, subclass = UI.q.subclass, slot = UI.q.slot, usable = UI.q.usable or nil, exact = UI.q.exact or nil, first = first,
      maxUnit = AH.ParseMoney(B.maxp:GetText()) })
    UI.Recent(text)
    UI.only = nil
    local q = table.remove(list, 1)
    AH.Search(q, function(s) UI.Status() end, function(why) UI.Status(why) end, list)
    UI.Status()
  end
  UI.Search = Search
  B.name = Edit(B, 190, function() UI.EnterName() end, "Item name (Enter = search)")
  B.name:SetPoint("TOPLEFT", B, "TOPLEFT", 0, 0)
  -- Names offered under a box while you type (AH.Complete): click one, or Tab / the arrow keys to
  -- walk the list and Enter to take it; Enter with none picked does the box's own thing. One maker
  -- for every box that takes an item's name (16 Nov 2026, user of the Shopping tab's Add box: "this
  -- should work the same as the search option"). o.part(text) -> head, name, tail when only a part
  -- of the box is the name; o.take(name) = what picking one does; o.enter() = Enter with none picked.
  local SUG = 10
  UI.suggesters = {}
  local function Suggester(e, o)
    local sg = { list = {}, box = e }
    local fr = CreateFrame("Frame", nil, f)
    sg.frame = fr
    fr:SetFrameStrata("DIALOG")
    fr:SetWidth(o.width or 280)
    fr:SetPoint("TOPLEFT", e, "BOTTOMLEFT", 0, -2)
    Flat(fr, 1, .4)
    -- (a solid fill of its own: the list behind showed through the backdrop - seen in game)
    fr.fill = fr:CreateTexture(nil, "BACKGROUND")
    fr.fill:SetPoint("TOPLEFT", fr, "TOPLEFT", 1, -1)
    fr.fill:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -1, 1)
    fr.fill:SetTexture(.05, .05, .07, 1)
    fr:EnableMouse(true)
    fr:Hide()
    fr.rows = {}
    function sg.Paint()
      local ar, ag, ab = Accent()
      for i = 1, SUG do
        local r, name = fr.rows[i], sg.list[i]
        if name then
          r.text:SetText(name)
          if sg.sel == i then r.hl:SetTexture(ar, ag, ab, .4) r.hl:Show() else r.hl:Hide() end
          r:Show()
        else
          r:Hide()
        end
      end
      fr:SetHeight(table.getn(sg.list) * 18 + 6)
      if table.getn(sg.list) > 0 then fr:Show() else fr:Hide() end
    end
    function sg.Hide()
      sg.list, sg.sel = {}, nil
      fr:Hide()
    end
    function sg.Name()
      local text = e:GetText() or ""
      if o.part then
        local _, name = o.part(text)
        text = name
      end
      return (string.gsub(text, "^%s+", ""))
    end
    function sg.Update()
      if sg.quiet or S().suggest == "0" then return end
      local name = sg.Name()
      local list = AH.Complete(name, SUG)
      -- (the one name already typed in full is not offered again)
      if table.getn(list) == 1 and string.lower(list[1]) == string.lower(name) then list = {} end
      sg.list, sg.sel = list, nil
      sg.Paint()
    end
    function sg.Take(i)
      local name = sg.list[i]
      if not name then return false end
      sg.quiet = true
      if o.part then
        local head, _, tail = o.part(e:GetText() or "")
        e:SetText(head .. (head ~= "" and " " or "") .. name .. tail)
      else
        e:SetText(name)
      end
      sg.quiet = nil
      sg.Hide()
      if o.take then o.take(name) end
      return true
    end
    function sg.Step(by)
      local n = table.getn(sg.list)
      if n == 0 then return end
      local at = (sg.sel or (by > 0 and 0 or n + 1)) + by
      if at < 1 then at = n elseif at > n then at = 1 end
      sg.sel = at
      sg.Paint()
    end
    function sg.Enter()
      if sg.sel and sg.Take(sg.sel) then return end
      sg.Hide()
      if o.enter then o.enter() end
    end
    for ii = 1, SUG do
      local i = ii
      local r = CreateFrame("Button", nil, fr)
      r:SetHeight(18)
      r:SetPoint("TOPLEFT", fr, "TOPLEFT", 2, -3 - (i - 1) * 18)
      r:SetPoint("RIGHT", fr, "RIGHT", -2, 0)
      r.hl = r:CreateTexture(nil, "ARTWORK")
      r.hl:SetAllPoints(r)
      r.hl:Hide()
      r.text = Text(r, 12)
      r.text:SetPoint("LEFT", r, "LEFT", 8, 0)
      r:SetScript("OnEnter", function() sg.sel = i sg.Paint() end)
      r:SetScript("OnClick", function() sg.Take(i) end)
      fr.rows[i] = r
    end
    e.changed = function() sg.Update() end
    e:SetScript("OnEnterPressed", function() sg.Enter() end)
    e:SetScript("OnTabPressed", function() sg.Step(IsShiftKeyDown() and -1 or 1) end)
    -- (arrow keys where the client has the script; Tab / Shift + Tab everywhere)
    pcall(e.SetScript, e, "OnArrowPressed", function()
      if arg1 == "UP" then sg.Step(-1) elseif arg1 == "DOWN" then sg.Step(1) end
    end)
    e:SetScript("OnEscapePressed", function()
      if fr:IsShown() then sg.Hide() else this:ClearFocus() end
    end)
    -- (the list goes a moment after the box loses focus: a click on one of its rows comes first)
    e:SetScript("OnEditFocusLost", function() sg.hideAt = GetTime() + .25 end)
    table.insert(UI.suggesters, sg)
    return sg
  end
  UI.Suggester = Suggester
  -- the part of the Browse box a name is being typed in: after the last ";" and before its first "/"
  function UI.NamePart(text)
    local head, part = "", text or ""
    local _, _, h, p = string.find(part, "^(.*;)(.*)$")
    if h then head, part = h, p end
    local _, _, name, tail = string.find(part, "^(.-)(/.*)$")
    if not name then name, tail = part, "" end
    return head, name, tail
  end
  B.sg = Suggester(B.name, { part = UI.NamePart, take = function() B.name:ClearFocus() Search() end,
    enter = function() B.name:ClearFocus() Search() end })
  B.sug = B.sg.frame
  function UI.EnterName() B.sg.Enter() end
  B.min = Edit(B, 34, function() Search() end, "lvl")
  B.min:SetPoint("LEFT", B.name, "RIGHT", 6, 0)
  B.max = Edit(B, 34, function() Search() end, "to")
  B.max:SetPoint("LEFT", B.min, "RIGHT", 4, 0)
  B.maxp = Edit(B, 86, function() Search() end, "max each")
  B.maxp:SetPoint("LEFT", B.max, "RIGHT", 6, 0)
  -- rarity: a drop-down in the rarities' own colours (16 Nov 2026, user: "the uncommon should be a drop down
  -- and coloured like the rarity"); the game's search takes "this rarity and better"
  function UI.QualityText(q)
    if q == nil then return "Any rarity" end
    local name = rawget(_G, "ITEM_QUALITY" .. q .. "_DESC") or ({ "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" })[q + 1] or "?"
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    local hex = c and c.hex or ({ "|cff9d9d9d", "|cffffffff", "|cff1eff00", "|cff0070dd", "|cffa335ee", "|cffff8000" })[q + 1] or ""
    return hex .. name .. (q > 0 and " +" or "") .. "|r"
  end
  B.quality = Btn(B, UI.QualityText(nil) .. "  |cff808088v|r", 112, function(b)
    local W = pfUI.octoui and pfUI.octoui.W
    if not W or not W.Menu then return end
    local opts = { { key = -1, label = UI.QualityText(nil) } }
    for q = 0, 5 do table.insert(opts, { key = q, label = UI.QualityText(q) }) end
    if W.CloseMenus then W.CloseMenus() end
    local m = W.Menu(b, opts, 140, function(key)
      UI.q.quality = (key ~= -1) and key or nil
      b.text:SetText(UI.QualityText(UI.q.quality) .. "  |cff808088v|r")
      if S().treesearch ~= "0" and AH.open then Search() end
    end)
    if m and m.Show then m:Show() end
  end, "Only this rarity and better.")
  B.quality:SetPoint("LEFT", B.maxp, "RIGHT", 6, 0)
  B.class = Btn(B, "Categories", 100, function(b)
    S().tree = (S().tree == "0") and "1" or "0"
    UI.PlaceTree()
  end, "Show or hide the list of categories on the left, as on the game's own auction window.")
  B.class:SetPoint("LEFT", B.quality, "RIGHT", 6, 0)
  B.usable = Btn(B, "Usable", 62, function(b) UI.q.usable = not UI.q.usable b.Lit(UI.q.usable) end, "Only what this character can use.")
  B.usable:SetPoint("LEFT", B.class, "RIGHT", 6, 0)
  B.exact = Btn(B, "Exact", 54, function(b) UI.q.exact = not UI.q.exact b.Lit(UI.q.exact) end, "Only the item with exactly this name.")
  B.exact:SetPoint("LEFT", B.usable, "RIGHT", 6, 0)
  B.go = Role(Btn(B, "Search", 66, function() if AH.Searching() then AH.Stop() else Search() end end, "Every page of the search. Click again to stop."), "go")
  B.go:SetPoint("LEFT", B.exact, "RIGHT", 6, 0)
  B.list = NewList(B, { { "Item", 300, "LEFT", "name", "count" }, { "Lvl", 30, "RIGHT", "level" }, { "Time left", 86, "LEFT", "left" },
    { "Seller", 96, "LEFT", "owner" }, { "Bid each", 100, "RIGHT", "bidunit" }, { "Buyout each", 104, "RIGHT", "unit" },
    { "Of usual", 60, "RIGHT" } }, 22, function(r, d)
    ItemCell(r, d, d.count)
    -- (a level above yours in red, as the game marks what you cannot use yet)
    local mine = UnitLevel and UnitLevel("player") or 60
    r.cell[2]:SetText(d.level > 0 and ((d.level > mine and "|cffff5a4a" or "") .. d.level .. (d.level > mine and "|r" or "")) or "")
    r.cell[3]:SetText(UI.Left(d.left))
    r.cell[4]:SetText(UI.Seller(d.owner))
    r.cell[5]:SetText(AH.Money(d.bidunit) .. (d.high and " |cff40e060*|r" or ""))
    r.cell[6]:SetText(d.unit and AH.Money(d.unit) or "|cff808080-|r")
    r.cell[7]:SetText(PctCell(d))
    for i = 2, 4 do r.cell[i]:SetTextColor(.8, .8, .84) end
  end, function(d, button)
    UI.PaintBuy()
    -- (right-click = its price as a line for chat; Alt + click = buy it out at once; Ctrl + click = bid)
    if button == "RightButton" then UI.PriceLine(d)
    elseif IsAltKeyDown() then UI.Buy("buyout") elseif IsControlKeyDown() then UI.Buy("bid") end
  end)
  -- "[item]: usual 1s each (6 days), cheapest now 98c": into the chat box when it is open, else to you
  function UI.PriceLine(d)
    if not AH.ledger or not d then return end
    local line = AH.ledger.PriceLine(d.link, d.key, d.name)
    if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then ChatFrameEditBox:Insert(line)
    else DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r auctions: " .. line) end
  end
  B.list.sortBy = "unit"

  -- Categories on the left, the game's own way to browse (16 Nov 2026, user: "a menu like this so people can
  -- browse the oldschool way"): kinds (gold), their sorts, armour's slots. Picking one searches at once
  -- (C.auction.treesearch) with what else is set; picking it again folds it.
  local TREE_W, TREE_ROWS = 178, 23
  UI.cat = {}
  local T = CreateFrame("Frame", nil, B)
  B.tree = T
  T:SetWidth(TREE_W)
  T:SetPoint("TOPLEFT", B, "TOPLEFT", 0, -28)
  Flat(T, .6)
  T.offset, T.rows = 0, {}
  T.head = Text(T, 11)
  T.head:SetPoint("TOPLEFT", T, "TOPLEFT", 8, -5)
  T.head:SetTextColor(Accent())
  T.head:SetText("Categories")
  T.rule = T:CreateTexture(nil, "ARTWORK")
  T.rule:SetHeight(1)
  T.rule:SetPoint("TOPLEFT", T, "TOPLEFT", 4, -21)
  T.rule:SetPoint("TOPRIGHT", T, "TOPRIGHT", -4, -21)
  do local ar, ag, ab = Accent() T.rule:SetTexture(ar, ag, ab, .55) end
  -- strings only: 1.12 gives inventory types one by one, later clients in pairs (name, shown)
  local function Strings(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24)
    local out = {}
    for _, v in ipairs({ a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24 }) do
      if type(v) == "string" then table.insert(out, v) end
    end
    return out
  end
  -- the lines shown now: { text, kind = class | sub | slot, class, sub, slot }
  function UI.TreeLines()
    local lines = {}
    if not GetAuctionItemClasses then return lines end
    local c = UI.cat
    for ci, cname in ipairs(Strings(GetAuctionItemClasses())) do
      table.insert(lines, { text = cname, kind = "class", class = ci })
      if c.class == ci and GetAuctionItemSubClasses then
        for si, sname in ipairs(Strings(GetAuctionItemSubClasses(ci))) do
          table.insert(lines, { text = sname, kind = "sub", class = ci, sub = si })
          if c.sub == si and GetAuctionInvTypes then
            for ti, tkey in ipairs(Strings(GetAuctionInvTypes(ci, si))) do
              table.insert(lines, { text = rawget(_G, tkey) or tkey, kind = "slot", class = ci, sub = si, slot = ti })
            end
          end
        end
      end
    end
    return lines
  end
  function UI.PickCategory(d)
    local c = UI.cat
    if d.kind == "class" then
      if c.class == d.class and not c.sub then UI.cat = {} else UI.cat = { class = d.class } end
    elseif d.kind == "sub" then
      if c.sub == d.sub and not c.slot then UI.cat = { class = d.class } else UI.cat = { class = d.class, sub = d.sub } end
    else
      if c.slot == d.slot then UI.cat = { class = d.class, sub = d.sub } else UI.cat = { class = d.class, sub = d.sub, slot = d.slot } end
    end
    UI.q.class, UI.q.subclass, UI.q.slot = UI.cat.class, UI.cat.sub, UI.cat.slot
    UI.PaintTree()
    if S().treesearch ~= "0" and AH.open then Search() end
  end
  for ii = 1, TREE_ROWS do
    local i = ii
    local r = CreateFrame("Button", nil, T)
    r:SetHeight(20)
    r:SetPoint("TOPLEFT", T, "TOPLEFT", 2, -24 - (i - 1) * 20)
    r:SetPoint("RIGHT", T, "RIGHT", -2, 0)
    r.pick = r:CreateTexture(nil, "BACKGROUND")
    r.pick:SetAllPoints(r)
    r.pick:Hide()
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetWidth(2)
    r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    r.bar:Hide()
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints(r)
    r.hl:SetTexture(1, 1, 1, .08)
    r.hl:Hide()
    r.mark = Text(r, 11)
    r.mark:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.text = Text(r, 12)
    r:SetScript("OnEnter", function() this.hl:Show() end)
    r:SetScript("OnLeave", function() this.hl:Hide() end)
    r:SetScript("OnClick", function() if this.d then UI.PickCategory(this.d) end end)
    T.rows[i] = r
  end
  T:EnableMouseWheel(true)
  T:SetScript("OnMouseWheel", function()
    local n = table.getn(UI.TreeLines())
    T.offset = math.max(0, math.min(math.max(0, n - TREE_ROWS), T.offset - (arg1 or 0) * 3))
    UI.PaintTree()
  end)
  function UI.PaintTree()
    local lines = UI.TreeLines()
    local n = table.getn(lines)
    if T.offset > math.max(0, n - TREE_ROWS) then T.offset = math.max(0, n - TREE_ROWS) end
    local ar, ag, ab = Accent()
    local c = UI.cat
    for i = 1, TREE_ROWS do
      local r, d = T.rows[i], lines[i + T.offset]
      r.d = d
      if d then
        local picked = (d.kind == "class" and c.class == d.class and not c.sub) or (d.kind == "sub" and c.sub == d.sub and c.class == d.class and not c.slot)
          or (d.kind == "slot" and c.slot == d.slot and c.sub == d.sub and c.class == d.class)
        local open = (d.kind == "class" and c.class == d.class) or (d.kind == "sub" and c.sub == d.sub and c.class == d.class)
        r.text:ClearAllPoints()
        r.text:SetPoint("LEFT", r, "LEFT", (d.kind == "class" and 8) or (d.kind == "sub" and 20) or 32, 0)
        r.text:SetText(d.text)
        if d.kind == "class" then r.text:SetTextColor(1, .82, .1) elseif d.kind == "sub" then r.text:SetTextColor(.95, .95, .97)
        else r.text:SetTextColor(.7, .7, .75) end
        local hasMore = d.kind == "class" or (d.kind == "sub" and d.class == 2)
        r.mark:SetText(hasMore and (open and "|cff808088-|r" or "|cff808088+|r") or "")
        if picked then
          r.pick:SetTexture(ar, ag, ab, .22) r.pick:Show()
          r.bar:SetTexture(ar, ag, ab, 1) r.bar:Show()
        else
          r.pick:Hide() r.bar:Hide()
        end
        r:Show()
      else
        r:Hide()
      end
    end
  end
  -- the list beside the categories, or the whole width when they are hidden
  function UI.PlaceTree()
    B.list:ClearAllPoints()
    if S().tree ~= "0" then
      T:Show()
      B.list:SetPoint("TOPLEFT", B, "TOPLEFT", TREE_W + 8, -28)
      UI.PaintTree()
    else
      T:Hide()
      B.list:SetPoint("TOPLEFT", B, "TOPLEFT", 0, -28)
    end
    B.list:SetPoint("RIGHT", B, "RIGHT", 0, 0)
    if B.class.Lit then B.class.Lit(S().tree ~= "0") end
  end
  UI.PlaceTree()
  T:SetPoint("BOTTOM", B.list, "BOTTOM", 0, 0)
  B.status = Text(B, 11)
  B.status:SetPoint("TOPLEFT", B.list, "BOTTOMLEFT", 4, -8)
  B.status:SetTextColor(.62, .62, .67)
  B.buy = Role(Btn(B, "Buyout", 190, function() UI.Buy("buyout") end, "Buy the picked auction out. Alt + click a row does it in one go."), "buy")
  B.buy:SetPoint("TOPRIGHT", B.list, "BOTTOMRIGHT", 0, -4)
  B.bid = Btn(B, "Bid", 190, function() UI.Buy("bid") end, "Bid on the picked auction. Ctrl + click a row does it in one go.")
  B.bid:SetPoint("RIGHT", B.buy, "LEFT", -6, 0)
  B.allAt = B.bid
  function UI.Status(why)
    local s = AH.scan
    local n = table.getn(AH.rows)
    if s then
      local more = s.queue and table.getn(s.queue) or 0
      B.status:SetText((s.q.silent and "Reading every auction: page " or "Searching: page ") .. (s.page + 1) .. (s.pages > 0 and (" of " .. s.pages) or "")
        .. (s.q.silent and ("   " .. (s.seen or 0) .. " read") or ("   " .. n .. " found so far"))
        .. (more > 0 and ("   " .. more .. " more to search") or ""))
      B.go.text:SetText("Stop")
    else
      B.status:SetText((why and why ~= "done") and (n .. " found (" .. why .. ")") or (n .. " found" .. (AH.total > 0 and (" in " .. AH.total .. " auctions") or "")))
      B.go.text:SetText("Search")
    end
  end
  function UI.PaintBuy()
    local d = UI.List().sel
    local kind = UI.pages[UI.tab] or B
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
  -- saved and recent searches in one menu ("s:" / "r:" + the text; the two actions on top)
  function UI.SearchMenu()
    local st = AH.Store()
    st.saved = st.saved or {}
    local opts = {}
    local text = B.name:GetText()
    if text ~= "" then table.insert(opts, { key = "!save", label = "|cff40e060Save:|r " .. text }) end
    if table.getn(st.saved) > 0 then
      table.insert(opts, { key = "!forget", label = "|cffff7060Remove a saved search...|r" })
      for _, n in ipairs(st.saved) do table.insert(opts, { key = "s:" .. n, label = "|cffffd24d*|r " .. n }) end
    end
    for _, n in ipairs(st.recent or {}) do table.insert(opts, { key = "r:" .. n, label = n }) end
    if text ~= "" then
      for i, l in ipairs(AH.Lists()) do table.insert(opts, { key = "l:" .. i, label = "|cff6fb3ffAdd to list:|r " .. l.name }) end
    end
    return opts
  end
  function UI.SearchPick(key)
    local st = AH.Store()
    st.saved = st.saved or {}
    if key == "!save" then
      local text = B.name:GetText()
      for _, n in ipairs(st.saved) do if n == text then return end end
      table.insert(st.saved, text)
      UI.Note("Saved: " .. text)
    elseif key == "!forget" then
      UI.forgetNext = true
      UI.Note("Pick the saved search to remove from the menu.")
      B.recent.fn(B.recent)
    else
      if string.sub(key, 1, 2) == "l:" then
        local i = tonumber(string.sub(key, 3))
        local l = AH.Lists()[i or 0]
        if l and AH.ListAdd(i, B.name:GetText()) then UI.Note("Added to \"" .. l.name .. "\".") end
        return
      end
      local text = string.sub(key, 3)
      if UI.forgetNext and string.sub(key, 1, 2) == "s:" then
        for i, n in ipairs(st.saved) do if n == text then table.remove(st.saved, i) break end end
        UI.Note("Removed: " .. text)
      else
        B.name:SetText(text)
        Search()
      end
      UI.forgetNext = nil
    end
  end
  B.recent = Btn(B, "Saved", 60, function(b)
    local W = pfUI.octoui and pfUI.octoui.W
    local opts = UI.SearchMenu()
    if not W or not W.Menu or table.getn(opts) == 0 then return end
    if W.CloseMenus then W.CloseMenus() end
    local m = W.Menu(b, opts, 260, UI.SearchPick)
    if m and m.Show then m:Show() end
  end, "Your saved and last searches; save the one in the box. A search can be several at once, with words: "
    .. "linen cloth/exact; silk cloth/max 2s; /rare/40-50/weapon")
  B.recent:SetPoint("LEFT", B.go, "RIGHT", 6, 0)
  B.all = Btn(B, "Read every auction", 150, function()
    if AH.Searching() then AH.Stop() return end
    AH.Search({ silent = true }, function() UI.Status() end, function(why, s)
      UI.Status(why)
      UI.Note("Read " .. ((s and s.seen) or 0) .. " auctions: " .. AH.Known() .. " items have a price now.")
    end)
    UI.Status()
  end, "Goes through the whole auction house once to note what everything sells for (nothing is listed). "
    .. "Fast with the AuctionQueryThrottle DLL; a page every 5 seconds without it.")
  UI.lists.browse = B.list
  B.all:SetPoint("RIGHT", B.allAt, "LEFT", -6, 0)

  -- ---------------------------------------------------------------- Sell

  local P = UI.pages.sell
  P.items = NewList(P, { { "In your bags", 250, "LEFT", "name", "total" } }, 24, function(r, d)
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
  P.post = Role(Btn(P.box, "Post", 160, function() UI.Post() end), "go")
  P.post:SetPoint("TOPLEFT", P.box, "TOPLEFT", 4, -236)
  P.rivals = NewList(P.box, { { "On the auction house now", 250, "LEFT", "name", "count" }, { "Seller", 110, "LEFT", "owner" }, { "Time left", 86, "LEFT", "left" },
    { "Buyout each", 110, "RIGHT", "unit" } }, 10, function(r, d)
    ItemCell(r, d, d.count)
    r.cell[2]:SetText(UI.Seller(d.owner))
    r.cell[3]:SetText(UI.Left(d.left))
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
    if P.chart then P.chart.Set(d.key) end
    local n, why = UI.SellNumbers()
    if AH.job then
      P.sum:SetText("|cffffd24dPosting: " .. AH.job.posted .. " up, " .. AH.job.left .. " to go...|r")
      P.post.text:SetText("Stop")
      P.post.Able(true)
    elseif n then
      P.sum:SetText(n.stacks .. (n.stacks == 1 and " stack of " or " stacks of ") .. n.size .. "   each stack: start " .. AH.Money(n.bid * n.size)
        .. (n.buy > 0 and ("   buyout " .. AH.Money(n.buy * n.size)) or "   no buyout")
        .. (n.buy > 0 and ("   |cff9a9aa0all sold = " .. AH.Money(n.buy * n.size * n.stacks, true) .. "|r") or "")
        .. (function()
          -- (from the vendor price: 5% per 2 hours at a faction auction house; the neutral ones and this server may differ)
          local dep = AH.Deposit(d.key, n.size * n.stacks, UI.hours)
          return dep and dep > 0 and ("   |cff9a9aa0deposit about " .. AH.Money(dep, true) .. "|r") or ""
        end)())
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
  O.list = NewList(O, { { "Item", 330, "LEFT", "name", "count" }, { "Time left", 86, "LEFT", "left" }, { "High bid", 104, "RIGHT", "bid" },
    { "Buyout", 104, "RIGHT", "buyout" }, { "Each", 96, "RIGHT", "unit" }, { "Cheapest other", 130, "RIGHT", "other" } }, 23, function(r, d)
    ItemCell(r, d, d.count)
    r.cell[2]:SetText(UI.Left(d.left))
    r.cell[3]:SetText(d.bid > 0 and AH.Money(d.bid) or "|cff808080no bid|r")
    r.cell[4]:SetText(d.buyout > 0 and AH.Money(d.buyout) or "|cff808080-|r")
    r.cell[5]:SetText(d.unit and AH.Money(d.unit) or "")
    -- (after "Check for undercuts": someone cheaper = red, you are the cheapest = green)
    if not d.other then r.cell[6]:SetText(UI.checked and "|cff40e060none|r" or "")
    elseif d.unit and d.other < d.unit then r.cell[6]:SetText("|cffff6050" .. AH.Money(d.other, true) .. "  undercut|r")
    else r.cell[6]:SetText("|cff40e060" .. AH.Money(d.other, true) .. "|r") end
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
  Role(O.cancel, "danger")
  O.sumText = Text(O, 11)
  O.sumText:SetPoint("TOPLEFT", O.list, "BOTTOMLEFT", 4, -8)
  O.sumText:SetTextColor(.62, .62, .67)
  function UI.PaintOwner() O.cancel.Able(O.list.sel ~= nil) end
  -- one exact search per different item you have up, then every row shows the cheapest other seller
  function UI.CheckUndercuts()
    if AH.Searching() then AH.Stop() return end
    local list, seen = {}, {}
    for _, r in ipairs(AH.Owned()) do
      if not seen[r.name] then
        seen[r.name] = true
        table.insert(list, { name = r.name, exact = true })
      end
    end
    if table.getn(list) == 0 then UI.Note("You have no auctions up.") return end
    local n = table.getn(list)
    local q = table.remove(list, 1)
    AH.Search(q, function(s) UI.Note("Checking prices: " .. ((s.done or 0) + 1) .. " of " .. n .. "...") end, function()
      UI.checked = true
      local cut = 0
      for _, r in ipairs(AH.Owned()) do
        local other = AH.LowestOther(r.key)
        if other and r.unit and other < r.unit then cut = cut + 1 end
      end
      UI.Note(cut == 0 and "Nobody is under your prices." or (cut .. (cut == 1 and " auction is" or " auctions are") .. " undercut (red)."))
      UI.Refresh()
    end, list)
  end
  O.check = Btn(O, "Check for undercuts", 190, function() UI.CheckUndercuts() end,
    "Searches the auction house for each item you have up and shows the cheapest other seller beside it: red where someone is under you.")
  O.check:SetPoint("RIGHT", O.cancel, "LEFT", -6, 0)
  UI.lists.owner = O.list
  local D = UI.pages.bidder
  D.list = NewList(D, { { "Item", 340, "LEFT", "name", "count" }, { "Time left", 90, "LEFT", "left" }, { "Seller", 110, "LEFT", "owner" },
    { "Bid now", 120, "RIGHT", "bid" }, { "Buyout", 120, "RIGHT", "buyout" }, { "", 60, "RIGHT" } }, 23, function(r, d)
    ItemCell(r, d, d.count)
    r.cell[2]:SetText(UI.Left(d.left))
    r.cell[3]:SetText(UI.Seller(d.owner))
    r.cell[4]:SetText(AH.Money(d.bid))
    r.cell[5]:SetText(d.buyout > 0 and AH.Money(d.buyout) or "|cff808080-|r")
    r.cell[6]:SetText(d.high and "|cff40e060yours|r" or "|cffff7060outbid|r")
    for i = 2, 3 do r.cell[i]:SetTextColor(.8, .8, .84) end
  end, function() UI.PaintBuy() end)
  D.list:SetPoint("TOPLEFT", D, "TOPLEFT", 0, 0)
  D.list:SetPoint("RIGHT", D, "RIGHT", 0, 0)
  D.buy = Role(Btn(D, "Buyout", 190, function() UI.Buy("buyout") end), "buy")
  D.buy:SetPoint("TOPRIGHT", D.list, "BOTTOMRIGHT", 0, -4)
  D.bid = Btn(D, "Bid", 190, function() UI.Buy("bid") end, "Bid again on an auction you were outbid on.")
  D.bid:SetPoint("RIGHT", D.buy, "LEFT", -6, 0)
  UI.lists.bidder = D.list

  -- ---------------------------------------------------------------- Shopping (16 Nov 2026)
  -- your lists on the left, the picked list's searches under them, and on the right what a run of
  -- the whole list found: one line an item - how many are up, the cheapest each (AH.Lists / AH.Group)

  local H = UI.pages.shop
  local function PlainCell(r, text, r1, g1, b1)
    r.icon:SetTexture(nil)
    r.cell[1]:SetText(text)
    r.cell[1]:SetTextColor(r1 or 1, g1 or 1, b1 or 1)
  end
  H.lists = NewList(H, { { "Your lists", 204, "LEFT" } }, 8, function(r, d)
    PlainCell(r, d.name .. "  |cff808088" .. table.getn(d.terms) .. "|r")
  end, function(d) UI.shop = d.i UI.shopRan = nil UI.PaintShop() end)
  H.lists:SetPoint("TOPLEFT", H, "TOPLEFT", 0, 0)
  H.lists:SetWidth(224)
  H.new = Edit(H, 224, function(e)
    local _, i = AH.ListNew(e:GetText())
    if i then UI.shop = i e:SetText("") UI.PaintShop() end
  end, "New list: its name, then Enter")
  H.new:SetPoint("TOPLEFT", H.lists, "BOTTOMLEFT", 0, -4)
  H.del = Role(Btn(H, "Delete list", 108, function()
    local lists = AH.Lists()
    local l = lists[UI.shop or 0]
    if not l then return end
    if UI.sureDel == l and GetTime() < (UI.sureAt or 0) then
      table.remove(lists, UI.shop)
      UI.shop, UI.sureDel = 1, nil
      UI.PaintShop()
    else
      UI.sureDel, UI.sureAt = l, GetTime() + 3
      UI.Note("Click Delete list again to delete \"" .. l.name .. "\".")
    end
  end, "Click twice: the picked list and its searches go."), "danger")
  H.del:SetPoint("TOPLEFT", H.new, "BOTTOMLEFT", 0, -4)
  H.exp = Btn(H, "Export", 108, function()
    local text = AH.ListExport(UI.shop or 0)
    if text == "" then return end
    local lc = pfUI.api and pfUI.api.libclient
    if lc and lc.Copy and lc.Copy(text) then UI.Note("The list is on the clipboard: paste it to a friend.") return end
    H.imp:SetText(text)
    H.imp:SetFocus()
    H.imp:HighlightText()
    UI.Note("The list is in the box at the bottom, marked: Ctrl + C copies it.")
  end, "The picked list as one line of text, to give to someone (they paste it into the box at the bottom).")
  H.exp:SetPoint("LEFT", H.del, "RIGHT", 8, 0)
  H.terms = NewList(H, { { "Searches in this list", 204, "LEFT" } }, 7, function(r, d)
    PlainCell(r, d.text)
  end, function() UI.PaintShop(true) end)
  H.terms:SetPoint("TOPLEFT", H.del, "BOTTOMLEFT", 0, -8)
  H.terms:SetWidth(224)
  H.add = Edit(H, 224, function(e)
    if AH.ListAdd(UI.shop or 0, e:GetText()) then e:SetText("") UI.PaintShop() end
  end, "Add: an item or search, then Enter")
  H.add:SetPoint("TOPLEFT", H.terms, "BOTTOMLEFT", 0, -4)
  -- (the same name list as the Browse box: a picked name goes on the list at once, as that exact item,
  -- and the box stays ready for the next one)
  H.sg = UI.Suggester(H.add, { width = 224,
    take = function(name)
      if AH.ListAdd(UI.shop or 0, name .. "/exact") then UI.Note("Added " .. name .. ".") end
      H.add:SetText("")
      UI.PaintShop()
    end,
    enter = function()
      if AH.ListAdd(UI.shop or 0, H.add:GetText()) then H.add:SetText("") UI.PaintShop() end
    end })
  H.rem = Btn(H, "Remove search", 108, function()
    local l = AH.Lists()[UI.shop or 0]
    local d = H.terms.sel
    if not l or not d then return end
    table.remove(l.terms, d.i)
    H.terms.sel = nil
    UI.PaintShop()
  end, "Takes the picked search off the list.")
  H.rem:SetPoint("TOPLEFT", H.add, "BOTTOMLEFT", 0, -4)
  H.one = Btn(H, "Search it", 108, function()
    local d = H.terms.sel
    if not d then return end
    B.name:SetText(d.text)
    UI.Open("browse")
    Search()
  end, "Runs only the picked search, on the Browse tab.")
  H.one:SetPoint("LEFT", H.rem, "RIGHT", 8, 0)
  H.imp = Edit(H, 224, function(e)
    local l, i = AH.ListImport(e:GetText())
    if l then UI.shop = i e:SetText("") UI.Note("List \"" .. l.name .. "\" added.") UI.PaintShop()
    else UI.Note("That is not a list (Name^search^search).") end
  end, "Paste a list here, then Enter")
  H.imp:SetPoint("TOPLEFT", H.rem, "BOTTOMLEFT", 0, -6)
  H.run = Role(Btn(H, "Search the whole list", 190, function()
    if AH.Searching() then AH.Stop() return end
    UI.shopRan = true
    if not AH.SearchList(UI.shop or 0, function() UI.PaintShop() end, function(why)
      UI.Note(table.getn(AH.Group()) .. " different items found" .. ((why and why ~= "done") and (" (" .. why .. ")") or "") .. ".")
      UI.PaintShop()
    end) then UI.Note("This list has no searches yet: add one on the left.") UI.shopRan = nil end
    UI.PaintShop()
  end, "Every search of the picked list, one after the other."), "go")
  H.run:SetPoint("TOPLEFT", H, "TOPLEFT", 236, 0)
  H.status = Text(H, 11)
  H.status:SetPoint("LEFT", H.run, "RIGHT", 12, 0)
  H.status:SetTextColor(.62, .62, .67)
  H.found = NewList(H, { { "Item", 310, "LEFT", "name" }, { "Up for sale", 90, "RIGHT", "count" }, { "Auctions", 70, "RIGHT", "auctions" },
    { "Cheapest each", 120, "RIGHT", "low" }, { "Of usual", 70, "RIGHT" } }, 22, function(r, d)
    ItemCell(r, d)
    r.cell[2]:SetText(d.count)
    r.cell[3]:SetText(d.auctions)
    r.cell[4]:SetText(d.low and AH.Money(d.low) or "|cff808080no buyout|r")
    local v = d.low and AH.Value(d.key)
    if v and v > 0 then
      local p = d.low / v * 100
      r.cell[5]:SetText(((p <= 80 and "|cff40e060") or (p <= 120 and "|cffffffff") or "|cffff7060") .. math.floor(p + .5) .. "%|r")
    else
      r.cell[5]:SetText("")
    end
    for i = 2, 3 do r.cell[i]:SetTextColor(.8, .8, .84) end
  end, function(d, button)
    if button == "RightButton" then UI.PriceLine(d) return end
    -- its auctions, cheapest first, on the Browse tab (they are already loaded: no new search)
    UI.only = d.key
    UI.Open("browse")
  end)
  H.found:SetPoint("TOPLEFT", H, "TOPLEFT", 236, -28)
  H.found:SetPoint("RIGHT", H, "RIGHT", 0, 0)
  H.found.sortBy = "name"
  UI.lists.shop = H.found
  function UI.PaintShop(keepTerm)
    local lists = AH.Lists()
    if not UI.shop or not lists[UI.shop] then UI.shop = lists[1] and 1 or nil end
    local rows = {}
    for i, l in ipairs(lists) do l.i = i table.insert(rows, l) end
    H.lists.Set(rows, true)
    H.lists.sel = UI.shop and lists[UI.shop] or nil
    H.lists.Paint()
    local l = UI.shop and lists[UI.shop]
    local terms = {}
    for i, t in ipairs(l and l.terms or {}) do table.insert(terms, { i = i, text = t, name = t }) end
    local was = keepTerm and H.terms.sel and H.terms.sel.i
    H.terms.Set(terms, true)
    if was then for _, t in ipairs(terms) do if t.i == was then H.terms.sel = t end end H.terms.Paint() end
    H.rem.Able(H.terms.sel ~= nil)
    H.one.Able(H.terms.sel ~= nil)
    H.del.Able(l ~= nil)
    H.exp.Able(l ~= nil and table.getn(l.terms) > 0)
    H.found.Set(UI.shopRan and AH.Group() or {}, true)
    local s = AH.scan
    if s then
      local more = s.queue and table.getn(s.queue) or 0
      H.status:SetText("Searching \"" .. tostring(s.q.name or "") .. "\": page " .. (s.page + 1) .. (s.pages > 0 and (" of " .. s.pages) or "")
        .. (more > 0 and ("   " .. more .. " more searches") or ""))
      H.run.text:SetText("Stop")
    else
      H.status:SetText(UI.shopRan and (table.getn(H.found.data) .. " different items. Click one to see its auctions.") or
        (l and ("\"" .. l.name .. "\": " .. table.getn(l.terms) .. " searches") or "Make a list on the left."))
      H.run.text:SetText("Search the whole list")
    end
  end

  -- ---------------------------------------------------------------- Deals (phase 3)
  -- auctions well under their item's usual price, the most profit first (AH.ledger.DealFilter)

  local K = UI.pages.deals
  local kl = Label(K, "Buyout under")
  kl:SetPoint("TOPLEFT", K, "TOPLEFT", 2, -5)
  K.pct = Edit(K, 44, nil, "70")
  K.pct:SetPoint("TOPLEFT", K, "TOPLEFT", 90, 0)
  local kl2 = Label(K, "% of the usual price,  profit a stack at least")
  kl2:SetPoint("LEFT", K.pct, "RIGHT", 6, 0)
  K.min = Edit(K, 90, nil, "50s")
  K.min:SetPoint("LEFT", kl2, "RIGHT", 6, 0)
  local kl3 = Label(K, "price known for")
  kl3:SetPoint("LEFT", K.min, "RIGHT", 10, 0)
  K.days = Edit(K, 34, nil, "3")
  K.days:SetPoint("LEFT", kl3, "RIGHT", 6, 0)
  local kl4 = Label(K, "days")
  kl4:SetPoint("LEFT", K.days, "RIGHT", 6, 0)
  K.go = Btn(K, "Find deals", 110, function()
    if AH.Searching() then AH.Stop() return end
    if not AH.ledger then return end
    local pct = tonumber(K.pct:GetText()) or tonumber(S().dealpct) or 70
    local min = AH.ParseMoney(K.min:GetText()) or 5000
    local days = tonumber(K.days:GetText()) or 3
    S().dealpct = tostring(pct)
    UI.dealScan = true
    AH.ledger.FindDeals(pct, min, days, function() UI.PaintDeals() end, function(why)
      UI.dealScan = nil
      UI.Note(table.getn(AH.rows) .. " deals found" .. ((why and why ~= "done") and (" (" .. why .. ")") or "") .. ".")
      UI.PaintDeals()
    end)
    UI.PaintDeals()
  end, "Goes through the whole auction house and lists what is up for well under its usual price. "
    .. "Only items whose price has been seen on several days count, so run \"Read every auction\" on a few days first.")
  K.go:SetPoint("LEFT", kl4, "RIGHT", 12, 0)
  Role(K.go, "go")
  K.list = NewList(K, { { "Item", 330, "LEFT", "name", "count" }, { "Seller", 100, "LEFT", "owner" }, { "Time left", 86, "LEFT", "left" },
    { "Buyout each", 100, "RIGHT", "unit" }, { "Usual", 100, "RIGHT", "value" }, { "Of usual", 62, "RIGHT", "share" },
    { "Profit a stack", 120, "RIGHT", "profit" } }, 22, function(r, d)
    ItemCell(r, d, d.count)
    r.cell[2]:SetText(UI.Seller(d.owner))
    r.cell[3]:SetText(UI.Left(d.left))
    r.cell[4]:SetText(d.unit and AH.Money(d.unit) or "")
    r.cell[5]:SetText(d.value and AH.Money(d.value) or "")
    r.cell[6]:SetText(d.share and ("|cff40e060" .. math.floor(d.share * 100 + .5) .. "%|r") or "")
    r.cell[7]:SetText(d.profit and ("|cff40e060+|r" .. AH.Money(d.profit)) or "")
    for i = 2, 3 do r.cell[i]:SetTextColor(.8, .8, .84) end
  end, function(d, button)
    UI.PaintBuy()
    if button == "RightButton" then UI.PriceLine(d) elseif IsAltKeyDown() then UI.Buy("buyout") end
  end)
  K.list:SetPoint("TOPLEFT", K, "TOPLEFT", 0, -28)
  K.list:SetPoint("RIGHT", K, "RIGHT", 0, 0)
  K.list.sortBy, K.list.desc = "profit", true
  K.status = Text(K, 11)
  K.status:SetPoint("TOPLEFT", K.list, "BOTTOMLEFT", 4, -8)
  K.status:SetTextColor(.62, .62, .67)
  K.buy = Role(Btn(K, "Buyout", 190, function() UI.Buy("buyout") end, "Buy the picked auction out. Alt + click a row does it in one go."), "buy")
  K.buy:SetPoint("TOPRIGHT", K.list, "BOTTOMRIGHT", 0, -4)
  K.bid = Btn(K, "Bid", 190, function() UI.Buy("bid") end)
  K.bid:SetPoint("RIGHT", K.buy, "LEFT", -6, 0)
  UI.lists.deals = K.list
  function UI.PaintDeals()
    local rows = {}
    for _, r in ipairs(AH.rows) do if r.profit then table.insert(rows, r) end end
    K.list.Set(rows, true)
    local s = AH.scan
    if s then
      K.status:SetText("Looking: page " .. (s.page + 1) .. (s.pages > 0 and (" of " .. s.pages) or "") .. "   " .. table.getn(rows) .. " deals so far")
      K.go.text:SetText("Stop")
    else
      K.status:SetText(table.getn(rows) .. " deals   (prices known for " .. AH.Known() .. " items)")
      K.go.text:SetText("Find deals")
    end
    UI.PaintBuy()
  end

  -- ---------------------------------------------------------------- Ledger (phase 3)
  -- what sold, what you bought, what came back - as it happens (AH.ledger)

  local G = UI.pages.ledger
  G.worth = Text(G, 13)
  G.worth:SetPoint("TOPLEFT", G, "TOPLEFT", 2, -2)
  G.sums = Text(G, 12)
  G.sums:SetPoint("TOPLEFT", G, "TOPLEFT", 2, -24)
  G.sums:SetWidth(900)
  UI.ledgerShow = "all"
  G.filters = {}
  local fx = 0
  for _, t in ipairs({ { "all", "Everything" }, { "sold", "Sold" }, { "bought", "Bought" }, { "other", "Expired, outbid, posted" } }) do
    local key = t[1]
    local b = Btn(G, t[2], key == "other" and 170 or 90, function() UI.ledgerShow = key UI.PaintLedger() end)
    b:SetPoint("TOPLEFT", G, "TOPLEFT", fx, -46)
    fx = fx + (key == "other" and 174 or 94)
    G.filters[key] = b
  end
  G.list = NewList(G, { { "When", 110, "LEFT", "t" }, { "What", 80, "LEFT", "k" }, { "Item", 330, "LEFT", "n" }, { "Count", 50, "RIGHT", "c" },
    { "Gold", 150, "RIGHT", "a" }, { "With", 110, "LEFT", "who" } }, 20, function(r, d)
    r.icon:SetTexture(nil)
    r.cell[1]:SetText(date and date("%d %b %H:%M", d.t) or "")
    local L = AH.ledger
    r.cell[2]:SetText((L and L.KINDS[d.k]) or d.k)
    r.cell[3]:SetText(d.n or "")
    r.cell[4]:SetText((d.c and d.c > 1) and ("x" .. d.c) or "")
    if d.a > 0 then r.cell[5]:SetText("|cff40e060+|r" .. AH.Money(d.a) .. (d.est and " |cff9a9aa0about|r" or ""))
    elseif d.a < 0 then r.cell[5]:SetText("|cffff7060-|r" .. AH.Money(-d.a) .. (d.est and " |cff9a9aa0about|r" or ""))
    else r.cell[5]:SetText("") end
    r.cell[6]:SetText(d.who or "")
    r.cell[1]:SetTextColor(.62, .62, .67)
    if d.k == "sold" then r.cell[2]:SetTextColor(.3, .9, .4) elseif d.k == "bought" or d.k == "won" then r.cell[2]:SetTextColor(1, .5, .4)
    else r.cell[2]:SetTextColor(.7, .7, .75) end
    r.cell[3]:SetTextColor(1, 1, 1)
    r.cell[6]:SetTextColor(.8, .8, .84)
  end)
  G.list:SetPoint("TOPLEFT", G, "TOPLEFT", 0, -74)
  G.list:SetPoint("RIGHT", G, "RIGHT", 0, 0)
  G.list.sortBy, G.list.desc = "t", true
  UI.lists.ledger = G.list
  function UI.PaintLedger()
    local L = AH.ledger
    if not L then G.worth:SetText("The ledger is switched off.") return end
    local w = L.Worth()
    G.worth:SetText("Worth now:  " .. AH.Money(w.total) .. "   |cff9a9aa0=  gold|r " .. AH.Money(w.gold) .. "  |cff9a9aa0+ bags|r " .. AH.Money(w.bags)
      .. "  |cff9a9aa0+ on the auction house|r " .. AH.Money(w.up))
    local function Line(label, s)
      return "|cff9a9aa0" .. label .. ":|r  sold " .. AH.Money(s.sold) .. " (" .. s.sales .. ")   spent " .. AH.Money(s.spent) .. " (" .. s.buys .. ")   "
        .. (s.net >= 0 and "|cff40e060+|r" or "|cffff7060-|r") .. AH.Money(math.abs(s.net))
    end
    G.sums:SetText(Line("Today", L.Sum(86400)) .. "      " .. Line("7 days", L.Sum(7 * 86400)))
    local rows = {}
    for _, e in ipairs(L.Entries()) do
      local kind = (e.k == "sold" and "sold") or ((e.k == "bought" or e.k == "won") and "bought") or "other"
      if UI.ledgerShow == "all" or UI.ledgerShow == kind then table.insert(rows, e) end
    end
    G.list.Set(rows, true)
    for key, b in pairs(G.filters) do b.Lit(key == UI.ledgerShow) end
  end

  -- a small chart of an item's daily lows (oldest left, today right, the usual price as a line)
  function UI.NewChart(parent, w, h)
    local c = CreateFrame("Frame", nil, parent)
    c:SetWidth(w)
    c:SetHeight(h)
    Flat(c, .5)
    c.bars = {}
    for i = 1, 11 do
      c.bars[i] = c:CreateTexture(nil, "ARTWORK")
      c.bars[i]:SetTexture(WHITE)
    end
    c.line = c:CreateTexture(nil, "OVERLAY")
    c.line:SetTexture(1, .82, .2, .9)
    c.line:SetHeight(1)
    c.text = Text(c, 10)
    c.text:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -3)
    c.text:SetTextColor(.62, .62, .67)
    function c.Set(key)
      local r = key and AH.Store().h[key]
      local list = {}
      if r then
        for _, v in ipairs(r.days) do table.insert(list, v) end
        table.insert(list, r.min)
      end
      local n = table.getn(list)
      local top = 0
      for _, v in ipairs(list) do if v > top then top = v end end
      local value = AH.Value(key)
      local bw = (w - 12) / 11
      local ar, ag, ab = Accent()
      for i = 1, 11 do
        local b = c.bars[i]
        local v = list[i]
        if v and top > 0 then
          b:ClearAllPoints()
          b:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 6 + (i - 1) * bw, 4)
          b:SetWidth(math.max(2, bw - 3))
          b:SetHeight(math.max(2, (h - 22) * v / top))
          if i == n then b:SetVertexColor(1, .82, .2, 1) else b:SetVertexColor(ar, ag, ab, .9) end
          b:Show()
        else
          b:Hide()
        end
      end
      if value and top > 0 then
        c.line:ClearAllPoints()
        c.line:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 4, 4 + (h - 22) * math.min(1, value / top))
        c.line:SetWidth(w - 8)
        c.line:Show()
        c.text:SetText("Lowest each, per day seen (" .. n .. ")   top " .. AH.Money(top, true))
      else
        c.line:Hide()
        c.text:SetText(n == 0 and "No price history yet" or "")
      end
      return n
    end
    return c
  end
  P.chart = UI.NewChart(P.box, 260, 78)
  P.chart:SetPoint("TOPLEFT", P.box, "TOPLEFT", 330, -94)

  -- ---------------------------------------------------------------- showing

  function UI.Refresh(event)
    if not f:IsShown() then return end
    if UI.tab == "browse" then
      -- (from the Shopping tab: only the clicked item's auctions, until the next search)
      local rows = AH.rows
      if UI.only then
        rows = {}
        for _, r in ipairs(AH.rows) do if r.key == UI.only then table.insert(rows, r) end end
      end
      B.list.Set(rows, true)
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
        r.other = UI.checked and AH.LowestOther(r.key) or nil
      end
      O.list.Paint()
      O.sumText:SetText(table.getn(rows) .. " auctions   " .. bids .. " with a bid   all buyouts together: " .. AH.Money(total))
      UI.PaintOwner()
    elseif UI.tab == "bidder" then
      D.list.Set(AH.Bids(), true)
      UI.PaintBuy()
    elseif UI.tab == "shop" then
      UI.PaintShop(true)
    elseif UI.tab == "deals" then
      UI.PaintDeals()
    elseif UI.tab == "ledger" then
      UI.PaintLedger()
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
  -- an item of your bags onto the Sell tab (by its key); false = it cannot be auctioned
  function UI.SellKey(key)
    UI.Open("sell")
    for _, e in ipairs(UI.bagList or {}) do
      if e.key == key then
        P.items.sel = e
        UI.PickSell(e)
        P.items.Paint()
        return true
      end
    end
    UI.Note("That cannot be auctioned (soulbound).")
    return false
  end
  -- right-click an item in your bags while the window is up: it goes to the Sell tab instead of being used
  local use = _G.UseContainerItem
  if type(use) == "function" and not UI.useWrapped then
    UI.useWrapped = true
    _G.UseContainerItem = function(bag, slot, onSelf)
      if AH.open and f:IsShown() and S().bagclick ~= "0" then
        local key = AH.ItemKey(GetContainerItemLink(bag, slot))
        if key then UI.SellKey(key) return end
      end
      return use(bag, slot, onSelf)
    end
  end
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
    -- (the name list goes a moment after the box loses focus: a click on one of its rows comes first)
    for _, sg in ipairs(UI.suggesters) do
      if sg.hideAt and now > sg.hideAt then sg.hideAt = nil sg.Hide() end
    end
    if UI.tab == "sell" and (AH.bagsDirty or AH.job or AH.Searching()) then UI.Refresh() end
  end)
end)
