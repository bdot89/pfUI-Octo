pfUI:RegisterModule("gear-options", "vanilla", function ()
  -- pfUI Octo :: the Gear section (24 Oct 2026, modules/gear.lua, gear-sheet.lua,
  -- gear-slots.lua). Gear sets: a set editor as ItemRack's / Outfitter's (saved sets
  -- on the left, the slots as on the character sheet with a tick each, the
  -- character wearing the set between them) and cards for the set, the buttons,
  -- swapping, the character window and the trinket bar. Slot buttons: its own page.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local GR = pfUI.gear
  if not W or not O or not O.AddPage or not GR then return end
  local GO = {}
  pfUI.gearOcto = GO

  local function G() return C.gear end
  local function U() GR.Changed() end
  local function Px(v) return v .. " px" end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key, U) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, U, fmt) end
  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function Flat(f, a)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(.06, .06, .08, a or .95)
    f:SetBackdropBorderColor(.2, .2, .24, 1)
  end

  -- the set being changed on the page
  function GO.Set() return GO.edit and C.gear.sets[GO.edit] end
  local function PickSet()
    if GO.edit and C.gear.sets[GO.edit] then return end
    GO.edit = GR.Current() or GR.Sets()[1]
  end
  function GO.Open(name)
    if name then GO.edit = name end
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("gearsets") else O:Open("gearsets") end
  end
  function GO.NewSet()
    local n = 1
    while C.gear.sets["Set " .. n] do n = n + 1 end
    GR.Save("Set " .. n, GR.Snapshot())
    GO.edit = "Set " .. n
    GR.Changed()
    return GO.edit
  end

  -- ---------------------------------------------------------------- set editor

  -- the slot buttons page lays slots out in three rows
  GO.ROWS = { { 1, 2, 3, 15, 5, 4, 19, 9 }, { 10, 6, 7, 8, 11, 12, 13, 14 }, { 16, 17, 18 } }
  local EMPTY = {}
  for _, s in ipairs(GR.SLOTS) do
    local _, tex = GetInventorySlotInfo and GetInventorySlotInfo(s[2])
    EMPTY[s[1]] = tex
  end
  -- the set editor as ItemRack's / Outfitter's (user, 24 Oct 2026: the first
  -- version "makes no sense"): the slots where the character sheet has them,
  -- a tick on each for "in this set", the character wearing the set between
  -- them, the saved sets listed on the left
  GO.LEFT = { 1, 2, 3, 15, 5, 4, 19, 9 }
  GO.RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }
  GO.BOTTOM = { 16, 17, 18 }
  -- rings, trinkets and one-hand weapons can come from the other slot of the pair
  local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }


  -- an item's picture, looked up fresh by the item (any copy - enchant and
  -- suffix do not change the picture): worn in that slot or its pair, in the
  -- bags, or the game's item info. Seen in game 24 Oct: a set saved while the
  -- game had not loaded its items held a placeholder picture
  -- (Interface\Icons\INV_Robe_02, a file the client does not have) for most
  -- slots, which then showed blank.
  local function BaseOf(id) return id and (string.gsub(id, ":.*$", "")) end
  local function WornBase(inv)
    local w = GR.Worn(inv)
    return w and BaseOf(w)
  end
  function GO.TexOf(id, inv)
    if not id then return "" end
    local base = BaseOf(id)
    if inv then
      for _, i in ipairs({ inv, PAIR[inv] }) do
        if WornBase(i) == base then
          local t = GR.InvTex(i)
          if GR.GoodTex(t) then return t end
        end
      end
    end
    for _, b in ipairs(GR.Bags()) do
      if BaseOf(b.id) == base then
        local t = GetContainerItemInfo(b.bag, b.slot)
        if GR.GoodTex(t) then return t end
      end
    end
    local info = _G.GetItemInfo
    if info then
      local _, _, _, _, _, _, _, _, tex = info("item:" .. base)
      if GR.GoodTex(tex) then return tex end
    end
    return ""
  end

  -- ---------------------------------------------------------------- icon picker

  -- every macro icon in a grid, as the game's macro window (user, 24 Oct 2026),
  -- the set's own item pictures first; a search box, the wheel scrolls
  local COLS, ROWS, ISZ = 10, 6, 34
  local picker
  local function Picker()
    if picker then return picker end
    picker = CreateFrame("Frame", "pfGearIconPicker", UIParent)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetWidth(COLS * (ISZ + 3) + 17)
    picker:SetHeight(ROWS * (ISZ + 3) + 72)
    Flat(picker, .97)
    picker:EnableMouse(true)
    picker:EnableMouseWheel(true)
    table.insert(UISpecialFrames, "pfGearIconPicker")
    picker:Hide()
    local title = picker:CreateFontString(nil, "OVERLAY")
    title:SetFont(W.UIFont(), 12, "OUTLINE")
    title:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -10)
    title:SetText("Pick an icon")
    local close = W.Button(picker, "X", 22, 20)
    close:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() picker:Hide() end)
    picker.search = W.EditBox(picker, 180)
    picker.search:SetPoint("TOPRIGHT", close, "TOPLEFT", -8, 0)
    picker.search:SetScript("OnTextChanged", function() picker.top = 0 picker:Fill() end)
    picker.search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    W.Tip(picker.search, "Search", "Part of the icon's file name: sword, shield, fire, holy, nature...")
    picker.buttons = {}
    for i = 1, COLS * ROWS do
      local b = CreateFrame("Button", nil, picker)
      b:SetWidth(ISZ)
      b:SetHeight(ISZ)
      local r = math.floor((i - 1) / COLS)
      local c = i - 1 - r * COLS
      b:SetPoint("TOPLEFT", picker, "TOPLEFT", 8 + c * (ISZ + 3), -36 - r * (ISZ + 3))
      Flat(b, 1)
      b.tex = b:CreateTexture(nil, "ARTWORK")
      b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
      b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
      b:SetScript("OnClick", function()
        if picker.onPick then picker.onPick(this.path) end
        picker:Hide()
      end)
      b:SetScript("OnEnter", function()
        local ar, ag, ab = Accent()
        this:SetBackdropBorderColor(ar, ag, ab, 1)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine((string.gsub(this.path or "", "^.*\\", "")))
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function()
        if this.path ~= picker.current then this:SetBackdropBorderColor(.2, .2, .24, 1) end
        GameTooltip:Hide()
      end)
      picker.buttons[i] = b
    end
    picker.page = picker:CreateFontString(nil, "OVERLAY")
    picker.page:SetFont(W.UIFont(), 11, "OUTLINE")
    picker.page:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 10, 10)
    picker.page:SetTextColor(.6, .6, .65)
    picker:SetScript("OnMouseWheel", function()
      local rows = math.ceil(table.getn(picker.shown or {}) / COLS)
      picker.top = math.max(0, math.min(math.max(0, rows - ROWS), (picker.top or 0) - (arg1 or 0)))
      picker:Fill()
    end)
    -- the list: the extra pictures first, then every macro icon (once each)
    function picker:Fill()
      local find = string.lower(self.search:GetText() or "")
      local list, seen = {}, {}
      local function Add(path)
        if not path or path == "" or seen[path] then return end
        seen[path] = true
        if find == "" or string.find(string.lower(path), find, 1, true) then table.insert(list, path) end
      end
      for _, path in ipairs(self.extra or {}) do Add(path) end
      for i = 1, (GetNumMacroIcons and GetNumMacroIcons() or 0) do
        local path = GetMacroIconInfo(i)
        -- (a bare icon name gets its folder)
        if path and not string.find(path, "\\", 1, true) then path = "Interface\\Icons\\" .. path end
        Add(path)
      end
      self.shown = list
      local ar, ag, ab = Accent()
      for i, b in ipairs(self.buttons) do
        local path = list[(self.top or 0) * COLS + i]
        b.path = path
        if path then
          b.tex:SetTexture(path)
          if path == self.current then b:SetBackdropBorderColor(ar, ag, ab, 1) else b:SetBackdropBorderColor(.2, .2, .24, 1) end
          b:Show()
        else
          b:Hide()
        end
      end
      local rows = math.max(1, math.ceil(table.getn(list) / COLS))
      self.page:SetText(table.getn(list) .. " icons   -   row " .. ((self.top or 0) + 1) .. " of " .. rows .. "   (mouse wheel scrolls)")
    end
    return picker
  end
  -- open it beside owner; extra = pictures to put first; onPick(path)
  function GO.IconPicker(owner, current, extra, onPick)
    local f = Picker()
    f.onPick, f.current, f.extra, f.top = onPick, current, extra, 0
    f.search:SetText("")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    f:Fill()
    f:Show()
    return f
  end

  local function Editor(p)
    local box = W.Box(p, 392)
    local holder = CreateFrame("Frame", nil, box)
    holder:SetAllPoints(box)
    GO.holder = holder
    local BW = box:GetWidth() or 668
    local SZ, GAP = 36, 4
    local ar, ag, ab = Accent()

    -- left: the saved sets
    local title = holder:CreateFontString(nil, "OVERLAY")
    title:SetFont(W.UIFont(), 12, "OUTLINE")
    title:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -12)
    title:SetText("Saved sets")
    GO.rows = {}
    local function Row(i)
      local r = GO.rows[i]
      if r then return r end
      r = CreateFrame("Button", nil, holder)
      r:SetWidth(176)
      r:SetHeight(24)
      r:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -32 - (i - 1) * 26)
      Flat(r, 1)
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetWidth(20)
      r.icon:SetHeight(20)
      r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
      r.icon:SetTexCoord(.07, .93, .07, .93)
      r.text = r:CreateFontString(nil, "OVERLAY")
      r.text:SetFont(W.UIFont(), 11, "OUTLINE")
      r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
      r.text:SetPoint("RIGHT", r, "RIGHT", -36, 0)
      r.text:SetJustifyH("LEFT")
      r.worn = r:CreateFontString(nil, "OVERLAY")
      r.worn:SetFont(W.UIFont(), 10, "OUTLINE")
      r.worn:SetPoint("RIGHT", r, "RIGHT", -5, 0)
      r.worn:SetTextColor(.3, 1, .4)
      r.worn:SetText("worn")
      r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      r:SetScript("OnClick", function()
        if arg1 == "RightButton" then GO.AskRename(this.set) return end
        GO.edit = this.set GR.Changed() O:Refresh()
      end)
      r:SetScript("OnDoubleClick", function() GR.Equip(this.set) end)
      r:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(this.set)
        GameTooltip:AddLine("Click: change it here", 1, 1, 1)
        GameTooltip:AddLine("Double-click: wear it", 1, 1, 1)
        GameTooltip:AddLine("Right-click: rename it", 1, 1, 1)
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
      GO.rows[i] = r
      return r
    end
    -- Rename (user, 24 Oct 2026): a box asking for the new name; the name
    -- box over the slots does the same on Enter
    function GO.AskRename(setname)
      setname = setname or GO.edit
      if not setname or not C.gear.sets[setname] then return end
      -- (another question box open would make this one close it instead)
      local open = _G["pfQuestionDialog"]
      if open and open:IsShown() then open:Hide() _G["pfQuestionDialog"] = nil end
      CreateQuestionDialog("Rename \"" .. setname .. "\" to:", function()
        local box = this:GetParent().input
        local v = box and string.gsub(box:GetText() or "", "^%s*(.-)%s*$", "%1")
        if v and v ~= "" and v ~= setname then
          if C.gear.sets[v] then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r gear: there is already a set called \"" .. v .. "\".")
          elseif GR.Rename(setname, v) then
            if GO.edit == setname then GO.edit = v end
            O:Refresh()
          end
        end
      end, false, true)
      local d = _G["pfQuestionDialog"]
      if d and d.input then d.input:SetText(setname) d.input:SetScript("OnEditFocusGained", function() this:HighlightText() end) d.input:SetFocus() d.input:HighlightText() end
    end

    local newBtn = W.Button(holder, "New set", 86, 22)
    newBtn:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 8, 30)
    local renBtn = W.Button(holder, "Rename", 86, 22)
    renBtn:SetPoint("LEFT", newBtn, "RIGHT", 4, 0)
    renBtn:SetScript("OnClick", function() GO.AskRename(GO.edit) end)
    W.Tip(renBtn, "Rename", "Give the set picked on the left a new name. Right-click a set does the same.")
    newBtn:SetScript("OnClick", function()
      GO.NewSet()
      O:Refresh()
      if GO.name then GO.name:SetFocus() GO.name:HighlightText() end
    end)
    W.Tip(newBtn, "New set", "Everything you wear now, as a new set. Untick the slots it should leave alone.")

    -- the slots, as on the character sheet
    local midL = 196 + SZ + 10
    local midR = BW - 10 - SZ - 10
    GO.slots = {}
    local function Slot(inv, x, y)
      local s = CreateFrame("Button", nil, holder)
      s.inv = inv
      s:SetWidth(SZ)
      s:SetHeight(SZ)
      s:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
      Flat(s, 1)
      s.icon = s:CreateTexture(nil, "ARTWORK")
      s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1)
      s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1)
      s.icon:SetTexCoord(.07, .93, .07, .93)
      s.off = s:CreateTexture(nil, "OVERLAY")
      s.off:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
      s.off:SetWidth(20)
      s.off:SetHeight(20)
      s.off:SetPoint("CENTER", s, "CENTER", 0, 0)
      -- the tick: in this set or not
      s.tick = CreateFrame("CheckButton", nil, s)
      s.tick:SetWidth(16)
      s.tick:SetHeight(16)
      s.tick:SetPoint("TOPLEFT", s, "TOPLEFT", -6, 6)
      s.tick:SetFrameLevel(s:GetFrameLevel() + 3)
      s.tick:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
      s.tick:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
      s.tick:SetScript("OnClick", function() GO.ToggleSlot(this:GetParent().inv) end)
      s.tick:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(GR.NAME[this:GetParent().inv])
        GameTooltip:AddLine("Ticked: the set puts this slot on. Unticked: it leaves this slot as it is.", 1, 1, 1, 1)
        GameTooltip:Show()
      end)
      s.tick:SetScript("OnLeave", function() GameTooltip:Hide() end)
      s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      s:SetScript("OnClick", function()
        if arg1 == "RightButton" then GO.ToggleSlot(this.inv) return end
        GO.PickFor(this)
      end)
      s:SetScript("OnEnter", function()
        local set = GO.Set()
        local e = set and set.slots[GR.Key(this.inv)]
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if type(e) == "table" and e.id then
          -- (the item's own tooltip, when the client knows it)
          local okTip = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. e.id .. ":0")
          if not okTip or (GameTooltip:NumLines() or 0) == 0 then GameTooltip:AddLine(e.name or "") end
        else
          GameTooltip:AddLine(GR.NAME[this.inv])
          if e == "empty" then GameTooltip:AddLine("The set takes this off.", 1, .5, .5)
          elseif e == nil then GameTooltip:AddLine("Not in this set: it stays as it is.", .7, .7, .7, 1) end
        end
        GameTooltip:AddLine("Click: pick its item  -  Right-click: in the set or not", .6, .8, 1)
        GameTooltip:Show()
      end)
      s:SetScript("OnLeave", function() GameTooltip:Hide() end)
      table.insert(GO.slots, s)
      return s
    end
    for i, inv in ipairs(GO.LEFT) do Slot(inv, 196, -12 - (i - 1) * (SZ + GAP)) end
    for i, inv in ipairs(GO.RIGHT) do Slot(inv, BW - 10 - SZ, -12 - (i - 1) * (SZ + GAP)) end
    local mid = (midL + midR) / 2
    for i, inv in ipairs(GO.BOTTOM) do Slot(inv, mid - (3 * SZ + 2 * GAP) / 2 + (i - 1) * (SZ + GAP), -12 - 7 * (SZ + GAP)) end

    -- the middle: icon and name, the character, the buttons
    local icon = CreateFrame("Button", nil, holder)
    icon:SetWidth(30)
    icon:SetHeight(30)
    icon:SetPoint("TOPLEFT", box, "TOPLEFT", midL, -12)
    Flat(icon, 1)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
    icon.tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    icon.tex:SetTexCoord(.07, .93, .07, .93)
    -- (click: every macro icon to pick from, the set's own items first)
    icon:SetScript("OnClick", function()
      local set = GO.Set()
      if not set then return end
      local own = {}
      for _, s in ipairs(GR.SLOTS) do
        local e = set.slots[GR.Key(s[1])]
        if type(e) == "table" then local t = GO.TexOf(e.id, s[1]) if t == "" then t = e.tex end if GR.GoodTex(t) then table.insert(own, t) end end
      end
      GO.IconPicker(this, set.icon, own, function(path)
        local s2 = GO.Set()
        if s2 then s2.icon = path GR.Changed() end
      end)
    end)
    W.Tip(icon, "Icon", "Click to pick one: the set's items first, then every icon the macro window has.")
    local name = W.EditBox(holder, midR - midL - 40)
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetScript("OnEnterPressed", function()
      local v = this:GetText()
      if GO.edit and v ~= "" and GR.Rename(GO.edit, v) then GO.edit = v end
      this:ClearFocus()
      O:Refresh()
    end)
    name:SetScript("OnEscapePressed", function() this:SetText(GO.edit or "") this:ClearFocus() end)
    name:SetScript("OnEditFocusGained", function() GO.typing = true end)
    name:SetScript("OnEditFocusLost", function() GO.typing = nil end)
    GO.name = name
    W.Tip(name, "Name", "Type a name and press Enter.")

    -- the character, wearing the set (drag to turn it)
    -- (seen in game twice: inside the options window, which is scaled down to
    -- fit the screen, a 1.12 model draws as if unscaled and slides towards the
    -- bottom-left. So the model sits on UIParent and is lined up every frame
    -- over a spot in the editor; it hides with the page, and while the editor
    -- is scrolled out of view)
    local spot = CreateFrame("Frame", nil, holder)
    spot:SetWidth(midR - midL)
    spot:SetHeight(7 * (SZ + GAP) - 50)
    spot:SetPoint("TOP", box, "TOPLEFT", (midL + midR) / 2, -48)
    local model = CreateFrame("DressUpModel", "pfGearModel", UIParent)
    model:SetFrameStrata("FULLSCREEN")
    model:Hide()
    model:EnableMouse(true)
    model:SetScript("OnMouseDown", function() this.turnX = GetCursorPosition() this.turnF = this.facing or 0 end)
    model:SetScript("OnMouseUp", function() this.turnX = nil end)
    model:SetScript("OnShow", function() this.redress = 2 end)
    GO.model, GO.spot = model, spot
    holder:SetScript("OnHide", function() model:Hide() end)
    -- the page's visible area (the scroll frame round the page)
    local view = p.frame
    local watch = CreateFrame("Frame", nil, holder)
    watch:SetScript("OnUpdate", function()
      local t, b = spot:GetTop(), spot:GetBottom()
      local vt, vb = view and view:GetTop(), view and view:GetBottom()
      local inside = t and b and vt and vb and (t <= vt + 1) and (b >= vb - 1)
      if inside and not model:IsShown() then model:Show()
      elseif not inside and model:IsShown() then model:Hide() end
      if not model:IsShown() then return end
      -- the spot in UIParent's units
      local k = spot:GetEffectiveScale() / UIParent:GetEffectiveScale()
      local l, bt = (spot:GetLeft() or 0) * k, (spot:GetBottom() or 0) * k
      local w, h = (spot:GetWidth() or 1) * k, (spot:GetHeight() or 1) * k
      if l ~= model.l or bt ~= model.b or w ~= model.w or h ~= model.h then
        model.l, model.b, model.w, model.h = l, bt, w, h
        model:ClearAllPoints()
        model:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, bt)
        model:SetWidth(w)
        model:SetHeight(h)
        model.redress = 2
      end
      -- (dressed a frame after it moved, when it has its size)
      if model.redress then
        model.redress = model.redress - 1
        if model.redress <= 0 then model.redress = nil GO.Dress() end
      end
      if model.turnX then
        local x = GetCursorPosition()
        model.facing = model.turnF + (x - model.turnX) / 80
        if model.SetFacing then model:SetFacing(model.facing) end
      end
    end)
    local function Dress()
      if not model.SetUnit then return end
      pcall(model.SetUnit, model, "player")
      if model.SetFacing then model:SetFacing(model.facing or 0) end
      local set = GO.Set()
      for _, e in pairs(set and set.slots or {}) do
        if type(e) == "table" and e.id and model.TryOn then pcall(model.TryOn, model, "item:" .. e.id .. ":0") end
      end
    end
    GO.Dress = Dress

    -- the buttons under the character
    local function Btn(text, x, w, fn, tip)
      local b = W.Button(holder, text, w, 22)
      b:SetPoint("TOPLEFT", box, "TOPLEFT", x, -12 - 8 * (SZ + GAP) - 4)
      b:SetScript("OnClick", fn)
      W.Tip(b, text, tip)
      return b
    end
    local bw = math.floor((midR - midL - 12) / 4)
    GO.wear = Btn("Wear", midL, bw, function() if GO.edit then GR.Equip(GO.edit) end end,
      "Put this set on now (in combat: weapons now, the rest after).")
    Btn("Take off", midL + (bw + 4), bw, function() GR.Unequip(GO.edit) end, "Back to the gear worn before the set went on.")
    Btn("Save", midL + 2 * (bw + 4), bw, function()
      local set = GO.Set()
      if not set then GO.NewSet() O:Refresh() return end
      set.slots = GR.Snapshot(set.slots)
      GR.Changed()
    end, "The ticked slots take what you wear there now.")
    Btn("Delete", midL + 3 * (bw + 4), bw, function()
      if not GO.edit then return end
      if GO.sure ~= GO.edit or GetTime() > (GO.sureT or 0) then
        GO.sure, GO.sureT = GO.edit, GetTime() + 3
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r gear: click Delete again within 3 s to delete \"" .. GO.edit .. "\".")
        return
      end
      GR.Delete(GO.edit)
      GO.edit, GO.sure = nil, nil
      GR.Changed()
      O:Refresh()
    end, "Click twice to delete this set.")

    local hint = holder:CreateFontString(nil, "OVERLAY")
    hint:SetFont(W.UIFont(), 11, "OUTLINE")
    hint:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 196, 10)
    hint:SetTextColor(.6, .6, .65)
    local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
    hint:SetText(k .. "Tick|r = in this set     " .. k .. "Click|r a slot = pick its item     " .. k .. "Save|r = take what you wear     " .. k .. "Drag|r the character to turn it")

    local function Paint()
      PickSet()
      ar, ag, ab = Accent()
      local cur = GR.Current()
      local names = GR.Sets()
      local fit = math.floor((392 - 32 - 60) / 26)
      for i, n in ipairs(names) do
        if i <= fit then
          local r = Row(i)
          r.set = n
          r.icon:SetTexture(C.gear.sets[n].icon)
          r.text:SetText(n)
          -- (every set fully worn says so - two sets can hold the same gear)
          if GR.IsEquipped(n) then r.worn:Show() else r.worn:Hide() end
          if n == GO.edit then
            r:SetBackdropBorderColor(ar, ag, ab, 1)
            r:SetBackdropColor(ar * .45, ag * .45, ab * .45, 1)
          else
            r:SetBackdropBorderColor(.2, .2, .24, 1)
            r:SetBackdropColor(.06, .06, .08, 1)
          end
          r:Show()
        end
      end
      for i = table.getn(names) + 1, table.getn(GO.rows) do GO.rows[i]:Hide() end
      local set = GO.Set()
      if set and (not set.icon or set.icon == "") then GR.Save(GO.edit, set.slots) end
      icon.tex:SetTexture(set and set.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      if not GO.typing then name:SetText(GO.edit or "") end
      for _, s in ipairs(GO.slots) do
        local e = set and set.slots[GR.Key(s.inv)]
        s.off:Hide()
        s.icon:SetAlpha(1)
        s.tick:SetChecked(e ~= nil)
        if not set then s.tick:Hide() else s.tick:Show() end
        if type(e) == "table" then
          -- the picture looked up fresh by the item; the saved one only when
          -- the game cannot say (an item in the bank), and the fresh one
          -- replaces it in the set
          local fresh = GO.TexOf(e.id, s.inv)
          if fresh ~= "" then e.tex = fresh end
          s.icon:SetTexture((fresh ~= "" and fresh) or (GR.GoodTex(e.tex) and e.tex) or EMPTY[s.inv])
        elseif e == "empty" then
          s.icon:SetTexture(EMPTY[s.inv])
          s.icon:SetAlpha(.6)
          s.off:Show()
        else
          -- (not in the set: what you wear there, faded)
          s.icon:SetTexture(GR.InvTex(s.inv) or EMPTY[s.inv])
          s.icon:SetAlpha(.3)
        end
        local worn = set and e ~= nil and ((e == "empty" and not GR.Worn(s.inv)) or (type(e) == "table" and GR.Worn(s.inv) == e.id))
        if worn then s:SetBackdropBorderColor(ar, ag, ab, 1) else s:SetBackdropBorderColor(.2, .2, .24, 1) end
      end
      -- Wear: greyed out with "Worn" while this set is what you wear (user,
      -- 24 Oct 2026: "why is wear enabled when its this set that is worn")
      local onNow = set ~= nil and GR.IsEquipped(GO.edit)
      W.Lit(GO.wear, false)
      if onNow then
        GO.wear:Disable()
        GO.wear:SetText("Worn")
        GO.wear.label:SetTextColor(.45, .45, .45)
      else
        GO.wear:Enable()
        GO.wear:SetText("Wear")
      end
      Dress()
    end
    GO.Paint = Paint
    GR.listeners.options = function() if holder:IsVisible() then Paint() end end
    Paint()
    if p.items then table.insert(p.items, { Refresh = Paint }) end
  end

  -- in the set or not (in: what you wear there now)
  function GO.ToggleSlot(inv)
    local set = GO.Set()
    if not set then return end
    local key = GR.Key(inv)
    if set.slots[key] ~= nil then set.slots[key] = nil
    else set.slots[key] = GR.Snapshot({ [key] = true })[key] end
    GR.Changed()
  end

  -- a slot's item: what you wear there (and in its pair), what fits from the
  -- bags, or "take it off"
  function GO.PickFor(s)
    local set = GO.Set()
    if not set then return end
    local inv = s.inv
    local items, seen = {}, {}
    local function Add(it)
      if it and it.id and not seen[it.id] then seen[it.id] = true table.insert(items, it) end
    end
    for _, i in ipairs({ inv, PAIR[inv] }) do
      local id, link = GR.Worn(i)
      if id then
        local _, _, nm = string.find(link, "%[(.-)%]")
        local loc = GR.EquipLoc and GR.EquipLoc(link)
        local fits = (i == inv)
        for _, f in ipairs(loc and GR.FITS[loc] or {}) do if f == inv then fits = true end end
        if fits then Add({ id = id, name = nm or "", tex = GR.InvTex(i), link = link, worn = i }) end
      end
    end
    for _, it in ipairs(GR.ItemsFor(inv)) do Add(it) end
    table.insert(items, "empty")
    GR.Flyout(s, inv, function(item)
      local s2 = GO.Set()
      if not s2 then return end
      s2.slots[GR.Key(inv)] = (item == "empty") and "empty" or { id = item.id, full = GR.FullOf and GR.FullOf(item.link), name = item.name, tex = item.tex }
      GR.Changed()
    end, { items = items, empty = false, side = (s:GetLeft() or 0) > (GO.holder:GetLeft() or 0) + 300 and "LEFT" or "RIGHT",
           hint = "Puts it in this set (Wear puts the set on)." })
  end

  -- ---------------------------------------------------------------- page

  local function Build(p)
    W.Heading(p, "Gear sets", { on = O.ModuleSwitch("gear", "Gear sets"), about = "Gear sets as ItemRack and Outfitter make them: pick a set on the left, tick the slots "
      .. "it should change, click a slot to pick its item (or Save to take what you wear), then Wear. In combat your "
      .. "weapons change at once and the rest when combat ends. Also: the Gear sets list beside your character window, "
      .. "the set button, keys, /gear equip <set>." })
    Editor(p)
    -- (31 Oct 2026, user: menus "overwhelming")
    O.CardTabs(p, {
      { "set", "This set", "INV_Chest_Cloth_17", { "This set" } },
      { "opts", "Buttons and swapping", "INV_Misc_Gear_01", { "Buttons", "Swapping", "Character window", "Trinket bar" } },
    })

    W.Card(p, "This set", { tip = "The set picked on the left." })
    W.Buttons(p, {
      { "Pick an icon", function()
        local set = GO.Set()
        if not set then return end
        local own = {}
        for _, s in ipairs(GR.SLOTS) do
          local e = set.slots[GR.Key(s[1])]
          if type(e) == "table" then local t = GO.TexOf(e.id, s[1]) if t == "" then t = e.tex end if GR.GoodTex(t) then table.insert(own, t) end end
        end
        GO.IconPicker(this, set.icon, own, function(path)
          local s2 = GO.Set()
          if s2 then s2.icon = path GR.Changed() end
        end)
      end, nil, "Every icon the macro window has, the set's items first. Or click the icon beside the set's name." },
      { "Icon from its items", function()
        local s = GO.Set()
        if not s then return end
        s.icon = nil
        GR.Save(GO.edit, s.slots)
      end, nil, "Its chest, main hand or head picture." },
    })
    local keys = { { key = "", label = "None" } }
    for i = 1, 10 do table.insert(keys, { key = tostring(i), label = "Gear set " .. i }) end
    W.Dropdown(p, "Key", "Then give \"Gear set N\" a key in Key Bindings (pfUI Octo: gear sets).", keys,
      function() local s = GO.Set() return s and s.key or "" end,
      function(v)
        local s = GO.Set()
        if not s then return end
        -- (one set per key)
        for _, other in pairs(C.gear.sets) do if other.key == v then other.key = nil end end
        s.key = v ~= "" and v or nil
        GR.Changed()
      end)

    W.Card(p, "Buttons", { tip = "The set button (click: your sets) and the minimap button." })
    Chk(p, "Set button", "Shows the set you wear; click for your sets, Shift-click to take it off.", "button")
    Sld(p, "Set button size", nil, 20, 64, 1, "size", Px)
    Chk(p, "Set name under it", nil, "showname")
    Chk(p, "Minimap button", nil, "minimap")

    W.Card(p, "Swapping")
    Chk(p, "Weapons change in combat", "1.12 lets weapons change in combat; the rest always waits for combat to end.", "combatweapons")
    Chk(p, "Instant swap (ClassicAPI)", "With ClassicAPI the whole set goes on at once, without the cursor; off = one item at a time, as without it.", "instant")
    Chk(p, "Say when gear waits for combat", nil, "tellwait")
    Chk(p, "A set's key takes it off again", "Off: the key only puts the set on.", "keytoggle")
    Chk(p, "\"Take it off\" in item menus", nil, "allowempty")
    Sld(p, "Item menu: items per row", nil, 1, 12, 1, "wrap")
    Sld(p, "Item menu size", nil, .5, 2, .05, "menuscale", function(v) return math.floor(v * 100 + .5) .. "%" end)
    Chk(p, "Item tooltips", "The item's tooltip on the gear buttons, trinket bar and item menus. They never cover an item menu.", "tooltips")

    W.Card(p, "Character window", { tip = "Where you change gear: the slots and a list of your sets." })
    Chk(p, "Item menu on the slots", "Hover a slot of your character for what can go in it.", "sheet")
    Chk(p, "Only with Shift held", nil, "sheetshift")
    Chk(p, "Sets beside the window", nil, "sheetpanel")
    Chk(p, "Tooltips under the sets", "While the character window is open, item tooltips from its slots and menus sit in one place under the gear sets.", "sheettip")
    Sld(p, "Gear tooltip size", "Item tooltips on the gear buttons, menus and under the sets.", .5, 1.2, .05, "sheettipscale", function(v) return math.floor(v * 100 + .5) .. "%" end)
    W.Dropdown(p, "Which side", nil, { { key = "right", label = "Right" }, { key = "left", label = "Left" } },
      function() return C.gear.sheetside end, function(v) C.gear.sheetside = v U() end)

    W.Card(p, "Trinket bar", { tip = "Your two trinkets with their cooldowns, as TrinketMenu: click one to use it." })
    Chk(p, "Show the trinket bar", nil, "trinketbar")
    Sld(p, "Size", nil, 20, 64, 1, "trinketsize", Px)
    Chk(p, "Up and down", "Off: side by side.", "trinketvertical")
    Chk(p, "Trinket menu", "Your other trinkets: left-click puts one in the top slot, right-click in the bottom one.", "trinketmenu")
    Chk(p, "Menu on right-click", "Off: it opens when the mouse is over a trinket, and right-click opens the trinket queue. The cog in a trinket's corner: left-click = queue on / off, right-click = its queue.", "trinketmenuclick")
    Chk(p, "Menu only with Shift held", nil, "trinketshift")
    Chk(p, "Cooldown numbers", nil, "cdnumbers")
    O.TabFilter(p)
  end

  -- ---------------------------------------------------------------- slot buttons page

  -- the slots to pick (lit = on the bar) and the bar as it will look
  local function SlotPreview(p)
    W.Pin(p, "Preview", "Left: every slot - click one to put it on your bar or take it off (or Alt-click it in your "
      .. "character window). Right: your bar as it will look; Shift + wheel over it for bigger or smaller buttons. "
      .. "Click this bar to fold it away.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 168)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      -- headings over the two halves (user, 24 Oct 2026: "this is confusing")
      local function Head(text, x)
        local fs = holder:CreateFontString(nil, "OVERLAY")
        fs:SetFont(W.UIFont(), 11, "OUTLINE")
        fs:SetPoint("TOPLEFT", box, "TOPLEFT", x, -9)
        local ar, ag, ab = Accent()
        fs:SetTextColor(ar, ag, ab)
        fs:SetText(text)
        return fs
      end
      Head("1. Your equipment slots - click one to add it to the bar", 12)
      Head("2. Your slot bar", 300)
      local note = holder:CreateFontString(nil, "OVERLAY")
      note:SetFont(W.UIFont(), 10, "")
      note:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 12, 8)
      note:SetPoint("RIGHT", box, "RIGHT", -12, 0)
      note:SetJustifyH("LEFT")
      note:SetTextColor(.6, .6, .62)
      note:SetText("Ticked = on the bar. The bar shows what you wear in those slots: click a button to use the item, "
        .. "hover it to swap in another from your bags. Shift + wheel over the bar resizes it.")
      GO.picks = {}
      for r, row in ipairs(GO.ROWS) do
        for c, inv in ipairs(row) do
          local s = CreateFrame("Button", nil, holder)
          s.inv = inv
          s:SetWidth(30)
          s:SetHeight(30)
          Flat(s, 1)
          s.icon = s:CreateTexture(nil, "ARTWORK")
          s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1)
          s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1)
          s.icon:SetTexCoord(.07, .93, .07, .93)
          s:SetPoint("TOPLEFT", box, "TOPLEFT", 12 + (c - 1) * 33 + (table.getn(row) < 8 and (8 - table.getn(row)) * 16 or 0), -30 - (r - 1) * 34)
          s:SetScript("OnClick", function() GR.ToggleSlot(this.inv) O:Refresh() end)
          s:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:AddLine(GR.NAME[this.inv])
            GameTooltip:AddLine(GR.HasSlot(this.inv) and "On your bar - click to take it off." or "Click to put it on your bar.", 1, 1, 1)
            GameTooltip:Show()
          end)
          s:SetScript("OnLeave", function() GameTooltip:Hide() end)
          -- (a tick on the slots that are on your bar)
          s.tick = s:CreateTexture(nil, "OVERLAY")
          s.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
          s.tick:SetWidth(16)
          s.tick:SetHeight(16)
          s.tick:SetPoint("TOPLEFT", s, "TOPLEFT", -5, 5)
          s.tick:Hide()
          table.insert(GO.picks, s)
        end
      end
      -- the bar, drawn by the same layout code
      local sample = CreateFrame("Frame", nil, holder)
      local sbtn = {}
      for _, s in ipairs(GR.SLOTS) do sbtn[s[1]] = GR.NewSlotButton(sample, s[1], nil, true) end
      GO.sample, GO.sampleButtons = sample, sbtn
      local hot = CreateFrame("Button", nil, holder)
      hot:SetAllPoints(sample)
      hot:SetFrameLevel(sample:GetFrameLevel() + 6)
      hot:EnableMouseWheel(true)
      hot:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() then
          C.gear.slotsize = tostring(math.max(20, math.min(64, (tonumber(C.gear.slotsize) or 36) + (arg1 or 0))))
          GR.Changed()
          O:Refresh()
        elseif pfUI.plates and pfUI.plates.PassWheel then
          pfUI.plates.PassWheel(this)
        end
      end)
      hot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Your slot buttons")
        GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller", 1, 1, 1)
        GameTooltip:Show()
      end)
      hot:SetScript("OnLeave", function() GameTooltip:Hide() end)
      local function Paint()
        local ar, ag, ab = Accent()
        for _, s in ipairs(GO.picks) do
          s.icon:SetTexture(GR.InvTex(s.inv) or GR.EMPTYTEX[s.inv])
          if GR.HasSlot(s.inv) then
            s:SetBackdropBorderColor(ar, ag, ab, 1)
            s:SetBackdropColor(ar * .45, ag * .45, ab * .45, 1)
            s.icon:SetAlpha(1)
            s.tick:Show()
          else
            s:SetBackdropBorderColor(.2, .2, .24, 1)
            s:SetBackdropColor(.06, .06, .08, 1)
            s.icon:SetAlpha(.45)
            s.tick:Hide()
          end
        end
        local n = GR.LayoutSlots(sample, sbtn, GR.SlotList())
        local room = (box:GetWidth() or 600) - 300
        local scale = math.min(1, room / math.max(1, sample:GetWidth()), 84 / math.max(1, sample:GetHeight()))
        sample:SetScale(scale)
        sample:ClearAllPoints()
        sample:SetPoint("CENTER", box, "LEFT", (290 + room / 2) / scale, 0)
        sample:SetAlpha(C.gear.slotbar == "1" and (tonumber(C.gear.slotalpha) or 1) or .3)
        if n == 0 then sample:Hide() else sample:Show() end
      end
      GO.PaintSlots = Paint
      GR.listeners.slotoptions = function() if holder:IsVisible() then Paint() end end
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end
      W.Buttons(pp, {
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the slot buttons where you want them." },
      })
    end)
  end

  local function BuildSlots(p)
    W.Heading(p, "Slot buttons", { on = O.KeySwitch(function() return C.gear end, "slotbar", "The slot buttons on or off.", function() if GR.UpdateSlots then GR.UpdateSlots() end end), about = "Buttons for the equipment slots you pick (as ItemRack's): each shows what you wear "
      .. "there with its cooldown. Click to use it; its menu swaps it for another item from your bags." })
    SlotPreview(p)

    W.Card(p, "Slot buttons")
    Chk(p, "Show the slot buttons", nil, "slotbar")
    Sld(p, "Size", "Or Shift + wheel over the bar in the preview.", 20, 64, 1, "slotsize", Px)
    Sld(p, "Spacing", nil, 0, 24, 1, "slotspace", Px)
    Sld(p, "Buttons per row", nil, 1, 19, 1, "slotper")
    Chk(p, "Up and down", "Off: side by side.", "slotvertical")
    Sld(p, "Opacity", nil, .1, 1, .05, "slotalpha", function(v) return math.floor(v * 100 + .5) .. "%" end)
    Chk(p, "Only in combat", nil, "slotcombat")
    Chk(p, "Alt-click in the character window", "Alt-click a slot there puts it on the bar or takes it off.", "altslots")

    W.Card(p, "Clicks and menus", { tip = "Left-click a slot button uses its item. Its menu lists what else can go in." })
    W.Dropdown(p, "Menu opens", nil, { { key = "hover", label = "When the mouse is over it" },
      { key = "right", label = "On right-click" }, { key = "off", label = "Never" } },
      function() return C.gear.slotmenu end, function(v) C.gear.slotmenu = v U() end)
    Chk(p, "Only with Shift held", nil, "slotshift")
    Chk(p, "Right-click uses the item", "When the menu does not open on right-click.", "slotrightuse")
    W.Dropdown(p, "Menu side", nil, { { key = "auto", label = "Towards the middle" }, { key = "TOP", label = "Above" },
      { key = "BOTTOM", label = "Below" }, { key = "LEFT", label = "Left" }, { key = "RIGHT", label = "Right" } },
      function() return C.gear.slotside end, function(v) C.gear.slotside = v U() end)
    Chk(p, "Alt-click hides an item", "Alt-click an item in a menu to hide it there; hold Alt while it opens to see hidden ones.", "allowhidden")
    Chk(p, "Only soulbound items", "Leave out gear you could still trade.", "boundonly")
    W.Buttons(p, { { "Show every hidden item again", function()
      for k in pairs(C.gear.hidden) do C.gear.hidden[k] = nil end
    end, nil, "Clears the items hidden with Alt-click." } })

    W.Card(p, "Cooldowns", { tip = "On the slot buttons and the trinket bar." })
    Chk(p, "Cooldown numbers", nil, "cdnumbers")
    Chk(p, "Seconds from 90 s", "Off: from 60 s.", "cd90")
    Chk(p, "Say when an item is ready", "On the screen, when an item used from a button is ready again.", "notify")
    Chk(p, "Also at 30 s", nil, "notify30")
    Chk(p, "Also in chat", nil, "notifychat")
  end

  O:AddPage("Gear", "gearsets", "Gear sets", Build)
  O:AddPage("Gear", "gearslots", "Slot buttons", BuildSlots)
end)
