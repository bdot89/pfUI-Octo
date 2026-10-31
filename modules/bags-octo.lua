pfUI:RegisterModule("bags-octo", "vanilla:tbc", function ()
  -- pfUI Octo :: Bagnon-style bag and bank windows (25 Oct 2026).
  -- User: "we need a addon building in like Bagnon" (Bagnon 12.1.7 zip; its
  -- licence is All Rights Reserved, so only its feature list was read and
  -- this is written fresh for 1.12). Chosen with the user: the core window -
  -- one inventory and one bank window with a title bar, search, a bag bar
  -- that shows / hides each bag, money and free slots, sort, moving, and
  -- columns / size / spacing / scale / colours.
  --
  -- Built on pfUI's own bag module (modules/bags.lua, untouched): its slot
  -- buttons, cooldowns, item locks, search and buttons stay; this wraps
  -- pfUI.bag:CreateBags / UpdateSlot / ReanchorAdditions and lays the
  -- windows out again after pfUI did. Sort = libbagsort's button (ClassicAPI
  -- C_Container.SortBags when present, else one item at a time).
  -- Settings: C.bagsocto (api/config.lua), page "Bags" (bags-options.lua).
  local PB = pfUI.bag
  if not PB or not PB.CreateBags or not PB.UpdateSlot then return end

  local BO = {}
  pfUI.bagsOcto = BO

  local function S() return C.bagsocto end
  local function N(v, d) return tonumber(v) or d end

  -- the bags of each window in the order they are drawn (keyring last)
  BO.ORDER = { bags = { 0, 1, 2, 3, 4, -2 }, bank = { -1, 5, 6, 7, 8, 9, 10 } }
  BO.PAD, BO.HEAD, BO.SEARCH, BO.BAR, BO.FOOT, BO.MINW = 6, 20, 18, 24, 16, 230

  function BO.On() return S().enable == "1" end

  -- ---------------------------------------------------------------- hidden bags

  -- C.bagsocto.hidden = "2,3,-2" (the bags whose slots are not drawn)
  function BO.Hidden(bag)
    return string.find("," .. (S().hidden or "") .. ",", "," .. bag .. ",", 1, true) and true or false
  end

  function BO.SetHidden(bag, hide)
    local out = {}
    for b in string.gfind(S().hidden or "", "([^,]+)") do
      if tonumber(b) ~= bag then table.insert(out, b) end
    end
    if hide then table.insert(out, tostring(bag)) end
    S().hidden = table.concat(out, ",")
  end

  function BO.ToggleBag(bag)
    -- the keyring's slots are pfUI's own keyring switch
    if bag == -2 then
      PB.showKeyring = not PB.showKeyring and true or nil
      BO.SetHidden(-2, false)
      if PB.CheckFullUpdate then PB:CheckFullUpdate() end
    else
      BO.SetHidden(bag, not BO.Hidden(bag))
    end
    BO.Refresh()
  end

  -- ---------------------------------------------------------------- sizes

  -- slots of one bag as drawn (the keyring only while pfUI shows it)
  function BO.BagSize(bag)
    if bag == -2 then
      if not PB.showKeyring or not GetKeyRingSize then return 0 end
      return GetKeyRingSize() or 0
    end
    return GetContainerNumSlots(bag) or 0
  end

  -- where every slot goes: { { bag, slot, col, row }, ... } and the row
  -- count. sizes[bag] = slots; hidden(bag) leaves a bag out; brk = each bag
  -- starts a new row; rev = last slot first.
  function BO.Places(order, sizes, cols, hidden, brk, rev)
    local list = {}
    for _, bag in ipairs(order) do
      if not (hidden and hidden(bag)) then
        for slot = 1, (sizes[bag] or 0) do table.insert(list, { bag = bag, slot = slot }) end
      end
    end
    if rev then
      local n = table.getn(list)
      for i = 1, math.floor(n / 2) do list[i], list[n - i + 1] = list[n - i + 1], list[i] end
    end
    cols = math.max(1, cols)
    local col, row, last = 0, 0, nil
    for _, e in ipairs(list) do
      if brk and last ~= nil and e.bag ~= last and col > 0 then col, row = 0, row + 1 end
      e.col, e.row = col, row
      last = e.bag
      col = col + 1
      if col >= cols then col, row = 0, row + 1 end
    end
    local rows = row + ((col > 0) and 1 or 0)
    return list, rows
  end

  -- the whole window's measures (the real windows and the options preview
  -- use the same numbers). which = "bags" | "bank"
  function BO.Metrics(which, sizes)
    local s = S()
    local bank = which == "bank"
    local size, gap = N(s.size, 32), N(s.spacing, 3)
    local cols = N(bank and s.bankcolumns or s.columns, 10)
    local places, rows = BO.Places(BO.ORDER[which], sizes, cols, BO.Hidden, s.bagbreak == "1", s.reverse == "1")
    local m = { size = size, gap = gap, cols = cols, places = places, rows = rows, pad = BO.PAD }
    local y = BO.PAD
    m.headY = y
    y = y + BO.HEAD + 4
    if not bank and s.search == "1" then m.searchY = y y = y + BO.SEARCH + 4 end
    if s.bagbar == "1" then m.barY = y y = y + BO.BAR + 4 end
    m.gridY = y
    local used = math.min(cols, table.getn(places))
    if rows > 1 then used = cols end
    m.gridW = math.max(0, used * (size + gap) - gap)
    m.gridH = math.max(0, rows * (size + gap) - gap)
    y = y + m.gridH
    if s.free == "1" or (not bank and s.money == "1") then
      y = y + 4
      m.footY = y
      y = y + BO.FOOT
    end
    m.h = y + BO.PAD
    m.w = math.max(m.gridW, BO.MINW) + 2 * BO.PAD
    return m
  end

  function BO.Sizes(which)
    local t = {}
    for _, bag in ipairs(BO.ORDER[which]) do t[bag] = BO.BagSize(bag) end
    return t
  end

  -- free / total slots of a window (the keyring never counts)
  function BO.Free(which)
    local free, total = 0, 0
    local CC = _G.C_UnitAuras and _G.C_Container
    for _, bag in ipairs(BO.ORDER[which]) do
      if bag ~= -2 then
        local n = GetContainerNumSlots(bag) or 0
        total = total + n
        local f
        -- ClassicAPI counts the backpack and bags 1-4 itself
        if CC and CC.GetContainerNumFreeSlots and bag >= 0 and bag <= 4 then
          local ok, v = pcall(CC.GetContainerNumFreeSlots, bag)
          if ok and type(v) == "number" then f = v end
        end
        if not f then
          f = 0
          for slot = 1, n do
            if not GetContainerItemInfo(bag, slot) then f = f + 1 end
          end
        end
        free = free + f
      end
    end
    return free, total
  end

  -- ---------------------------------------------------------------- colours

  function BO.Wash(which)
    local s = S()
    local mode = which == "bank" and s.bankwash or s.wash
    if mode == "class" then
      local _, cls = UnitClass("player")
      local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
      if c then return c.r, c.g, c.b end
    elseif mode == "accent" and GetAccentColor then
      return GetAccentColor()
    end
    local r, g, b = GetStringColor(which == "bank" and s.bankwashcolor or s.washcolor)
    return tonumber(r) or .2, tonumber(g) or .7, tonumber(b) or 1
  end

  -- a soft colour wash fading to the right (one texture, gradient alpha only)
  function BO.PaintWash(t, r, g, b, a)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetGradientAlpha("HORIZONTAL", r, g, b, a or .35, r, g, b, .02)
  end

  local function Text(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(pfUI.font_default, size or 12, "OUTLINE")
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetTextColor(1, 1, 1, 1)
    return fs
  end
  BO.Text = Text

  -- ---------------------------------------------------------------- bag bar

  local function InvSlot(bag)
    if bag >= 1 and bag <= 4 then
      local id = GetInventorySlotInfo("Bag" .. (bag - 1) .. "Slot")
      if id then return id end
    end
    if _G.ContainerIDToInventoryID then return _G.ContainerIDToInventoryID(bag) end
    if bag >= 5 and _G.BankButtonIDToInvSlotID then return _G.BankButtonIDToInvSlotID(bag - 4, 1) end
  end
  BO.InvSlot = InvSlot

  -- a bank bag slot not bought yet
  function BO.Locked(bag)
    return bag >= 5 and (bag - 4) > (GetNumBankSlots and GetNumBankSlots() or 0)
  end

  function BO.BagIcon(bag)
    if bag == 0 then return "Interface\\Buttons\\Button-Backpack-Up" end
    if bag == -1 then return "Interface\\Icons\\INV_Box_02" end
    if bag == -2 then return "Interface\\Icons\\INV_Misc_Key_03" end
    local inv = InvSlot(bag)
    local tex = inv and GetInventoryItemTexture("player", inv)
    return tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
  end

  function BO.BagName(bag)
    if bag == 0 then return BACKPACK_TOOLTIP or "Backpack" end
    if bag == -1 then return "Bank" end
    if bag == -2 then return KEYRING or "Keyring" end
    return GetBagName(bag) or (bag >= 5 and ("Bank bag " .. (bag - 4)) or ("Bag " .. bag))
  end

  local function BagEnter()
    local bag = this.bag
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    local inv = (bag >= 1) and InvSlot(bag)
    if BO.Locked(bag) then
      GameTooltip:SetText(BANK_BAG_PURCHASE or "Buy a bank bag slot")
      if GetBankSlotCost then
        GameTooltip:AddLine("Cost: " .. CreateGoldString(GetBankSlotCost(GetNumBankSlots())), 1, 1, 1)
      end
      GameTooltip:AddLine("Click at the bank to buy it.", .35, .7, 1)
    else
      if not (inv and GameTooltip:SetInventoryItem("player", inv)) then GameTooltip:SetText(BO.BagName(bag)) end
      local shown = bag == -2 and PB.showKeyring or (bag ~= -2 and not BO.Hidden(bag))
      if shown then
        GameTooltip:AddLine("Click: hide its slots", .95, .3, .3)
      else
        GameTooltip:AddLine("Click: show its slots", .25, .85, .4)
      end
      if bag >= 1 then GameTooltip:AddLine("Drag: pick the bag up", .6, .61, .65) end
    end
    GameTooltip:Show()
  end

  local function BagPut(bag)
    if not CursorHasItem() then return end
    if bag == 0 then PutItemInBackpack() return true end
    local inv = bag >= 1 and InvSlot(bag)
    if inv then PutItemInBag(inv) return true end
  end

  local function BagClick()
    local bag = this.bag
    if BagPut(bag) then return end
    if BO.Locked(bag) then
      if BankFrame and BankFrame:IsVisible() and bag - 4 == GetNumBankSlots() + 1 then
        StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
      end
      return
    end
    BO.ToggleBag(bag)
    BagEnter()
  end

  function BO.BagButton(parent, bag)
    local b = CreateFrame("Button", nil, parent)
    b.bag = bag
    CreateBackdrop(b, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(.08, .92, .08, .92)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b.icon)
    hl:SetTexture(1, 1, 1, .15)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", BagClick)
    b:SetScript("OnReceiveDrag", function() BagPut(this.bag) end)
    b:SetScript("OnDragStart", function()
      local inv = this.bag >= 1 and not BO.Locked(this.bag) and InvSlot(this.bag)
      if inv then PickupBagFromSlot(inv) end
    end)
    b:SetScript("OnEnter", BagEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end

  -- one bag button's look: shown = its picture, hidden = grey with a red
  -- edge, not bought = dark with a red edge
  function BO.PaintBag(b)
    local bag = b.bag
    b.icon:SetTexture(BO.BagIcon(bag))
    local off = BO.Locked(bag) or (bag == -2 and not PB.showKeyring) or (bag ~= -2 and BO.Hidden(bag))
    if b.icon.SetDesaturated then b.icon:SetDesaturated(off and 1 or nil) end
    b.icon:SetAlpha(off and .45 or 1)
    if off then
      b.backdrop:SetBackdropBorderColor(.95, .3, .3, 1)
    else
      b.backdrop:SetBackdropBorderColor(.25, .85, .4, .9)
    end
  end

  -- ---------------------------------------------------------------- one window

  -- dragging a window by its title bar or its body (unless locked)
  local function StartMove()
    local f = this.octoWindow or this
    if S().locked == "1" then return end
    f:SetMovable(true)
    f:StartMoving()
  end
  local function StopMove()
    local f = this.octoWindow or this
    f:StopMovingOrSizing()
    BO.SavePlace(f, f.octoWhich)
    BO.Place(f, f.octoWhich)
  end

  function BO.SavePlace(f, which)
    local k = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local s = S()
    if which == "bags" then
      if not f:GetRight() then return end
      s.bagsx, s.bagsy = tostring(math.floor(f:GetRight() * k + .5)), tostring(math.floor(f:GetBottom() * k + .5))
    else
      if not f:GetLeft() then return end
      s.bankx, s.banky = tostring(math.floor(f:GetLeft() * k + .5)), tostring(math.floor(f:GetTop() * k + .5))
    end
  end

  function BO.Place(f, which)
    local s = S()
    local x, y = tonumber(s[which .. "x"]), tonumber(s[which .. "y"])
    f:ClearAllPoints()
    if x and y then
      local k = (UIParent:GetEffectiveScale() or 1) / (f:GetEffectiveScale() or 1)
      if which == "bags" then
        f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x * k, y * k)
      else
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x * k, y * k)
      end
    elseif which == "bags" then
      f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 190)
    else
      f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -110)
    end
  end

  function BO.ResetPlaces()
    local s = S()
    s.bagsx, s.bagsy, s.bankx, s.banky = "", "", "", ""
    BO.Refresh()
  end

  -- the parts this module adds to a pfUI window (once)
  function BO.Build(f, which)
    if f.octo then return f.octo end
    local o = {}
    f.octo = o
    f.octoWhich = which
    o.head = CreateFrame("Button", nil, f)
    o.head.octoWindow = f
    o.head:SetHeight(BO.HEAD)
    o.head:RegisterForDrag("LeftButton")
    o.head:RegisterForClicks("RightButtonUp")
    o.head:SetScript("OnDragStart", StartMove)
    o.head:SetScript("OnDragStop", StopMove)
    o.head:SetScript("OnClick", function() BO.OpenOptions() end)
    o.head:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(which == "bank" and "Bank" or "Bags")
      if S().locked ~= "1" then GameTooltip:AddLine("Drag: move the window", .6, .61, .65) end
      GameTooltip:AddLine("Right-click: bag options", .35, .7, 1)
      GameTooltip:Show()
    end)
    o.head:SetScript("OnLeave", function() GameTooltip:Hide() end)
    o.wash = o.head:CreateTexture(nil, "BACKGROUND")
    o.wash:SetAllPoints(o.head)
    o.title = Text(o.head, 12)
    o.title:SetPoint("LEFT", o.head, "LEFT", 6, 0)
    o.title:SetJustifyH("LEFT")

    o.bar = CreateFrame("Frame", nil, f)
    o.bar:SetHeight(BO.BAR)
    o.bags = {}
    for i, bag in ipairs(BO.ORDER[which]) do
      local b = BO.BagButton(o.bar, bag)
      b:SetWidth(BO.BAR)
      b:SetHeight(BO.BAR)
      b:SetPoint("LEFT", o.bar, "LEFT", (i - 1) * (BO.BAR + 4), 0)
      o.bags[i] = b
    end
    -- the bags window's last tab: the bank snapshot (blue edge: it opens something)
    if which == "bags" then
      local s = CreateFrame("Button", nil, o.bar)
      CreateBackdrop(s, 1)
      s.backdrop:SetBackdropBorderColor(.3, .6, 1, 1)
      s:SetWidth(BO.BAR)
      s:SetHeight(BO.BAR)
      s:SetPoint("LEFT", o.bar, "LEFT", table.getn(BO.ORDER.bags) * (BO.BAR + 4) + 6, 0)
      s.icon = s:CreateTexture(nil, "ARTWORK")
      s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 2, -2)
      s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 2)
      s.icon:SetTexCoord(.08, .92, .08, .92)
      s.icon:SetTexture("Interface\\Icons\\INV_Box_02")
      local hl = s:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints(s.icon)
      hl:SetTexture(1, 1, 1, .15)
      s:SetScript("OnClick", function() BO.ToggleSnapshot() end)
      s:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Bank")
        GameTooltip:AddLine("Click: what your bank holds, from your last visit.", 1, 1, 1, 1)
        GameTooltip:AddLine("Other characters' banks are in its menu.", .35, .7, 1, 1)
        GameTooltip:Show()
      end)
      s:SetScript("OnLeave", function() GameTooltip:Hide() end)
      o.snapbtn = s
    end

    o.foot = CreateFrame("Frame", nil, f)
    o.foot:SetHeight(BO.FOOT)
    o.free = Text(o.foot, 11)
    o.free:SetPoint("LEFT", o.foot, "LEFT", 2, 0)
    o.money = Text(o.foot, 11)
    o.money:SetPoint("RIGHT", o.foot, "RIGHT", -2, 0)

    -- the window body drags too
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", StartMove)
    f:SetScript("OnDragStop", StopMove)
    return o
  end

  -- pfUI's small buttons in the title bar, right to left
  function BO.Header(f)
    local o = f and f.octo
    if not o then return end
    -- a clear "Sort" button in place of pfUI's small sort icon (user, 25 Oct
    -- 2026: "make this button also be on the bags so it is able to be done
    -- without opening UI"); bags or bank by the window
    local W = pfUI.octoui and pfUI.octoui.W
    if not o.sortb and W then
      o.sortb = W.Button(o.head, "Sort", 40, 16)
      if W.Tint then W.Tint(o.sortb, "go") end
      o.sortb.which = f.octoWhich
      o.sortb:SetScript("OnClick", function()
        if pfUI.api.libbagsort then pfUI.api.libbagsort:Sort(this.which == "bank" and "bank" or "bags") end
      end)
      W.Tip(o.sortb, "Sort", "Sorts this window's items: instantly with ClassicAPI, else one item at a time.")
    end
    if f.sort and o.sortb then f.sort:Hide() end
    local list = { f.close, f.bags, o.sortb or f.sort, f.keys, f.open, f.picklock, f.disenchant }
    local prev
    for _, b in ipairs(list) do
      local use = b ~= nil
      if (b == f.sort or (o.sortb and b == o.sortb)) and S().sortbtn ~= "1" then use = false end
      if (b == f.picklock or b == f.disenchant) and b and not (b:GetID() and b:GetID() > 0) then use = false end
      if b then
        if use then
          b:SetParent(o.head)
          b:ClearAllPoints()
          b:SetWidth(b == o.sortb and 40 or 16)
          b:SetHeight(16)
          if prev then
            b:SetPoint("RIGHT", prev, "LEFT", -4, 0)
          else
            b:SetPoint("RIGHT", o.head, "RIGHT", -3, 0)
          end
          b:SetFrameLevel(o.head:GetFrameLevel() + 2)
          b:Hide() b:Show()
          prev = b
        else
          b:Hide()
        end
      end
    end
    if f.bags then
      f.bags:SetScript("OnClick", function()
        S().bagbar = S().bagbar == "1" and "0" or "1"
        BO.Refresh()
      end)
    end
  end

  function BO.Footer(f)
    local o = f and f.octo
    if not o then return end
    local which, s = f.octoWhich, S()
    if s.free == "1" then
      local free, total = BO.Free(which)
      local r, g, b = .25, .85, .4
      if free == 0 then r, g, b = .95, .3, .3 elseif free <= 4 then r, g, b = 1, .78, .2 end
      o.free:SetText(string.format("|cff%02x%02x%02x%d|r |cff999aa6/ %d free|r", r * 255, g * 255, b * 255, free, total))
      o.free:Show()
    else
      o.free:Hide()
    end
    if which == "bags" and s.money == "1" then
      o.money:SetText(CreateGoldString(GetMoney()))
      o.money:Show()
    else
      o.money:Hide()
    end
    for _, b in ipairs(o.bags) do BO.PaintBag(b) end
  end

  -- lay a window out again (after pfUI's CreateBags placed it its own way)
  function BO.Layout(which)
    local f = which == "bank" and PB.left or PB.right
    if not f then return end
    local s = S()
    local o = BO.Build(f, which)
    f:SetScale(N(s.scale, 1))
    local m = BO.Metrics(which, BO.Sizes(which))
    f:SetWidth(m.w)
    f:SetHeight(m.h)
    BO.Place(f, which)
    if f.backdrop then
      f.backdrop:SetBackdropColor(.06, .065, .075, N(s.bgalpha, .92))
    end

    o.head:ClearAllPoints()
    o.head:SetPoint("TOPLEFT", f, "TOPLEFT", m.pad, -m.headY)
    o.head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -m.pad, -m.headY)
    local r, g, b = BO.Wash(which)
    BO.PaintWash(o.wash, r, g, b, .4)
    if s.title == "1" then
      local name = UnitName("player") or ""
      o.title:SetText(which == "bank" and (name .. "'s bank") or (name .. "'s bags"))
      o.title:Show()
    else
      o.title:Hide()
    end
    BO.Header(f)

    if f.search then
      if m.searchY then
        f.search:SetParent(f)
        f.search:ClearAllPoints()
        f.search:SetPoint("TOPLEFT", f, "TOPLEFT", m.pad, -m.searchY)
        f.search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -m.pad, -m.searchY)
        f.search:SetHeight(BO.SEARCH)
        f.search:Show()
      else
        f.search:Hide()
      end
    end
    if f.bagslots then f.bagslots:Hide() end
    if f.gold then f.gold:Hide() end

    if m.barY then
      o.bar:ClearAllPoints()
      o.bar:SetPoint("TOPLEFT", f, "TOPLEFT", m.pad, -m.barY)
      o.bar:SetWidth(m.w - 2 * m.pad)
      o.bar:Show()
      for _, bt in ipairs(o.bags) do
        bt:Show()
        if bt.bag == -2 and not GetKeyRingSize then bt:Hide() end
      end
    else
      o.bar:Hide()
    end

    -- the slots: hidden bags' slots away, the rest on the grid
    for _, bag in ipairs(BO.ORDER[which]) do
      local holder = pfUI.bags[bag]
      if holder and holder.slots then
        for _, sl in pairs(holder.slots) do
          if sl.frame and BO.Hidden(bag) then sl.frame:Hide() end
        end
      end
    end
    local step = m.size + m.gap
    for _, e in ipairs(m.places) do
      local holder = pfUI.bags[e.bag]
      local sl = holder and holder.slots and holder.slots[e.slot]
      if sl and sl.frame then
        sl.frame:ClearAllPoints()
        sl.frame:SetPoint("TOPLEFT", f, "TOPLEFT", m.pad + e.col * step, -(m.gridY + e.row * step))
        sl.frame:SetWidth(m.size)
        sl.frame:SetHeight(m.size)
        BO.Mark(e.bag, e.slot)
      end
    end

    if m.footY then
      o.foot:ClearAllPoints()
      o.foot:SetPoint("TOPLEFT", f, "TOPLEFT", m.pad, -m.footY)
      o.foot:SetPoint("TOPRIGHT", f, "TOPRIGHT", -m.pad, -m.footY)
      o.foot:Show()
    else
      o.foot:Hide()
    end
    BO.Footer(f)
    if BO.onLayout then BO.onLayout(which) end
  end

  -- both windows again (from the options, a bag click...)
  function BO.Refresh()
    if not BO.On() then return end
    if PB.right then PB:CreateBags() end
    if PB.left then PB:CreateBags("bank") end
  end

  function BO.OpenOptions()
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Open then O:Open("bagsocto") end
  end

  -- ---------------------------------------------------------------- item marks

  -- (25 Oct 2026, user: "the item glow next: quest / junk / unusable marks and
  -- a new-item glow with ClassicAPI C_NewItems")
  --   new      a pulsing glow on items you got since login (ClassicAPI's flag,
  --            else BO.new: an item id you owned none of a moment ago);
  --            mouse over it, or close the bags, and it stops
  --   junk     a coin on grey items
  --   quest    a ? on quest items, a ! on items that start a quest
  --   unusable red tint (pfUI's unusable.lua scans the tooltip; ClassicAPI's
  --            C_PlayerInfo.CanUseItem answers first when the client has it)
  BO.ICON = {
    junk = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    quest = "Interface\\GossipFrame\\ActiveQuestIcon",
    start = "Interface\\GossipFrame\\AvailableQuestIcon",
    glow = "Interface\\Buttons\\UI-ActionButton-Border",
  }
  BO.new = {}        -- [item id] = true (without ClassicAPI)
  BO.glowing = {}    -- [slot frame] = true while it glows
  local scanner = libtipscan and libtipscan:GetScanner("bagsocto")
  local starts = {}  -- [item string] = true / false (tooltip says it starts a quest)

  local function NI() return _G.C_UnitAuras and _G.C_NewItems end

  function BO.ItemId(link)
    local _, _, id = string.find(link or "", "item:(%d+)")
    return tonumber(id)
  end

  -- every item id you have now, with counts: bags 0-4, worn, and the bank as
  -- last seen open (moving between them is not "new")
  BO.bankCount = {}
  function BO.Owned()
    local t = {}
    local function Add(link, n)
      local id = BO.ItemId(link)
      if id then t[id] = (t[id] or 0) + (n or 1) end
    end
    for bag = 0, 4 do
      for slot = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, slot)
        if link then
          local _, n = GetContainerItemInfo(bag, slot)
          Add(link, n)
        end
      end
    end
    for inv = 1, 19 do Add(GetInventoryItemLink("player", inv), 1) end
    if BankFrame and BankFrame:IsVisible() then
      local b = {}
      for _, bag in ipairs(BO.ORDER.bank) do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
          local id = BO.ItemId(GetContainerItemLink(bag, slot))
          if id then
            local _, n = GetContainerItemInfo(bag, slot)
            b[id] = (b[id] or 0) + (n or 1)
          end
        end
      end
      BO.bankCount = b
    end
    for id, n in pairs(BO.bankCount) do t[id] = (t[id] or 0) + n end
    return t
  end

  -- the plain-API new items: ids owned now that were not owned at the last
  -- look (a few seconds after login everything counts as already yours)
  BO.readyAt = GetTime() + 4
  function BO.ScanNew()
    if NI() and NI().IsNewItem then return end
    local now = BO.Owned()
    if BO.seen and GetTime() >= BO.readyAt then
      for id in pairs(now) do
        if not BO.seen[id] then BO.new[id] = true end
      end
    end
    for id in pairs(BO.new) do if not now[id] then BO.new[id] = nil end end
    BO.seen = now
  end

  function BO.IsNew(bag, slot)
    if S().glownew ~= "1" or bag < 0 or bag > 4 then return false end
    local ni = NI()
    if ni and ni.IsNewItem then
      local ok, v = pcall(ni.IsNewItem, bag, slot)
      if ok then return v and true or false end
    end
    local id = BO.ItemId(GetContainerItemLink(bag, slot))
    return id and BO.new[id] and true or false
  end

  -- seen: mouse over a glowing item
  function BO.Seen(bag, slot)
    local ni = NI()
    if ni and ni.RemoveNewItem and bag >= 0 and bag <= 4 then pcall(ni.RemoveNewItem, bag, slot) end
    local id = BO.ItemId(GetContainerItemLink(bag, slot))
    if id then BO.new[id] = nil end
    BO.Mark(bag, slot)
  end

  function BO.ClearNew()
    local ni = NI()
    if ni and ni.ClearAll then pcall(ni.ClearAll) end
    BO.new = {}
    BO.MarkAll()
  end

  function BO.StartsQuest(bag, slot, link)
    local key = string.gsub(link or "", "^.-(item:[%d:]+).*$", "%1")
    if starts[key] == nil then
      local found = false
      if scanner and ITEM_STARTS_QUEST then
        local ok, hit = pcall(function()
          if bag == -1 then scanner:SetInventoryItem("player", 39 + slot) else scanner:SetBagItem(bag, slot) end
          return scanner:Find(ITEM_STARTS_QUEST, true)
        end)
        found = ok and hit and true or false
      end
      starts[key] = found
    end
    return starts[key]
  end

  -- what one item shows: { new, junk, quest = "quest" | "start", bad }
  function BO.Marks(bag, slot)
    local s = S()
    local link = GetContainerItemLink(bag, slot)
    if not link then return {} end
    local m = {}
    local _, _, quality, _, class = _G.GetItemInfo((string.gsub(link, "^.-(item:[%d:]+).*$", "%1")))
    if quality == nil then
      local _, _, _, q = GetContainerItemInfo(bag, slot)
      quality = q
    end
    m.new = BO.IsNew(bag, slot)
    m.junk = s.junk == "1" and quality == 0
    if s.quest == "1" then
      if BO.StartsQuest(bag, slot, link) then m.quest = "start"
      elseif class == "Quest" then m.quest = "quest" end
    end
    if C.appearance.bags.unusable == "1" then
      local PI = _G.C_UnitAuras and _G.C_PlayerInfo
      if PI and PI.CanUseItem then
        local ok, can = pcall(PI.CanUseItem, BO.ItemId(link))
        if ok and can == false then m.bad = true end
      end
    end
    return m
  end

  local function Corner(f, layer)
    local t = f:CreateTexture(nil, layer or "OVERLAY")
    t:SetWidth(13)
    t:SetHeight(13)
    return t
  end

  -- the marks' textures on one of pfUI's slot buttons (made once)
  function BO.MarkParts(f)
    if f.octoMarks then return f.octoMarks end
    local p = {}
    f.octoMarks = p
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints(f)
    top:SetFrameLevel(f:GetFrameLevel() + 3)
    p.top = top
    p.glow = top:CreateTexture(nil, "OVERLAY")
    p.glow:SetTexture(BO.ICON.glow)
    p.glow:SetBlendMode("ADD")
    p.glow:SetPoint("CENTER", f, "CENTER", 0, 0)
    p.junk = Corner(top)
    p.junk:SetTexture(BO.ICON.junk)
    p.junk:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    p.quest = Corner(top)
    p.quest:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -1)
    -- mouse over = seen (the template's own OnEnter still runs first)
    local enter = f:GetScript("OnEnter")
    f:SetScript("OnEnter", function()
      if enter then enter() end
      local parent = this:GetParent()
      if this.octoGlows and parent and parent.GetID then BO.Seen(parent:GetID(), this:GetID()) end
    end)
    return p
  end

  function BO.Mark(bag, slot)
    local holder = pfUI.bags[bag]
    local sl = holder and holder.slots and holder.slots[slot]
    local f = sl and sl.frame
    if not f then return end
    local p = BO.MarkParts(f)
    local m = BO.On() and BO.Marks(bag, slot) or {}
    local size = f:GetWidth() or 32
    p.glow:SetWidth(size * 1.75)
    p.glow:SetHeight(size * 1.75)
    if m.new then
      local r, g, b = GetStringColor(S().newcolor)
      p.glow:SetVertexColor(tonumber(r) or 1, tonumber(g) or .85, tonumber(b) or .3, 1)
      p.glow:Show()
      f.octoGlows = true
      BO.glowing[f] = true
    else
      p.glow:Hide()
      f.octoGlows = nil
      BO.glowing[f] = nil
    end
    if m.junk then p.junk:Show() else p.junk:Hide() end
    if m.quest then
      p.quest:SetTexture(BO.ICON[m.quest])
      p.quest:Show()
      if f.qtext then f.qtext:SetText("") end
    else
      p.quest:Hide()
    end
    if m.bad then
      local r, g, b, a = GetStringColor(C.appearance.bags.unusable_color)
      _G.SetItemButtonTextureVertexColor(f, tonumber(r) or .9, tonumber(g) or .2, tonumber(b) or .2, tonumber(a) or 1)
    end
  end

  function BO.MarkAll()
    for _, which in ipairs({ "bags", "bank" }) do
      for _, bag in ipairs(BO.ORDER[which]) do
        local holder = pfUI.bags[bag]
        if holder and holder.slots then
          for slot, sl in pairs(holder.slots) do
            if sl.frame and sl.frame:IsShown() then BO.Mark(bag, slot) end
          end
        end
      end
    end
  end

  -- the glow breathes (one clock for every glowing slot)
  function BO.Pulse(t)
    local a = .55 + .45 * math.sin((t or GetTime()) * 4)
    for f in pairs(BO.glowing) do
      if f.octoMarks and f:IsVisible() then f.octoMarks.glow:SetAlpha(a) end
    end
  end

  -- ---------------------------------------------------------------- hooks

  local rawCreate = PB.CreateBags
  function PB:CreateBags(object)
    rawCreate(self, object)
    if not BO.On() then return end
    local which = object == "bank" and "bank" or "bags"
    BO.Layout(which)
    -- closing the bag window = the new items were seen (pfUI sets OnHide again each time)
    local f = which == "bank" and PB.left or PB.right
    local hide = f and f:GetScript("OnHide")
    if f and which == "bags" then
      f:SetScript("OnHide", function()
        if hide then hide() end
        if S().newclear == "1" then BO.ClearNew() end
      end)
    end
  end

  local rawSlot = PB.UpdateSlot
  function PB:UpdateSlot(bag, slot)
    rawSlot(self, bag, slot)
    if not BO.On() then return end
    if BO.Hidden(bag) then
      local holder = pfUI.bags[bag]
      local sl = holder and holder.slots and holder.slots[slot]
      if sl and sl.frame then sl.frame:Hide() end
    else
      BO.Mark(bag, slot)
    end
  end

  if PB.UpdateItemLock then
    local rawLock = PB.UpdateItemLock
    function PB:UpdateItemLock()
      rawLock(self)
      if BO.On() then BO.MarkAll() end
    end
  end

  if PB.ReanchorAdditions then
    local rawAnchor = PB.ReanchorAdditions
    -- (pfUI lines the small title buttons up again when your spells change;
    -- with this window's title bar that made a loop - Show hung on
    -- Disenchant, Disenchant on Show: error in bags.lua, user 26 Oct 2026.
    -- While this window is on, only its own title bar lines them up.)
    function PB:ReanchorAdditions()
      if BO.On() and PB.right and PB.right.octo then BO.Header(PB.right) return end
      rawAnchor(self)
    end
  end

  -- money / free slots / bag pictures: once per frame of bag changes
  -- (ClassicAPI's BAG_UPDATE_DELAYED when the client has it), else 10 a second
  local watch = CreateFrame("Frame")
  BO.watch = watch
  local delayed
  if _G.C_EventUtils and _G.C_EventUtils.IsEventValid then
    local ok, valid = pcall(_G.C_EventUtils.IsEventValid, "BAG_UPDATE_DELAYED")
    delayed = ok and valid
  end
  watch:RegisterEvent(delayed and "BAG_UPDATE_DELAYED" or "BAG_UPDATE")
  watch:RegisterEvent("PLAYER_MONEY")
  watch:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
  watch:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
  watch:RegisterEvent("UNIT_INVENTORY_CHANGED")
  watch:RegisterEvent("PLAYER_ENTERING_WORLD")
  -- ClassicAPI: an item got or lost its new flag
  if delayed then watch:RegisterEvent("BAG_NEW_ITEMS_UPDATED") end
  watch:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      BO.readyAt = GetTime() + 4
      this.dirty = true
    elseif event == "BAG_UPDATE_DELAYED" then
      BO.UpdateShown()
    elseif event == "BAG_NEW_ITEMS_UPDATED" then
      if BO.On() then BO.MarkAll() end
    else
      this.dirty = true
    end
  end)
  watch:SetScript("OnUpdate", function()
    if next(BO.glowing) then BO.Pulse(GetTime()) end
    if not this.dirty or (this.tick or 0) > GetTime() then return end
    this.tick, this.dirty = GetTime() + .1, nil
    BO.UpdateShown()
  end)

  -- ---------------------------------------------------------------- bank snapshots
  -- (31 Oct 2026, user: "a bank tab in our bag tabs ... a snapshot of your bank
  -- ... view other banks on other characters on this account in a simple
  -- menu"). Each visit to a banker saves what the bank holds in
  -- pfUI_cache.banks[realm][name] (pfUI_cache is per account):
  -- { class, at = time(), slots = { { link, count, tex } | false ... }, total }.
  -- The bags window's bar gets a Bank button that opens pfBankSnapshot.

  BO.BANKBAGS = { -1, 5, 6, 7, 8, 9, 10 }

  function BO.Banks()
    pfUI_cache.banks = pfUI_cache.banks or {}
    local realm = GetRealmName() or "?"
    pfUI_cache.banks[realm] = pfUI_cache.banks[realm] or {}
    return pfUI_cache.banks[realm], realm
  end

  -- what the bank holds now (only while it is open: shut, the game reports nothing)
  function BO.SaveBank()
    if not BO.bankOpen then return end
    local slots, total = {}, 0
    for _, bag in ipairs(BO.BANKBAGS) do
      local n = GetContainerNumSlots(bag) or 0
      for slot = 1, n do
        total = total + 1
        local link = GetContainerItemLink(bag, slot)
        if link then
          local tex, count = GetContainerItemInfo(bag, slot)
          table.insert(slots, { link = link, count = count or 1, tex = tex })
        else
          table.insert(slots, false)
        end
      end
    end
    local banks = BO.Banks()
    local _, class = UnitClass("player")
    banks[UnitName("player") or "?"] = { class = class, at = time(), slots = slots, total = total }
    if BO.snap and BO.snap:IsShown() then BO.ShowSnapshot(BO.snap.who) end
  end

  local function Ago(at)
    local s = time() - (at or 0)
    if s < 120 then return "just now" end
    if s < 7200 then return math.floor(s / 60) .. " min ago" end
    if s < 172800 then return math.floor(s / 3600) .. " h ago" end
    return math.floor(s / 86400) .. " days ago"
  end

  local function ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return "|cffffffff" end
    return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
  end

  local SNAP_COLS, SNAP_SIZE, SNAP_GAP = 14, 30, 3

  local function SnapSlot(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(SNAP_SIZE)
    b:SetHeight(SNAP_SIZE)
    CreateBackdrop(b, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b.count = Text(b, 11)
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b:SetScript("OnEnter", function()
      if not this.link then return end
      local _, _, item = string.find(this.link, "(item:[%d:%-]+)")
      if not item then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(item)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Shift-click = link it in chat
    b:SetScript("OnClick", function()
      if this.link and IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Insert(this.link)
      end
    end)
    return b
  end

  function BO.SnapshotWindow()
    if BO.snap then return BO.snap end
    local f = CreateFrame("Frame", "pfBankSnapshot", UIParent)
    BO.snap = f
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    CreateBackdrop(f, nil, nil, .92)
    if CreateBackdropShadow then CreateBackdropShadow(f) end
    table.insert(UISpecialFrames, "pfBankSnapshot")

    f.head = CreateFrame("Frame", nil, f)
    f.head:SetHeight(BO.HEAD)
    f.head:SetPoint("TOPLEFT", f, "TOPLEFT", BO.PAD, -BO.PAD)
    f.head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -BO.PAD, -BO.PAD)
    f.wash = f.head:CreateTexture(nil, "BACKGROUND")
    f.wash:SetAllPoints(f.head)
    f.title = Text(f.head, 12)
    f.title:SetPoint("LEFT", f.head, "LEFT", 6, 0)

    f.close = CreateFrame("Button", nil, f.head)
    f.close:SetWidth(16)
    f.close:SetHeight(16)
    f.close:SetPoint("RIGHT", f.head, "RIGHT", -2, 0)
    if SkinCloseButton then SkinCloseButton(f.close, f.head, -2, -2) end
    f.close:SetScript("OnClick", function() BO.snap:Hide() end)

    -- the character menu: purple, it picks one of many
    f.pick = CreateFrame("Button", nil, f.head)
    f.pick:SetHeight(16)
    f.pick:SetWidth(120)
    f.pick:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
    CreateBackdrop(f.pick, 1)
    f.pick.backdrop:SetBackdropBorderColor(.62, .4, .95, 1)
    f.pick.text = Text(f.pick, 11)
    f.pick.text:SetPoint("CENTER", f.pick, "CENTER", 0, 0)
    f.pick.text:SetText("Characters  v")
    f.pick:SetScript("OnClick", function() BO.SnapMenu(this) end)
    f.pick:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText("Other characters' banks")
      GameTooltip:AddLine("Each character's bank is saved when it visits a banker.", 1, 1, 1, 1)
      GameTooltip:Show()
    end)
    f.pick:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.info = Text(f, 11)
    f.info:SetTextColor(.6, .61, .65)
    f.info:SetJustifyH("LEFT")
    f.empty = Text(f, 12)
    f.empty:SetTextColor(.6, .61, .65)
    f.slots = {}
    f:Hide()
    return f
  end

  function BO.SnapMenu(anchor)
    local W = pfUI.octoui and pfUI.octoui.W
    if not W or not W.Menu then return end
    local banks = BO.Banks()
    local names = {}
    for name in pairs(banks) do table.insert(names, name) end
    table.sort(names)
    local opts = { { label = "Banks on " .. (GetRealmName() or "this realm"), group = true } }
    for _, name in ipairs(names) do
      local d = banks[name]
      local used = 0
      for _, sl in ipairs(d.slots or {}) do if sl then used = used + 1 end end
      table.insert(opts, { key = name, label = ClassHex(d.class) .. name .. "|r  " .. used .. "/" .. (d.total or 0),
        tip = "Saved " .. Ago(d.at) .. "." })
    end
    local who = BO.snap and BO.snap.who
    if who and who ~= UnitName("player") and banks[who] then
      table.insert(opts, { key = "!forget", label = "|cffff5555Forget " .. who .. "'s bank|r" })
    end
    local m = W.Menu(anchor, opts, 190, function(key)
      if key == "!forget" then
        banks[who] = nil
        BO.ShowSnapshot(UnitName("player"))
        return
      end
      BO.ShowSnapshot(key)
    end)
    m:Show()
  end

  function BO.ShowSnapshot(who)
    local f = BO.SnapshotWindow()
    who = who or UnitName("player")
    f.who = who
    local d = BO.Banks()[who]
    local r, g, b = BO.Wash("bank")
    BO.PaintWash(f.wash, r, g, b, .4)
    f.title:SetText(ClassHex(d and d.class) .. who .. "|r's bank")
    for _, sl in ipairs(f.slots) do sl:Hide() end
    local top = BO.PAD + BO.HEAD + 6
    local w = 2 * BO.PAD + SNAP_COLS * (SNAP_SIZE + SNAP_GAP) - SNAP_GAP
    f:SetWidth(w)
    if not d or not d.slots then
      f.info:Hide()
      f.empty:ClearAllPoints()
      f.empty:SetPoint("TOP", f, "TOP", 0, -(top + 10))
      f.empty:SetWidth(w - 20)
      f.empty:SetText("No snapshot yet. Visit a banker on " .. who .. " and it is saved.")
      f.empty:Show()
      f:SetHeight(top + 44)
      f:Show()
      return
    end
    f.empty:Hide()
    local n, used = 0, 0
    for i, item in ipairs(d.slots) do
      local sl = f.slots[i] or SnapSlot(f)
      f.slots[i] = sl
      local col, row = math.mod(i - 1, SNAP_COLS), math.floor((i - 1) / SNAP_COLS)
      sl:ClearAllPoints()
      sl:SetPoint("TOPLEFT", f, "TOPLEFT", BO.PAD + col * (SNAP_SIZE + SNAP_GAP), -(top + row * (SNAP_SIZE + SNAP_GAP)))
      sl.link = item and item.link or nil
      if item then
        used = used + 1
        sl.icon:SetTexture(item.tex)
        sl.icon:Show()
        sl.count:SetText((item.count or 1) > 1 and item.count or "")
        local _, _, hex = string.find(item.link, "|c%x%x(%x%x%x%x%x%x)")
        local qr, qg, qb = .3, .3, .3
        if hex and hex ~= "ffffff" and hex ~= "9d9d9d" then
          qr, qg, qb = tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255, tonumber(string.sub(hex, 5, 6), 16) / 255
        end
        sl.backdrop:SetBackdropBorderColor(qr, qg, qb, 1)
      else
        sl.icon:Hide()
        sl.count:SetText("")
        sl.backdrop:SetBackdropBorderColor(.2, .2, .2, 1)
      end
      sl:Show()
      n = i
    end
    local rows = math.ceil(math.max(n, 1) / SNAP_COLS)
    local bottom = top + rows * (SNAP_SIZE + SNAP_GAP) + 4
    f.info:ClearAllPoints()
    f.info:SetPoint("TOPLEFT", f, "TOPLEFT", BO.PAD + 2, -bottom)
    f.info:SetText(used .. "/" .. (d.total or n) .. " slots  -  saved " .. Ago(d.at) .. "  -  Shift-click: link")
    f.info:Show()
    f:SetHeight(bottom + 16 + BO.PAD)
    f:Show()
  end

  function BO.ToggleSnapshot()
    if BO.snap and BO.snap:IsShown() then BO.snap:Hide() else BO.ShowSnapshot(UnitName("player")) end
  end

  local bankev = CreateFrame("Frame")
  bankev:RegisterEvent("BANKFRAME_OPENED")
  bankev:RegisterEvent("BANKFRAME_CLOSED")
  bankev:SetScript("OnEvent", function()
    if event == "BANKFRAME_OPENED" then
      BO.bankOpen = true
      BO.SaveBank()
    else
      -- (the last look before it shuts)
      BO.SaveBank()
      BO.bankOpen = nil
    end
  end)

  function BO.UpdateShown()
    -- (bank changes while it is open: the snapshot follows)
    if BO.bankOpen then BO.SaveBank() end
    if not BO.On() then return end
    BO.ScanNew()
    BO.MarkAll()
    if PB.right and PB.right:IsShown() then BO.Footer(PB.right) end
    if PB.left and PB.left:IsShown() then BO.Footer(PB.left) end
  end
end)
