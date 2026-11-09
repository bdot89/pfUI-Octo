pfUI:RegisterModule("keybinds", "vanilla", function ()
  -- pfUI Octo :: Key Bindings - the game's key binding list in pfUI Octo's look.
  -- User, 20 Oct 2026 (screenshot of Blizzard's Key Bindings window): "our
  -- own version of the blizzard keybindings ... a popout window on the right
  -- explaining what it is ... collapsible cat lists ... use logos and images
  -- everywhere you can".
  --
  -- Every command the game knows (GetNumBindings / GetBinding: command, key 1,
  -- key 2; "HEADER_x" rows start a category, its name is BINDING_HEADER_x),
  -- in folding categories with a picture each; action button rows show the
  -- spell on the button, raid mark rows the mark. Click a key box, press a
  -- key (Shift / Ctrl / Alt, mouse buttons 3-5 and the wheel work too);
  -- Escape or a left-click cancels, right-click clears. Changes are saved at
  -- once (SaveBindings of the current set). Character specific = binding
  -- set 2, as Blizzard's box (LoadBindings 1 when it is unticked).
  -- The info panel on the right explains the row under the mouse.

  local OU = pfUI.octoui
  local W = OU and OU.W
  if not W then return end
  local K = W.C

  local KB = { rows = {}, heads = {} }
  pfUI.keybinds = KB

  local ICON = "Interface\\Icons\\"
  local RAID = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
  -- every icon name checked against the client's MPQ file lists
  local HEAD = {
    MOVEMENT = { "Ability_Rogue_Sprint", "Walking, turning, jumping and auto-run - the keys you hold to move." },
    CHAT = { "INV_Letter_02", "Opening chat, replying to whispers and scrolling the chat window." },
    ACTIONBAR = { "Ability_DualWield", "Your main action bar: its 12 buttons, bar pages, and the stance and pet bars." },
    MULTIACTIONBAR = { "INV_Sword_04", "The extra action bars: bottom left, bottom right, right and left." },
    TARGETING = { "Ability_Hunter_SniperShot", "Picking targets: nearest enemy, party members, assist and more." },
    INTERFACE = { "INV_Misc_Gear_01", "Opening windows: bags, character, spellbook, talents, map, options..." },
    MISC = { "INV_Misc_Rune_01", "Everything else: screenshots, nameplates, toggles." },
    CAMERA = { "INV_Misc_Spyglass_02", "Zooming, camera views and moving the camera around." },
    RAID_TARGET = { nil, "Putting a raid mark (star, circle, skull...) on your target." },
    ITUNES_REMOTE = { "INV_Misc_Note_02", "Music player keys." },
  }
  local ADDON = { "INV_Misc_Book_09", "Keys an addon added." }

  local function Store()
    local s = OU.Store()
    if type(s.kbFold) ~= "table" then s.kbFold = {} end
    return s
  end

  local function KeyText(key)
    if not key then return nil end
    return (GetBindingText and GetBindingText(key, "KEY_")) or key
  end

  -- raid mark n -> its part of the raid icon texture (4 x 2 grid)
  local function RaidCoords(n)
    local col, row = math.mod(n - 1, 4), math.floor((n - 1) / 4)
    return col * .25, (col + 1) * .25, row * .25, (row + 1) * .25
  end

  -- the categories and their commands, as the game lists them
  function KB.Read()
    local out, cur = {}, nil
    local n = GetNumBindings and GetNumBindings() or 0
    for i = 1, n do
      local cmd = GetBinding(i)
      if cmd then
        local _, _, hid = string.find(cmd, "^HEADER_(.+)$")
        if hid then
          if not string.find(hid, "^BLANK") then   -- BLANK, BLANK2...: spacers, they join the one before
            local info = HEAD[hid] or ADDON
            cur = { id = hid, name = getglobal("BINDING_" .. cmd) or hid, icon = info[1] and (ICON .. info[1]),
                    about = info[2], rows = {} }
            if hid == "RAID_TARGET" then cur.raid = 1 end
            table.insert(out, cur)
          end
        else
          if not cur then
            cur = { id = "OTHER", name = "Other", icon = ICON .. ADDON[1], about = ADDON[2], rows = {} }
            table.insert(out, cur)
          end
          table.insert(cur.rows, { cmd = cmd, name = (GetBindingText and GetBindingText(cmd, "BINDING_NAME_")) or cmd })
        end
      end
    end
    local list = {}
    for _, s in ipairs(out) do if table.getn(s.rows) > 0 then table.insert(list, s) end end
    return list
  end

  -- the picture of one command
  function KB.Icon(sec, cmd)
    local _, _, mark = string.find(cmd, "^RAIDTARGET(%d)$")
    if mark then return RAID, RaidCoords(tonumber(mark)) end
    if pfUI.keymap and pfUI.keymap.Describe then
      local tex = pfUI.keymap.Describe(cmd)
      if tex then return tex, .08, .92, .08, .92 end
    end
    return nil
  end

  local function Save()
    SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
    KB:Refresh()
  end

  -- puts key on cmd's key box n (1 or 2); returns what the key did before
  function KB.Bind(cmd, n, key)
    local k1, k2 = GetBindingKey(cmd)
    local old = (n == 1) and k1 or k2
    local before = GetBindingAction(key)
    if old and old ~= key then SetBinding(old) end
    SetBinding(key, cmd)
    Save()
    if before and before ~= "" and before ~= cmd then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. KeyText(key) .. " was \""
        .. ((GetBindingText and GetBindingText(before, "BINDING_NAME_")) or before) .. "\" - it is now this.")
    end
    return before
  end

  function KB.Clear(cmd, n)
    local k1, k2 = GetBindingKey(cmd)
    local k = (n == 1) and k1 or k2
    if k then SetBinding(k) Save() end
  end

  -- ---------------------------------------------------------------- waiting for a key

  local function StopWaiting()
    local w = KB.waiting
    KB.waiting = nil
    if KB.frame then KB.frame:EnableKeyboard(false) end
    if w then KB:Refresh() end
  end

  local function Pressed(key)
    local w = KB.waiting
    if not w then return end
    if key == "ESCAPE" then StopWaiting() return end
    if key == "SHIFT" or key == "CTRL" or key == "ALT" or key == "UNKNOWN"
      or key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
    if IsShiftKeyDown() then key = "SHIFT-" .. key end
    if IsControlKeyDown() then key = "CTRL-" .. key end
    if IsAltKeyDown() then key = "ALT-" .. key end
    KB.waiting = nil
    KB.frame:EnableKeyboard(false)
    KB.Bind(w.cmd, w.n, key)
  end
  KB.Pressed = Pressed

  local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

  local function KeyBoxClick()
    local b = this
    local row = b.row
    if not row or not row.cmd then return end
    local w = KB.waiting
    if w and w.cmd == row.cmd and w.n == b.n then
      if MOUSE[arg1] then Pressed(MOUSE[arg1]) else StopWaiting() end
      return
    end
    if arg1 == "RightButton" then
      KB.Clear(row.cmd, b.n)
      return
    end
    KB.waiting = { cmd = row.cmd, n = b.n }
    KB.selected = row.cmd
    KB.frame:EnableKeyboard(true)
    KB:Refresh()
    KB:ShowInfo(row)
  end

  -- ---------------------------------------------------------------- the window

  local WIDTH, HEIGHT, PAD, INFO_W = 980, 640, 12, 270
  local ROW_H, HEAD_H = 26, 30
  local LIST_W = WIDTH - 2 * PAD - INFO_W - 12 - 22
  local NAME_X, KEY1_X, KEY_W = 38, LIST_W - 2 * 158, 150

  local function KeyBox(row, n)
    local b = W.Button(row, "", KEY_W, 20)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
    b:SetPoint("LEFT", row, "LEFT", KEY1_X + (n - 1) * (KEY_W + 8), 0)
    b.n = n
    b:SetScript("OnClick", KeyBoxClick)
    b:SetScript("OnEnter", function() KB:ShowInfo(this.row) end)
    return b
  end

  local function MakeRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW_H)
    r:SetWidth(LIST_W)
    r.bg = W.Fill(r, { 1, 1, 1 }, .025, "BACKGROUND")
    r.bg:SetAllPoints(r)
    local hl = W.Fill(r, K.accent, .08, "HIGHLIGHT")
    hl:SetAllPoints(r)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(20)
    r.icon:SetHeight(20)
    r.icon:SetPoint("LEFT", r, "LEFT", 10, 0)
    r.text = W.Font(r:CreateFontString(nil, "OVERLAY"), 12, K.text[1], K.text[2], K.text[3])
    r.text:SetPoint("LEFT", r, "LEFT", NAME_X, 0)
    r.text:SetPoint("RIGHT", r, "LEFT", KEY1_X - 8, 0)
    r.text:SetJustifyH("LEFT")
    r.k1 = KeyBox(r, 1)
    r.k2 = KeyBox(r, 2)
    r.k1.row, r.k2.row = r, r
    r:SetScript("OnEnter", function() KB:ShowInfo(this) end)
    r:SetScript("OnClick", function()
      KB.selected = this.cmd
      KB:ShowInfo(this)
      KB:Refresh()
    end)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function() KB.Wheel() end)
    return r
  end

  local function MakeHead(parent)
    local h = CreateFrame("Button", nil, parent)
    h:SetHeight(HEAD_H - 4)
    h:SetWidth(LIST_W)
    W.Flat(h, K.head, 1, K.line)
    W.Hover(h, .05)
    h.arrow = W.Arrow(h, 10, "down")
    h.arrow:SetPoint("LEFT", h, "LEFT", 8, 0)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetWidth(20)
    h.icon:SetHeight(20)
    h.icon:SetPoint("LEFT", h, "LEFT", 24, 0)
    h.text = W.Font(h:CreateFontString(nil, "OVERLAY"), 13, K.text[1], K.text[2], K.text[3])
    h.text:SetPoint("LEFT", h.icon, "RIGHT", 8, 0)
    h.count = W.Font(h:CreateFontString(nil, "OVERLAY"), 11, K.dim[1], K.dim[2], K.dim[3])
    h.count:SetPoint("RIGHT", h, "RIGHT", -10, 0)
    h:SetScript("OnClick", function()
      local f = Store().kbFold
      -- folded until opened (user: "collapsed naturally"); false = open
      if f[this.id] == false then f[this.id] = nil else f[this.id] = false end
      KB:Layout()
    end)
    h:SetScript("OnEnter", function()
      if this.sec then KB:ShowInfo(nil, this.sec) end
    end)
    h:EnableMouseWheel(true)
    h:SetScript("OnMouseWheel", function() KB.Wheel() end)
    return h
  end

  function KB.Wheel()
    local sf = KB.scroll
    local max = sf:GetVerticalScrollRange() or 0
    local v = math.max(0, math.min(max, (sf:GetVerticalScroll() or 0) - arg1 * ROW_H * 3))
    local sb = getglobal(sf:GetName() .. "ScrollBar")
    if sb then sb:SetValue(v) else sf:SetVerticalScroll(v) end
  end

  function KB:Build()
    local f = CreateFrame("Frame", "pfKeyBindings", UIParent)
    f:SetWidth(WIDTH)
    f:SetHeight(HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetClampedToScreen(true)
    W.Flat(f, K.bg, .97, K.lineHi)
    f:Hide()
    table.insert(UISpecialFrames, "pfKeyBindings")
    f:SetScript("OnMouseDown", function() this:StartMoving() end)
    f:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
    f:SetScript("OnKeyDown", function() Pressed(arg1) end)
    f:SetScript("OnMouseWheel", function()
      if KB.waiting then Pressed(arg1 > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") else KB.Wheel() end
    end)
    f:SetScript("OnShow", function() KB:Layout() end)
    f:SetScript("OnHide", function() StopWaiting() W.CloseMenus() end)
    self.frame = f

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ICON .. "INV_Misc_Key_03")
    logo:SetTexCoord(.08, .92, .08, .92)
    logo:SetWidth(22)
    logo:SetHeight(22)
    logo:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 2, -8)
    local title = W.Font(f:CreateFontString(nil, "OVERLAY"), 15, K.text[1], K.text[2], K.text[3])
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("|cff33ccffKey|r Bindings")
    local sub = W.Font(f:CreateFontString(nil, "OVERLAY"), 11, K.dim[1], K.dim[2], K.dim[3])
    sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
    sub:SetText("every key the game knows")
    local close = W.Button(f, "X", 22, 22)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    close:SetScript("OnClick", function() f:Hide() end)

    -- tool bar
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -36)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -36)
    bar:SetHeight(30)
    W.Flat(bar, K.panel, 1, K.line)
    local find = W.EditBox(bar, 220, "pfKeyBindingsFind")
    find:SetPoint("LEFT", bar, "LEFT", 6, 0)
    local hint = W.Font(find:CreateFontString(nil, "OVERLAY"), 11, K.dim[1], K.dim[2], K.dim[3])
    hint:SetPoint("LEFT", find, "LEFT", 7, 0)
    hint:SetText("Search commands or keys")
    find.OnFocus = function() if find.typing or (find:GetText() or "") ~= "" then hint:Hide() else hint:Show() end end
    find:SetScript("OnTextChanged", function()
      find.OnFocus()
      KB.search = string.lower(this:GetText() or "")
      if string.len(KB.search) < 2 then KB.search = nil end
      KB:Layout()
    end)
    find:SetScript("OnEscapePressed", function() this:SetText("") this:ClearFocus() end)
    self.find = find
    local cb = W.CheckBox(bar, 16)
    cb:SetPoint("LEFT", find, "RIGHT", 16, 0)
    local cl = W.Font(bar:CreateFontString(nil, "OVERLAY"), 12, K.text[1], K.text[2], K.text[3])
    cl:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    cl:SetText("Character specific")
    cb:SetScript("OnClick", function()
      if this:GetChecked() then
        SaveBindings(2)
      else
        -- (9 Nov 2026: never drop keys without asking) this character's own keys are
        -- replaced by the shared ones, so it asks first; No keeps everything
        this:SetChecked(1)
        CreateQuestionDialog("Use the keys every character on the account shares?\nThis character's own keys are replaced by them.", function()
          LoadBindings(1)
          SaveBindings(1)
          KB:Refresh()
        end)
      end
      KB:Refresh()
    end)
    W.Tip(cb, "Character specific", "Ticked: this character keeps its own keys. Unticked: the keys every character on the account shares.")
    self.charBox = cb
    local reset = W.Button(bar, "Reset to default", 120, 22)
    reset:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    reset:SetScript("OnClick", function()
      CreateQuestionDialog("Put every key back to the game's defaults?", function()
        LoadBindings(0)
        Save()
      end)
    end)
    local map = W.Button(bar, "Key Map", 90, 22)
    map:SetPoint("RIGHT", reset, "LEFT", -6, 0)
    map:SetScript("OnClick", function()
      f:Hide()
      if pfUI.keymap then pfUI.keymap:Toggle() end
    end)
    W.Tip(map, "Key Map", "The same keys on a picture of your keyboard.")

    -- column titles
    local cols = CreateFrame("Frame", nil, f)
    cols:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -72)
    cols:SetWidth(LIST_W)
    cols:SetHeight(16)
    local function Col(text, x)
      local t = W.Font(cols:CreateFontString(nil, "OVERLAY"), 11, K.accent[1], K.accent[2], K.accent[3])
      t:SetPoint("LEFT", cols, "LEFT", x, 0)
      t:SetText(text)
    end
    Col("Command", NAME_X)
    Col("Key 1", KEY1_X + 4)
    Col("Key 2", KEY1_X + KEY_W + 12)

    -- the list
    local holder = CreateFrame("Frame", nil, f)
    holder:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -92)
    holder:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
    holder:SetWidth(LIST_W + 22)
    W.Flat(holder, K.panel, 1, K.line)
    local sf = CreateFrame("ScrollFrame", "pfKeyBindingsScroll", holder, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -4)
    sf:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -20, 4)
    W.FlatScroll(sf)
    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(LIST_W)
    content:SetHeight(10)
    sf:SetScrollChild(content)
    self.scroll, self.content = sf, content

    -- the info panel on the right
    local info = CreateFrame("Frame", nil, f)
    info:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -72)
    info:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
    info:SetWidth(INFO_W)
    W.Flat(info, K.card, 1, K.line)
    info.icon = info:CreateTexture(nil, "ARTWORK")
    info.icon:SetWidth(52)
    info.icon:SetHeight(52)
    info.icon:SetPoint("TOPLEFT", info, "TOPLEFT", 14, -14)
    info.name = W.Font(info:CreateFontString(nil, "OVERLAY"), 15, K.text[1], K.text[2], K.text[3])
    info.name:SetPoint("TOPLEFT", info.icon, "TOPRIGHT", 10, -2)
    info.name:SetPoint("RIGHT", info, "RIGHT", -10, 0)
    info.name:SetJustifyH("LEFT")
    info.cat = W.Font(info:CreateFontString(nil, "OVERLAY"), 11, K.accent[1], K.accent[2], K.accent[3])
    info.cat:SetPoint("TOPLEFT", info.name, "BOTTOMLEFT", 0, -6)
    info.keys = W.Font(info:CreateFontString(nil, "OVERLAY"), 12, K.text[1], K.text[2], K.text[3])
    info.keys:SetPoint("TOPLEFT", info.icon, "BOTTOMLEFT", 0, -16)
    info.keys:SetWidth(INFO_W - 28)
    info.keys:SetJustifyH("LEFT")
    info.keys:SetSpacing(4)
    info.about = W.Font(info:CreateFontString(nil, "OVERLAY"), 11, K.dim[1], K.dim[2], K.dim[3])
    info.about:SetPoint("TOPLEFT", info.keys, "BOTTOMLEFT", 0, -14)
    info.about:SetWidth(INFO_W - 28)
    info.about:SetJustifyH("LEFT")
    info.about:SetSpacing(3)
    local how = W.Font(info:CreateFontString(nil, "OVERLAY"), 11, K.dim[1], K.dim[2], K.dim[3])
    how:SetPoint("BOTTOMLEFT", info, "BOTTOMLEFT", 14, 14)
    how:SetWidth(INFO_W - 28)
    how:SetJustifyH("LEFT")
    how:SetSpacing(3)
    how:SetText("|cff33ccffHow to bind|r\nClick a key box, then press the key. Shift, Ctrl and Alt work, and so do "
      .. "mouse buttons 3 - 5 and the wheel.\nEscape or a click cancels. Right-click a box to clear it.\n"
      .. "Saved at once.")
    self.info = info
    self:ShowInfo(nil, nil)
  end

  -- the panel on the right: what the row (or category) under the mouse is
  function KB:ShowInfo(row, sec)
    local info = self.info
    if not info then return end
    sec = sec or (row and row.sec)
    if row and row.cmd then
      local tex, l, r, t, b = KB.Icon(sec, row.cmd)
      info.icon:SetTexture(tex or (sec and sec.icon) or (ICON .. "INV_Misc_Key_03"))
      if tex then info.icon:SetTexCoord(l, r, t, b) else info.icon:SetTexCoord(.08, .92, .08, .92) end
      info.name:SetText(row.name)
      info.cat:SetText(sec and sec.name or "")
      local k1, k2 = GetBindingKey(row.cmd)
      local spell
      if pfUI.keymap and pfUI.keymap.SlotOf then
        local slot = pfUI.keymap.SlotOf(row.cmd)
        if slot and HasAction(slot) then
          local _, n = pfUI.keymap.Describe(row.cmd)
          spell = "On the button: |cffffffff" .. (n or "?") .. "|r"
        elseif slot then
          spell = "The button is empty."
        end
      end
      info.keys:SetText("Key 1:  |cff33ccff" .. (KeyText(k1) or "-") .. "|r\nKey 2:  |cff33ccff" .. (KeyText(k2) or "-") .. "|r"
        .. (spell and ("\n" .. spell) or ""))
      info.about:SetText((sec and sec.about or "") .. "\n\n|cff777777" .. row.cmd .. "|r")
    elseif sec then
      info.icon:SetTexture(sec.icon or RAID)
      if sec.icon then info.icon:SetTexCoord(.08, .92, .08, .92) else info.icon:SetTexCoord(RaidCoords(1)) end
      info.name:SetText(sec.name)
      info.cat:SetText(table.getn(sec.rows) .. " commands")
      info.keys:SetText("")
      info.about:SetText(sec.about or "")
    else
      info.icon:SetTexture(ICON .. "INV_Misc_Key_03")
      info.icon:SetTexCoord(.08, .92, .08, .92)
      info.name:SetText("Key Bindings")
      info.cat:SetText("pfUI Octo")
      info.keys:SetText("")
      info.about:SetText("Hover a command to see what it does and which keys work it. Click a category bar to fold it.")
    end
  end

  local function Match(row)
    local s = KB.search
    if not s then return true end
    local k1, k2 = GetBindingKey(row.cmd)
    local hay = string.lower(row.name .. " " .. row.cmd .. " " .. (KeyText(k1) or "") .. " " .. (KeyText(k2) or ""))
    return string.find(hay, s, 1, true) ~= nil
  end

  -- stacks the categories and their rows (folded ones as a bar only)
  function KB:Layout()
    if not self.frame then return end
    self.sections = KB.Read()
    for _, r in ipairs(self.rows) do r:Hide() end
    for _, h in ipairs(self.heads) do h:Hide() end
    local y, nr, nh = 0, 0, 0
    local fold = Store().kbFold
    for _, sec in ipairs(self.sections) do
      local shown = {}
      for _, row in ipairs(sec.rows) do if Match(row) then table.insert(shown, row) end end
      if table.getn(shown) > 0 then
        nh = nh + 1
        local h = self.heads[nh] or MakeHead(self.content)
        self.heads[nh] = h
        h.id, h.sec = sec.id, sec
        h.text:SetText(sec.name)
        h.count:SetText(table.getn(shown))
        h.icon:SetTexture(sec.icon or RAID)
        if sec.icon then h.icon:SetTexCoord(.08, .92, .08, .92) else h.icon:SetTexCoord(RaidCoords(1)) end
        local open = KB.search or fold[sec.id] == false
        W.Turn(h.arrow, open and "down" or "right")
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
        h:Show()
        y = y + HEAD_H
        if open then
          for i, row in ipairs(shown) do
            nr = nr + 1
            local r = self.rows[nr] or MakeRow(self.content)
            self.rows[nr] = r
            r.cmd, r.name, r.sec = row.cmd, row.name, sec
            r.text:SetText(row.name)
            if math.mod(i, 2) == 0 then r.bg:Show() else r.bg:Hide() end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
            r:Show()
            y = y + ROW_H
          end
          y = y + 6
        end
      end
    end
    self.content:SetHeight(math.max(10, y))
    self.scroll:UpdateScrollChildRect()
    self:Refresh()
  end

  -- re-reads every shown row's keys and picture
  function KB:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self.charBox:SetChecked((GetCurrentBindingSet and GetCurrentBindingSet() == 2) and 1 or nil)
    for _, r in ipairs(self.rows) do
      if r:IsShown() and r.cmd then
        local k1, k2 = GetBindingKey(r.cmd)
        for n, box in ipairs({ r.k1, r.k2 }) do
          local k = (n == 1) and k1 or k2
          local w = KB.waiting and KB.waiting.cmd == r.cmd and KB.waiting.n == n
          if w then
            box:SetText("Press a key...")
            W.Pick(box, true)
          else
            W.Pick(box, false)
            box:SetText(KeyText(k) or "Not bound")
            if k then box.label:SetTextColor(1, 1, 1) else box.label:SetTextColor(K.dim[1], K.dim[2], K.dim[3]) end
          end
        end
        local tex, l, rr, t, b = KB.Icon(r.sec, r.cmd)
        if tex then
          r.icon:SetTexture(tex)
          r.icon:SetTexCoord(l, rr, t, b)
          r.icon:SetAlpha(1)
        else
          r.icon:SetTexture(r.sec.icon or RAID)
          r.icon:SetTexCoord(.08, .92, .08, .92)
          r.icon:SetAlpha(.35)
        end
        if KB.selected == r.cmd then r.text:SetTextColor(K.accent[1], K.accent[2], K.accent[3]) else r.text:SetTextColor(K.text[1], K.text[2], K.text[3]) end
      end
    end
  end

  function KB:Toggle()
    if not self.frame then self:Build() end
    if self.frame:IsShown() then self.frame:Hide() else
      if pfUI.gui and pfUI.gui:IsShown() then pfUI.gui:Hide() end
      self.frame:Show()
    end
  end

  local ev = CreateFrame("Frame")
  pcall(ev.RegisterEvent, ev, "UPDATE_BINDINGS")
  ev:SetScript("OnEvent", function() if KB.frame and KB.frame:IsShown() and not KB.waiting then KB:Refresh() end end)

  _G.SLASH_PFKEYBINDS1, _G.SLASH_PFKEYBINDS2 = "/keybinds", "/kb"
  _G.SlashCmdList.PFKEYBINDS = function() KB:Toggle() end
end)
