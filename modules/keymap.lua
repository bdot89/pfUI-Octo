pfUI:RegisterModule("keymap", "vanilla", function ()
  -- pfUI Octo :: Key Map - a picture of your keyboard with what every key does.
  -- User, 20 Oct 2026 (screenshot of a retail "KeyMap" addon): the Keybinds
  -- button offers the original hover binding or this keyboard layout.
  --
  -- Every key shows its binding: the spell's icon when the key works an
  -- action button (or, with ClassicAPI, casts a spell / uses a macro), else
  -- the binding's name. Layers: base, Shift, Ctrl, Alt (click the modifier
  -- keys or the layer buttons; holding the modifier shows that layer too).
  --   drop a spell / item / macro on a key  -> bind it (an action button key
  --                                            gets it on its button)
  --   left-click a key                      -> pick its binding up; click
  --                                            another key to move / swap
  --   right-click                           -> unbind
  --   Unbound abilities                     -> action bar buttons with no key:
  --                                            click one, then a key
  -- Client facts (WoW.exe strings): SetBinding / GetBindingAction /
  -- GetBindingKey / SaveBindings / GetCurrentBindingSet / PickupAction /
  -- PlaceAction / CursorHasSpell / CursorHasItem / ClearCursor. ClassicAPI.dll
  -- adds GetCursorInfo, SetBindingSpell / Item / Macro ("Usage:" strings in the
  -- DLL); its returns follow retail's and are not verified on this client.

  local OU = pfUI.octoui
  local W = OU and OU.W
  if not W then return end
  local K = W.C

  local KM = { layer = "", keys = {}, cells = {} }
  pfUI.keymap = KM

  -- ---------------------------------------------------------------- what keys do

  -- action button binding commands -> action slot (Blizzard's bar layout,
  -- the same pfUI's bars use: actionbar.lua bar ids)
  local BARS = { ACTIONBUTTON = 0, MULTIACTIONBAR1BUTTON = 60, MULTIACTIONBAR2BUTTON = 48,
                 MULTIACTIONBAR3BUTTON = 24, MULTIACTIONBAR4BUTTON = 36 }
  function KM.SlotOf(action)
    if not action then return nil end
    local _, _, cmd, n = string.find(action, "^(%u+%d?%u+)(%d+)$")
    n = tonumber(n)
    if cmd and n and BARS[cmd] and n >= 1 and n <= 12 then return BARS[cmd] + n end
    return nil
  end
  function KM.CommandOf(slot)
    for cmd, base in pairs(BARS) do
      if slot > base and slot <= base + 12 then return cmd .. (slot - base) end
    end
    return nil
  end

  -- What spell sits on an action button, and its rank: 1.12 has no
  -- GetActionInfo, so the button's tooltip is read on a hidden tooltip
  -- (line 1 left = name, line 1 right = "Rank 3").
  local scan
  function KM.ActionSpell(slot)
    if not slot or not HasAction(slot) then return nil end
    if not scan then
      scan = CreateFrame("GameTooltip", "pfKeyMapScan", nil, "GameTooltipTemplate")
    end
    scan:SetOwner(WorldFrame, "ANCHOR_NONE")
    scan:ClearLines()
    scan:SetAction(slot)
    local l, r = getglobal("pfKeyMapScanTextLeft1"), getglobal("pfKeyMapScanTextRight1")
    local name = l and l:IsShown() ~= false and l:GetText()
    local rank = r and r:IsShown() and r:GetText()
    if rank == "" then rank = nil end
    scan:Hide()
    return name, rank
  end

  -- every rank of a spell in the spellbook: { { index, rank }, ... } low to high
  function KM.SpellRanks(name)
    local out = {}
    if not name or not GetSpellName then return out end
    local i = 1
    while i <= 1024 do -- (bounded: a client that never says "no more" froze, 1 Nov 2026)
      local n, r = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not n then break end
      if n == name then table.insert(out, { i, (r and r ~= "") and r or nil }) end
      i = i + 1
    end
    return out
  end

  -- Which rank? (user, 20 Oct 2026: "a rank selector when you click on a
  -- spell"). A menu of the spell's ranks beside anchor; the picked rank is
  -- put on the action button (PickupSpell + PlaceAction, the old one taken
  -- off the cursor again). after() runs once a rank is on the button - at
  -- once when the spell has one rank or the button holds no spell.
  KM.rankMenus = {}
  function KM.PickRank(slot, anchor, after)
    local name, cur = KM.ActionSpell(slot)
    if table.getn(KM.SpellRanks(name)) < 2 then
      if after then after() end
      return false
    end
    return KM.RankMenu(name, cur, anchor, function(index)
      PickupSpell(index, BOOKTYPE_SPELL or "spell")
      PlaceAction(slot)
      ClearCursor()
      if after then after() end
      KM:Refresh()
    end)
  end

  -- the rank menu itself: onPick(spellbook index); cur = the rank in use now
  function KM.RankMenu(name, cur, anchor, onPick)
    local ranks = KM.SpellRanks(name)
    local opts = { { label = name .. " - which rank?", group = true } }
    local n = table.getn(ranks)
    for i = n, 1, -1 do
      local r = ranks[i]
      local label = r[2] or ("Rank " .. i)
      if i == n then label = label .. "  |cff999999(highest)|r" end
      if r[2] and r[2] == cur then label = label .. "  |cff33ccff(on the button)|r" end
      table.insert(opts, { key = r[1], label = label })
    end
    if KM.rankMenu then KM.rankMenu:Hide() end
    local menu = W.Menu(anchor, opts, 220, onPick)
    menu:SetFrameStrata("TOOLTIP")
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
    menu:Show()
    KM.rankMenu = menu
    return true
  end

  local function SpellTexture(name)
    if not name or not GetSpellName then return nil end
    local i = 1
    while i <= 1024 do
      local n = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not n then return nil end
      if n == name then return GetSpellTexture(i, BOOKTYPE_SPELL or "spell") end
      i = i + 1
    end
  end

  -- icon and short name of a binding command
  function KM.Describe(action)
    if not action or action == "" then return nil, nil end
    -- the gear slot buttons (pfUI.gear.UseSlot): the worn item's picture
    local _, _, ginv = string.find(action, "^PFGEARSLOT(%d+)$")
    if ginv then
      ginv = tonumber(ginv)
      local link = GetInventoryItemLink("player", ginv)
      local _, _, iname = string.find(link or "", "%[(.-)%]")
      return (pfUI.gear and pfUI.gear.InvTex and pfUI.gear.InvTex(ginv) or GetInventoryItemTexture("player", ginv)), iname or ((GetBindingText and GetBindingText(action, "BINDING_NAME_")) or action)
    end
    local slot = KM.SlotOf(action)
    if slot then
      local tex = HasAction(slot) and GetActionTexture(slot)
      local text = GetActionText and GetActionText(slot)
      if tex and not text then
        -- a spell or item: its name and rank ("Fireball (Rank 3)")
        local n, r = KM.ActionSpell(slot)
        if n then text = n .. (r and (" (" .. r .. ")") or "") end
      end
      return tex, text or (GetBindingText and GetBindingText(action, "BINDING_NAME_")) or action
    end
    local _, _, kind, what = string.find(action, "^(%u+) (.+)$")
    if kind == "SPELL" then
      local name = string.gsub(what, "%(.-%)$", "")
      return SpellTexture(name), name
    elseif kind == "MACRO" then
      local idx = GetMacroIndexByName and GetMacroIndexByName(what)
      if idx and idx > 0 then
        local name, tex = GetMacroInfo(idx)
        return tex, name
      end
      return nil, what
    elseif kind == "ITEM" then
      return nil, what
    end
    return nil, (GetBindingText and GetBindingText(action, "BINDING_NAME_")) or action
  end

  local function Save()
    SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
    KM:Refresh()
  end

  -- ---------------------------------------------------------------- layouts

  -- rows of { label, key name (nil = not bindable / a modifier), width in units }
  local function Row(list) return list end
  local LETTERS = {
    uk = { "QWERTYUIOP[]", "ASDFGHJKL;'#", "\\ZXCVBNM,./" },
    us = { "QWERTYUIOP[]\\", "ASDFGHJKL;'", "ZXCVBNM,./" },
    de = { "QWERTZUIOP[]", "ASDFGHJKL;'#", "<YXCVBNM,./" },
    fr = { "AZERTYUIOP[]", "QSDFGHJKLM'#", "<WXCVBN,;:!" },
  }
  KM.LAYOUTS = { { key = "uk", label = "English QWERTY (UK)" }, { key = "us", label = "English QWERTY (US)" },
                 { key = "de", label = "Deutsch QWERTZ" }, { key = "fr", label = "Français AZERTY" } }

  local function Chars(s)
    local out = {}
    for ch in string.gfind(s, ".") do table.insert(out, { ch, ch, 1 }) end
    return out
  end

  function KM.Rows(layout)
    local L = LETTERS[layout] or LETTERS.uk
    local rows = {}
    local f = { { "Esc", nil, 1 }, { "", nil, .5 } }
    for i = 1, 12 do
      table.insert(f, { "F" .. i, "F" .. i, 1 })
      if i == 4 or i == 8 then table.insert(f, { "", nil, .5 }) end
    end
    table.insert(rows, f)
    local num = { { "`", "`", 1 } }
    for _, d in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }) do table.insert(num, { d, d, 1 }) end
    table.insert(num, { "Back", "BACKSPACE", 2 })
    table.insert(rows, num)
    local r1 = { { "Tab", "TAB", 1.5 } }
    for _, c in ipairs(Chars(L[1])) do table.insert(r1, c) end
    if layout ~= "us" then table.insert(r1, { "Enter", "ENTER", 1.5 }) end
    table.insert(rows, r1)
    local r2 = { { "Caps", "CAPSLOCK", 1.75 } }
    for _, c in ipairs(Chars(L[2])) do table.insert(r2, c) end
    if layout == "us" then table.insert(r2, { "Enter", "ENTER", 2.25 }) end
    table.insert(rows, r2)
    local r3 = { { "Shift", "*SHIFT", (layout == "us") and 2.25 or 1.25 } }
    for _, c in ipairs(Chars(L[3])) do table.insert(r3, c) end
    table.insert(r3, { "Shift", "*SHIFT", 2.75 })
    table.insert(rows, r3)
    table.insert(rows, { { "Ctrl", "*CTRL", 1.5 }, { "", nil, 1 }, { "Alt", "*ALT", 1.5 }, { "Space", "SPACE", 6.5 },
                         { "Alt", "*ALT", 1.5 }, { "", nil, 1 }, { "Ctrl", "*CTRL", 1.5 } })
    table.insert(rows, { { "Mouse 3", "BUTTON3", 2 }, { "Mouse 4", "BUTTON4", 2 }, { "Mouse 5", "BUTTON5", 2 },
                         { "Wheel Up", "MOUSEWHEELUP", 2 }, { "Wheel Down", "MOUSEWHEELDOWN", 2 } })
    return rows
  end

  -- ---------------------------------------------------------------- the window

  local UNIT, GAP, PAD = 50, 4, 14
  local PANEL_W = 330

  local function Full(key)
    if not key then return nil end
    return KM.layer .. key
  end

  local function Tip(b)
    local key = Full(b.key)
    local action = GetBindingAction(key)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    local slot = KM.SlotOf(action)
    local sname, srank = KM.ActionSpell(slot)
    if sname then
      -- the spell on the key's button, with its rank
      GameTooltip:AddDoubleLine(sname, srank or "", 1, 1, 1, K.accent[1], K.accent[2], K.accent[3])
      local ranks = table.getn(KM.SpellRanks(sname))
      if ranks > 1 then GameTooltip:AddLine(ranks .. " ranks known - middle-click this key to pick another", .6, .6, .6) end
    else
      local _, name = KM.Describe(action)
      GameTooltip:AddLine(name or "Not bound", 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Key", key, .6, .6, .6, 1, 1, 1)
    if action and action ~= "" then GameTooltip:AddDoubleLine("Binding", action, .6, .6, .6, 1, 1, 1) end
    GameTooltip:AddLine("Drop a spell, item or macro to bind it. Left-click: pick up / move / swap. Right-click: unbind.",
      K.accent[1], K.accent[2], K.accent[3], 1)
    GameTooltip:Show()
  end

  local function CursorHasSomething()
    if CursorHasSpell and CursorHasSpell() then return true end
    if CursorHasItem and CursorHasItem() then return true end
    if GetCursorInfo and GetCursorInfo() then return true end
    return false
  end

  -- a free action slot on a bar (for a dropped spell on an unbound key)
  local function FreeSlot()
    for _, base in ipairs({ 0, 60, 48, 24, 36 }) do
      for n = 1, 12 do
        if not HasAction(base + n) then return base + n end
      end
    end
    return nil
  end

  -- whatever is on the cursor goes onto this key
  function KM.Drop(key)
    key = Full(key)
    local action = GetBindingAction(key)
    local slot = KM.SlotOf(action)
    if slot then
      -- an action button key: the spell goes on its button (what was there
      -- comes back onto the cursor, as dragging between buttons does)
      PlaceAction(slot)
      Save()
      return true
    end
    if GetCursorInfo then
      local kind, a, b = GetCursorInfo()
      local done
      if kind == "spell" and SetBindingSpell and GetSpellName then
        local name = GetSpellName(a, b or BOOKTYPE_SPELL or "spell")
        if name then SetBindingSpell(key, name) done = true end
      elseif kind == "item" and SetBindingItem then
        local _, _, name = string.find(tostring(b or ""), "%[(.-)%]")
        if not name and GetItemInfo then name = GetItemInfo(a) end
        if name then SetBindingItem(key, name) done = true end
      elseif kind == "macro" and SetBindingMacro then
        SetBindingMacro(key, a)
        done = true
      end
      if done then
        ClearCursor()
        Save()
        return true
      end
    end
    -- no ClassicAPI: put it on a free action button and bind the key to it
    local free = FreeSlot()
    if free then
      PlaceAction(free)
      SetBinding(key, KM.CommandOf(free))
      Save()
      return true
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: no free action button to put it on - free one up first.")
    return false
  end

  local function KeyClick()
    local b = this
    if b.modifier then
      KM.locked = (KM.layer == b.modifier .. "-") and "" or (b.modifier .. "-")
      KM.layer = KM.locked
      KM:Refresh()
      return
    end
    if not b.key then return end
    local key = Full(b.key)
    if arg1 == "MiddleButton" then
      -- another rank of the spell on this key's button
      local slot = KM.SlotOf(GetBindingAction(key))
      if slot then KM.PickRank(slot, b) end
      return
    end
    if arg1 == "RightButton" then
      SetBinding(key)
      KM.picked, KM.pickedAction = nil, nil
      Save()
      return
    end
    if CursorHasSomething() then
      KM.Drop(b.key)
      return
    end
    if KM.spell then
      -- a spell (and rank) picked in the spell book: onto this key
      KM.GiveSpell(b.key, KM.spell)
      return
    end
    if KM.command then
      -- a command picked in All bindings: this key works it
      SetBinding(key, KM.command)
      KM.command = nil
      Save()
      return
    end
    if KM.ability then
      -- an unbound ability picked on the right: this key works its button
      SetBinding(key, KM.CommandOf(KM.ability))
      KM.ability = nil
      Save()
      return
    end
    if KM.picked then
      if KM.picked ~= key then
        local mine = GetBindingAction(key)
        SetBinding(key, KM.pickedAction)
        if mine and mine ~= "" then SetBinding(KM.picked, mine) else SetBinding(KM.picked) end
      end
      KM.picked, KM.pickedAction = nil, nil
      Save()
      return
    end
    local action = GetBindingAction(key)
    if action and action ~= "" then
      KM.picked, KM.pickedAction = key, action
      KM:Refresh()
    end
  end

  local function MakeKey(parent)
    local b = CreateFrame("Button", nil, parent)
    W.Flat(b, K.field, 1, K.line)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    W.Hover(b, .08)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.icon:SetAlpha(.85)
    b.label = W.Font(b:CreateFontString(nil, "OVERLAY"), 11, 1, 1, 1)
    b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -3)
    b.what = W.Font(b:CreateFontString(nil, "OVERLAY"), 9, K.dim[1], K.dim[2], K.dim[3])
    b.what:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 3)
    b.what:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.what:SetJustifyH("CENTER")
    b.what:SetHeight(11)
    b:SetScript("OnClick", KeyClick)
    b:SetScript("OnReceiveDrag", function() if this.key then KM.Drop(this.key) end end)
    b:SetScript("OnEnter", function() if this.key then Tip(this) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end

  function KM:Build()
    local f = CreateFrame("Frame", "pfKeyMap", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    W.Flat(f, K.bg, .97, K.lineHi)
    f:Hide()
    table.insert(UISpecialFrames, "pfKeyMap")
    f:SetScript("OnMouseDown", function() this:StartMoving() end)
    f:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
    f:SetScript("OnShow", function() KM:Refresh() end)
    f:SetScript("OnHide", function()
      KM.picked, KM.ability, KM.command, KM.spell = nil, nil, nil, nil
      W.CloseMenus()
    end)
    -- holding a modifier shows its layer (when no layer is clicked on)
    f:SetScript("OnUpdate", function()
      if KM.locked and KM.locked ~= "" then return end
      local l = (IsShiftKeyDown() and "SHIFT-") or (IsControlKeyDown() and "CTRL-") or (IsAltKeyDown() and "ALT-") or ""
      if l ~= KM.layer then
        KM.layer = l
        KM:Refresh()
      end
    end)
    self.frame = f

    local title = W.Font(f:CreateFontString(nil, "OVERLAY"), 15, K.text[1], K.text[2], K.text[3])
    title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -10)
    title:SetText("|cff33ccffKey|r Map")
    self.layerText = W.Font(f:CreateFontString(nil, "OVERLAY"), 15, K.text[1], K.text[2], K.text[3])
    self.layerText:SetPoint("TOP", f, "TOP", -PANEL_W / 2, -10)
    local close = W.Button(f, "X", 22, 22)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    close:SetScript("OnClick", function() f:Hide() end)

    -- tool bar: keyboard layout, layers, unbound list, hover binding
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -36)
    bar:SetHeight(24)
    bar:SetWidth(600)
    local lay, layRefresh = W.MiniDrop(bar, 170, KM.LAYOUTS, function() return KM.Store().layout or "uk" end,
      function(v) KM.Store().layout = v KM:Layout() end, 190)
    lay:SetPoint("LEFT", bar, "LEFT", 0, 0)
    self.layRefresh = layRefresh
    local x = 180
    self.layerButtons = {}
    for _, l in ipairs({ { "", "Base" }, { "SHIFT-", "Shift" }, { "CTRL-", "Ctrl" }, { "ALT-", "Alt" } }) do
      local b = W.Button(bar, l[2], 58, 22)
      b:SetPoint("LEFT", bar, "LEFT", x, 0)
      b.layer = l[1]
      b:SetScript("OnClick", function()
        KM.locked = this.layer
        KM.layer = this.layer
        KM:Refresh()
      end)
      table.insert(self.layerButtons, b)
      x = x + 62
    end
    local unb = W.Button(bar, "Lists", 70, 22)
    unb:SetPoint("LEFT", bar, "LEFT", x + 10, 0)
    unb:SetScript("OnClick", function()
      KM.Store().hidePanel = not KM.Store().hidePanel
      KM:Layout()
    end)
    W.Tip(unb, "Lists", "Show or hide the lists on the right: unbound abilities and every binding.")
    local quick = W.Button(bar, "Quick Keybind", 110, 22)
    quick:SetPoint("LEFT", unb, "RIGHT", 6, 0)
    quick:SetScript("OnClick", function()
      f:Hide()
      if pfUI.hoverbind then pfUI.hoverbind:Show() end
    end)
    W.Tip(quick, "Quick Keybind", "pfUI's hover binding: hover an action button and press a key.")

    self.board = CreateFrame("Frame", nil, f)
    self.board:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -70)

    -- the lists on the right: unbound abilities | all bindings (user, 20 Oct
    -- 2026: two tabs with pictures, both dragged onto keys)
    local panel = CreateFrame("Frame", nil, f)
    panel:SetWidth(PANEL_W)
    panel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -70)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 30)
    W.Flat(panel, K.panel, 1, K.line)
    self.panel = panel
    self.abilities = {}
    self.tabs = {}
    local tw = (PANEL_W - 28) / 3
    for i, t in ipairs({ { "unbound", "Unbound", "INV_Misc_Key_01" }, { "spells", "Spell book", "INV_Misc_Book_11" },
        { "all", "All bindings", "INV_Misc_Book_09" } }) do
      local b = W.Button(panel, "", tw, 28)
      b:SetPoint("TOPLEFT", panel, "TOPLEFT", 8 + (i - 1) * (tw + 6), -8)
      local ic = b:CreateTexture(nil, "ARTWORK")
      ic:SetTexture("Interface\\Icons\\" .. t[3])
      ic:SetTexCoord(.08, .92, .08, .92)
      ic:SetWidth(20)
      ic:SetHeight(20)
      ic:SetPoint("LEFT", b, "LEFT", 5, 0)
      b.label:ClearAllPoints()
      b.label:SetPoint("LEFT", ic, "RIGHT", 6, 0)
      b:SetText(t[2])
      b.tab = t[1]
      b:SetScript("OnClick", function()
        KM.Store().tab = this.tab
        KM.ability, KM.command, KM.spell = nil, nil, nil
        KM:Refresh()
      end)
      self.tabs[i] = b
    end
    self.hint = W.Font(panel:CreateFontString(nil, "OVERLAY"), 10, K.dim[1], K.dim[2], K.dim[3])
    self.hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 9, -42)
    self.hint:SetWidth(PANEL_W - 18)
    self.hint:SetJustifyH("LEFT")
    self.hint:SetSpacing(2)
    -- every binding: folding categories in a scroll list
    local sf = CreateFrame("ScrollFrame", "pfKeyMapList", panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -72)
    sf:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -18, 6)
    W.FlatScroll(sf)
    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(PANEL_W - 26)
    content:SetHeight(10)
    sf:SetScrollChild(content)
    self.listScroll, self.list = sf, content
    self.listRows, self.listHeads = {}, {}
    -- the whole spell book: a picture grid per spell book tab
    local ss = CreateFrame("ScrollFrame", "pfKeyMapSpells", panel, "UIPanelScrollFrameTemplate")
    ss:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -72)
    ss:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -18, 6)
    W.FlatScroll(ss)
    local sc = CreateFrame("Frame", nil, ss)
    sc:SetWidth(PANEL_W - 26)
    sc:SetHeight(10)
    ss:SetScrollChild(sc)
    self.spellScroll, self.spellList = ss, sc
    self.spellIcons, self.spellHeads = {}, {}

    local help = W.Font(f:CreateFontString(nil, "OVERLAY"), 10, K.dim[1], K.dim[2], K.dim[3])
    help:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 10)
    help:SetText("Drag spells, macros, items - or anything from the lists on the right - onto keys  |  Click a key to pick it up, click another to move / swap  |  "
      .. "Right-click unbinds  |  Hold or click Shift / Ctrl / Alt for their layers")
    self:Layout()
  end

  function KM.Store()
    local s = OU.Store()
    if type(s.keymap) ~= "table" then s.keymap = {} end
    return s.keymap
  end

  -- places the keys for the chosen keyboard and sizes the window
  function KM:Layout()
    if not self.frame then return end
    for _, c in ipairs(self.cells) do c:Hide() end
    local rows = KM.Rows(KM.Store().layout or "uk")
    local n, maxw, y = 0, 0, 0
    for r, row in ipairs(rows) do
      local x = 0
      if r == 2 or r == table.getn(rows) then y = y + 8 end
      for _, k in ipairs(row) do
        local w = k[3] * UNIT + (k[3] - 1) * GAP
        if k[2] or k[1] ~= "" then
          n = n + 1
          local b = self.cells[n] or MakeKey(self.board)
          self.cells[n] = b
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", self.board, "TOPLEFT", x, -y)
          b:SetWidth(w)
          b:SetHeight(UNIT - 6)
          b.text = k[1]
          b.label:SetText(k[1])
          b.modifier = nil
          b.key = nil
          if k[2] and string.sub(k[2], 1, 1) == "*" then
            b.modifier = string.sub(k[2], 2)
          else
            b.key = k[2]
          end
          b:Show()
        end
        x = x + w + GAP
      end
      if x > maxw then maxw = x end
      y = y + UNIT - 6 + GAP
    end
    self.board:SetWidth(maxw)
    self.board:SetHeight(y)
    local panel = not KM.Store().hidePanel
    if panel then self.panel:Show() else self.panel:Hide() end
    self.frame:SetWidth(PAD * 2 + maxw + (panel and (PANEL_W + 12) or 0))
    self.frame:SetHeight(70 + y + 34)
    if self.layRefresh then self.layRefresh() end
    self:Refresh()
  end

  local NAMES = { [""] = "Base layer", ["SHIFT-"] = "Shift layer", ["CTRL-"] = "Ctrl layer", ["ALT-"] = "Alt layer" }

  function KM:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self.layerText:SetText(NAMES[self.layer] or "")
    for _, b in ipairs(self.layerButtons) do W.Pick(b, b.layer == self.layer) end
    for _, b in ipairs(self.cells) do
      if b:IsShown() then
        local key = b.key and Full(b.key)
        local action = key and GetBindingAction(key)
        local tex, name = KM.Describe(action)
        b.icon:SetTexture(tex)
        if tex then b.icon:Show() else b.icon:Hide() end
        b.what:SetText(b.key and (tex and "" or (name or "")) or "")
        local col, line = K.field, K.line
        if b.modifier then
          col = (self.layer == b.modifier .. "-") and K.head or K.btn
          line = (self.layer == b.modifier .. "-") and K.accent or K.line
        elseif not b.key then
          col = K.panel
        elseif action and action ~= "" then
          col, line = K.card, K.lineHi
        end
        if key and key == self.picked then line = { 1, .82, 0 } end
        b:SetBackdropColor(col[1], col[2], col[3], 1)
        b:SetBackdropBorderColor(line[1], line[2], line[3], 1)
        if b.key or b.modifier then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(K.dim[1], K.dim[2], K.dim[3]) end
      end
    end
    self:RefreshPanel()
  end

  -- action bar buttons with a spell / item / macro and no key
  function KM.Unbound()
    local out = {}
    for _, base in ipairs({ 0, 60, 48, 24, 36 }) do
      for n = 1, 12 do
        local slot = base + n
        if HasAction(slot) then
          local cmd = KM.CommandOf(slot)
          if cmd and not GetBindingKey(cmd) then table.insert(out, slot) end
        end
      end
    end
    -- the gear slot buttons on screen with no key (user, 24 Oct 2026)
    local GR = pfUI.gear
    local seen = {}
    for _, b in ipairs(GR and GR.bindables or {}) do
      if b.pfBinding and not seen[b.pfBinding] and b:IsVisible() and not GetBindingKey(b.pfBinding)
        and GR.InvTex(b.inv) then
        seen[b.pfBinding] = true
        table.insert(out, { cmd = b.pfBinding, inv = b.inv })
      end
    end
    return out
  end

  -- ---------------------------------------------------------------- drag and drop

  -- Our own drag (these are not things the game's cursor can carry): a
  -- picture follows the mouse; let go over a key and that key gets it.
  -- payload: { slot = n } (an action button) or { cmd = "COMMAND" }
  function KM.Give(key, payload)
    if not key or not payload then return end
    local cmd = payload.cmd or (payload.slot and KM.CommandOf(payload.slot))
    if not cmd then return end
    SetBinding(Full(key), cmd)
    KM.ability, KM.command = nil, nil
    Save()
  end

  local function Ghost()
    if KM.ghost then return KM.ghost end
    local g = CreateFrame("Frame", nil, UIParent)
    g:SetFrameStrata("TOOLTIP")
    g:SetWidth(34)
    g:SetHeight(34)
    W.Flat(g, K.field, 1, K.accent)
    g.icon = g:CreateTexture(nil, "ARTWORK")
    g.icon:SetPoint("TOPLEFT", g, "TOPLEFT", 2, -2)
    g.icon:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -2, 2)
    g:SetScript("OnUpdate", function()
      local x, y = GetCursorPosition()
      local s = UIParent:GetEffectiveScale()
      this:ClearAllPoints()
      this:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s + 14, y / s - 14)
    end)
    g:Hide()
    KM.ghost = g
    return g
  end

  local function DragStart()
    local p = this.payload
    if not p then return end
    KM.dragging = p
    local g = Ghost()
    g.icon:SetTexture(this.tex or "Interface\\Icons\\INV_Misc_Key_03")
    if this.coords then g.icon:SetTexCoord(this.coords[1], this.coords[2], this.coords[3], this.coords[4])
    else g.icon:SetTexCoord(.08, .92, .08, .92) end
    g:Show()
  end

  -- the key under the mouse when the drag ends
  function KM.KeyUnderMouse()
    for _, c in ipairs(KM.cells) do
      if c:IsShown() and c.key and MouseIsOver(c) then return c.key end
    end
    return nil
  end

  local function DragStop()
    local p = KM.dragging
    KM.dragging = nil
    this.justDragged = true
    if KM.ghost then KM.ghost:Hide() end
    if p and p.spell then KM.GiveSpell(KM.KeyUnderMouse(), p.spell)
    elseif p then KM.Give(KM.KeyUnderMouse(), p) end
  end

  -- a spell book spell (index = that rank) onto a key: as if dragged from
  -- the spell book (an action key's button takes it, else the key binds it)
  function KM.GiveSpell(key, index)
    KM.spell = nil
    if not key or not index then KM:Refresh() return end
    PickupSpell(index, BOOKTYPE_SPELL or "spell")
    KM.Drop(key)
    ClearCursor()
    KM:Refresh()
  end

  local function Draggable(b)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", DragStart)
    b:SetScript("OnDragStop", DragStop)
    -- the mouse-up ending a drag is not a click
    b:SetScript("OnMouseDown", function() this.justDragged = nil end)
  end

  -- ---------------------------------------------------------------- the lists

  local HINT = {
    unbound = "Action bar buttons with no key. Click one to choose its |cffffffffrank|r, then click a key - or |cffffffffdrag it onto a key|r.",
    all = "Every command, in categories. Open one, then |cffffffffdrag a command onto a key|r - or click it, then a key.",
    spells = "Every spell you know. Click one to choose its |cffffffffrank|r, then click a key - or |cffffffffdrag it onto a key|r (highest rank).",
  }

  function KM:RefreshPanel()
    if not self.panel:IsShown() then return end
    local tab = KM.Store().tab or "unbound"
    for _, b in ipairs(self.tabs) do W.Pick(b, b.tab == tab) end
    self.hint:SetText(HINT[tab])
    if tab ~= "unbound" then for _, a in ipairs(self.abilities) do a:Hide() end end
    if tab == "all" then self.listScroll:Show() else self.listScroll:Hide() end
    if tab == "spells" then self.spellScroll:Show() else self.spellScroll:Hide() end
    if tab == "all" then
      self:RefreshList()
    elseif tab == "spells" then
      self:RefreshSpells()
    else
      self:RefreshAbilities()
    end
  end

  -- every spell in the spell book, once per name (its highest rank),
  -- passives left out: { { tab name, tab icon, { { index, name, tex }, ... } }, ... }
  function KM.SpellBook()
    local out = {}
    if not GetNumSpellTabs or not GetSpellTabInfo then return out end
    local book = BOOKTYPE_SPELL or "spell"
    for t = 1, GetNumSpellTabs() do
      local tname, ttex, offset, num = GetSpellTabInfo(t)
      local list, at = {}, {}
      for i = offset + 1, offset + num do
        local n = GetSpellName(i, book)
        if n and not (IsPassiveSpell and IsPassiveSpell(i, book)) then
          if at[n] then list[at[n]][1] = i
          else
            table.insert(list, { i, n, GetSpellTexture(i, book) })
            at[n] = table.getn(list)
          end
        end
      end
      if table.getn(list) > 0 then table.insert(out, { tname, ttex, list }) end
    end
    return out
  end

  local function SpellIcon(parent)
    local a = CreateFrame("Button", nil, parent)
    a:SetWidth(36)
    a:SetHeight(36)
    W.Flat(a, K.field, 1, K.line)
    a.icon = a:CreateTexture(nil, "ARTWORK")
    a.icon:SetTexCoord(.08, .92, .08, .92)
    a.icon:SetPoint("TOPLEFT", a, "TOPLEFT", 2, -2)
    a.icon:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -2, 2)
    W.Hover(a, .15)
    Draggable(a)
    a:SetScript("OnClick", function()
      if this.justDragged then this.justDragged = nil return end
      KM.ability, KM.command = nil, nil
      if KM.spell and KM.SpellRanksHas(this.name, KM.spell) then
        KM.spell = nil
        KM:Refresh()
        return
      end
      local top = this.index
      if table.getn(KM.SpellRanks(this.name)) < 2 then
        KM.spell = top
        KM:Refresh()
        return
      end
      KM.RankMenu(this.name, nil, this, function(index)
        KM.spell = index
        KM:Refresh()
      end)
    end)
    a:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:SetSpell(this.index, BOOKTYPE_SPELL or "spell")
      local ranks = table.getn(KM.SpellRanks(this.name))
      GameTooltip:AddLine((ranks > 1 and "Click to choose the rank, then click a key" or "Click, then click a key")
        .. " - or drag it onto a key.", K.accent[1], K.accent[2], K.accent[3])
      GameTooltip:Show()
    end)
    a:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return a
  end

  -- is index one of name's ranks (the picked spell's picture stays lit)
  function KM.SpellRanksHas(name, index)
    for _, r in ipairs(KM.SpellRanks(name)) do if r[1] == index then return true end end
    return false
  end

  function KM:RefreshSpells()
    for _, a in ipairs(self.spellIcons) do a:Hide() end
    for _, h in ipairs(self.spellHeads) do h:Hide() end
    local size = 36
    local per = math.floor((PANEL_W - 26) / (size + 6))
    local y, n = 0, 0
    for t, tab in ipairs(KM.SpellBook()) do
      local h = self.spellHeads[t]
      if not h then
        h = CreateFrame("Frame", nil, self.spellList)
        h:SetHeight(20)
        h:SetWidth(PANEL_W - 26)
        h.icon = h:CreateTexture(nil, "ARTWORK")
        h.icon:SetTexCoord(.08, .92, .08, .92)
        h.icon:SetWidth(16)
        h.icon:SetHeight(16)
        h.icon:SetPoint("LEFT", h, "LEFT", 2, 0)
        h.text = W.Font(h:CreateFontString(nil, "OVERLAY"), 11, K.accent[1], K.accent[2], K.accent[3])
        h.text:SetPoint("LEFT", h.icon, "RIGHT", 6, 0)
        self.spellHeads[t] = h
      end
      h.icon:SetTexture(tab[2])
      h.text:SetText(tab[1])
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", self.spellList, "TOPLEFT", 0, -y)
      h:Show()
      y = y + 22
      local count = table.getn(tab[3])
      for i, s in ipairs(tab[3]) do
        n = n + 1
        local a = self.spellIcons[n] or SpellIcon(self.spellList)
        self.spellIcons[n] = a
        a.index, a.name, a.tex = s[1], s[2], s[3]
        a.payload = { spell = s[1] }
        a.icon:SetTexture(s[3])
        local row, col = math.floor((i - 1) / per), math.mod(i - 1, per)
        a:ClearAllPoints()
        a:SetPoint("TOPLEFT", self.spellList, "TOPLEFT", 2 + col * (size + 6), -y - row * (size + 6))
        local l = (KM.spell and KM.SpellRanksHas(s[2], KM.spell)) and K.accent or K.line
        a:SetBackdropBorderColor(l[1], l[2], l[3], 1)
        a:Show()
      end
      y = y + math.ceil(count / per) * (size + 6) + 6
    end
    self.spellList:SetHeight(math.max(10, y))
    self.spellScroll:UpdateScrollChildRect()
  end

  function KM:RefreshAbilities()
    for _, a in ipairs(self.abilities) do a:Hide() end
    local size = 36
    local per = math.floor((PANEL_W - 10) / (size + 6))
    for i, slot in ipairs(KM.Unbound()) do
      local a = self.abilities[i]
      if not a then
        a = CreateFrame("Button", nil, self.panel)
        a:SetWidth(size)
        a:SetHeight(size)
        W.Flat(a, K.field, 1, K.line)
        a.icon = a:CreateTexture(nil, "ARTWORK")
        a.icon:SetTexCoord(.08, .92, .08, .92)
        a.icon:SetPoint("TOPLEFT", a, "TOPLEFT", 2, -2)
        a.icon:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -2, 2)
        W.Hover(a, .15)
        Draggable(a)
        a:SetScript("OnClick", function()
          if this.justDragged then this.justDragged = nil return end
          if this.cmd then
            -- a gear slot button: picked, then click a key
            KM.ability = nil
            KM.command = (KM.command ~= this.cmd) and this.cmd or nil
            KM:Refresh()
            return
          end
          KM.command = nil
          if KM.ability == this.slot then
            KM.ability = nil
            KM:Refresh()
            return
          end
          -- a spell with several ranks asks which one first, then it is picked
          local slot = this.slot
          KM.PickRank(slot, this, function()
            KM.ability = slot
            KM:Refresh()
          end)
        end)
        a:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_LEFT")
          if this.cmd then
            GameTooltip:SetInventoryItem("player", this.inv)
            GameTooltip:AddLine("Gear slot button. Click, then click a key - or drag it onto a key.", K.accent[1], K.accent[2], K.accent[3])
          else
            GameTooltip:SetAction(this.slot)
            GameTooltip:AddLine("Click to choose the rank, then click a key - or drag it onto a key.", K.accent[1], K.accent[2], K.accent[3])
          end
          GameTooltip:Show()
        end)
        a:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.abilities[i] = a
      end
      if type(slot) == "table" then
        a.slot, a.cmd, a.inv = nil, slot.cmd, slot.inv
        a.payload = { cmd = slot.cmd }
        a.tex = pfUI.gear.InvTex(slot.inv)
      else
        a.slot, a.cmd, a.inv = slot, nil, nil
        a.payload = { slot = slot }
        a.tex = GetActionTexture(slot)
      end
      a.icon:SetTexture(a.tex)
      local row, col = math.floor((i - 1) / per), math.mod(i - 1, per)
      a:ClearAllPoints()
      a:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 8 + col * (size + 6), -76 - row * (size + 6))
      local l = ((a.slot and KM.ability == a.slot) or (a.cmd and KM.command == a.cmd)) and K.accent or K.line
      a:SetBackdropBorderColor(l[1], l[2], l[3], 1)
      a:Show()
    end
  end

  local LROW, LHEAD = 22, 26

  local function ListHead(parent)
    local h = CreateFrame("Button", nil, parent)
    h:SetHeight(LHEAD - 2)
    h:SetWidth(PANEL_W - 26)
    W.Flat(h, K.head, 1, K.line)
    W.Hover(h, .05)
    h.arrow = W.Arrow(h, 8, "right")
    h.arrow:SetPoint("LEFT", h, "LEFT", 6, 0)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetWidth(18)
    h.icon:SetHeight(18)
    h.icon:SetPoint("LEFT", h, "LEFT", 18, 0)
    h.text = W.Font(h:CreateFontString(nil, "OVERLAY"), 11, K.text[1], K.text[2], K.text[3])
    h.text:SetPoint("LEFT", h.icon, "RIGHT", 6, 0)
    h.text:SetPoint("RIGHT", h, "RIGHT", -26, 0)
    h.text:SetJustifyH("LEFT")
    h.count = W.Font(h:CreateFontString(nil, "OVERLAY"), 10, K.dim[1], K.dim[2], K.dim[3])
    h.count:SetPoint("RIGHT", h, "RIGHT", -6, 0)
    h:SetScript("OnClick", function()
      local o = KM.Store()
      if type(o.open) ~= "table" then o.open = {} end
      o.open[this.id] = not o.open[this.id] or nil
      KM:RefreshList()
    end)
    return h
  end

  local function ListRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(LROW)
    r:SetWidth(PANEL_W - 26)
    local hl = W.Fill(r, K.accent, .12, "HIGHLIGHT")
    hl:SetAllPoints(r)
    r.sel = W.Fill(r, K.accent, .2, "BACKGROUND")
    r.sel:SetAllPoints(r)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(18)
    r.icon:SetHeight(18)
    r.icon:SetPoint("LEFT", r, "LEFT", 10, 0)
    r.text = W.Font(r:CreateFontString(nil, "OVERLAY"), 11, K.text[1], K.text[2], K.text[3])
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", -58, 0)
    r.text:SetJustifyH("LEFT")
    r.key = W.Font(r:CreateFontString(nil, "OVERLAY"), 10, K.accent[1], K.accent[2], K.accent[3])
    r.key:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.key:SetWidth(54)
    r.key:SetJustifyH("RIGHT")
    Draggable(r)
    r:SetScript("OnClick", function()
      if this.justDragged then this.justDragged = nil return end
      KM.command = (KM.command ~= this.cmd) and this.cmd or nil
      KM.ability = nil
      KM:Refresh()
    end)
    r:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:AddLine(this.name, 1, 1, 1)
      local k1, k2 = GetBindingKey(this.cmd)
      GameTooltip:AddDoubleLine("Keys", (k1 or "none") .. (k2 and (", " .. k2) or ""), .6, .6, .6, 1, 1, 1)
      GameTooltip:AddLine("Drag onto a key, or click then click a key.", K.accent[1], K.accent[2], K.accent[3])
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
  end

  -- the categories of pfUI.keybinds, folded until opened
  function KM:RefreshList()
    local KB = pfUI.keybinds
    local secs = KB and KB.Read and KB.Read() or {}
    local open = KM.Store().open or {}
    for _, r in ipairs(self.listRows) do r:Hide() end
    for _, h in ipairs(self.listHeads) do h:Hide() end
    local y, nh, nr = 0, 0, 0
    for _, sec in ipairs(secs) do
      nh = nh + 1
      local h = self.listHeads[nh] or ListHead(self.list)
      self.listHeads[nh] = h
      h.id = sec.id
      h.text:SetText(sec.name)
      h.count:SetText(table.getn(sec.rows))
      if sec.icon then
        h.icon:SetTexture(sec.icon)
        h.icon:SetTexCoord(.08, .92, .08, .92)
      else
        local tex, a, b, c, d = KB.Icon(sec, "RAIDTARGET1")
        h.icon:SetTexture(tex)
        h.icon:SetTexCoord(a, b, c, d)
      end
      W.Turn(h.arrow, open[sec.id] and "down" or "right")
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
      h:Show()
      y = y + LHEAD
      if open[sec.id] then
        for _, row in ipairs(sec.rows) do
          nr = nr + 1
          local r = self.listRows[nr] or ListRow(self.list)
          self.listRows[nr] = r
          r.cmd, r.name = row.cmd, row.name
          r.payload = { cmd = row.cmd }
          r.text:SetText(row.name)
          local tex, a, b, c, d = KB.Icon(sec, row.cmd)
          r.tex = tex or sec.icon
          r.coords = tex and { a, b, c, d } or nil
          r.icon:SetTexture(r.tex)
          if tex then r.icon:SetTexCoord(a, b, c, d) else r.icon:SetTexCoord(.08, .92, .08, .92) end
          r.icon:SetAlpha(tex and 1 or .35)
          local k1 = GetBindingKey(row.cmd)
          r.key:SetText(k1 and ((GetBindingText and GetBindingText(k1, "KEY_")) or k1) or "")
          if KM.command == row.cmd then r.sel:Show() else r.sel:Hide() end
          r:ClearAllPoints()
          r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
          r:Show()
          y = y + LROW
        end
        y = y + 4
      end
    end
    self.list:SetHeight(math.max(10, y))
    self.listScroll:UpdateScrollChildRect()
  end

  function KM:Toggle()
    if not self.frame then self:Build() end
    if self.frame:IsShown() then self.frame:Hide() else
      if pfUI.gui and pfUI.gui:IsShown() then pfUI.gui:Hide() end
      self.frame:Show()
    end
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function() if KM.frame and KM.frame:IsShown() then KM:Refresh() end end)

  _G.SLASH_PFKEYMAP1, _G.SLASH_PFKEYMAP2 = "/keymap", "/km"
  _G.SlashCmdList.PFKEYMAP = function() KM:Toggle() end
end)
