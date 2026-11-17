pfUI:RegisterModule("gear-slots", "vanilla", function ()
  -- pfUI Octo :: quick-access slot buttons (24 Oct 2026, gear phase 2; ItemRack's
  -- feature list read, nothing copied). One movable bar of the equipment slots
  -- picked (C.gear.slotlist "16,17,18": on the Slot buttons page, or Alt-click
  -- a slot in the character window): each shows what is worn there with its
  -- cooldown; click uses it, the item menu (hover, right-click or off) swaps it.
  local GR = pfUI.gear
  if not GR or not GR.Flyout then return end

  local function Flat(f, a)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(.06, .06, .08, a or .95)
    f:SetBackdropBorderColor(.2, .2, .24, 1)
  end

  -- the slots on the bar, in the order picked
  function GR.SlotList()
    local out = {}
    for n in string.gfind(C.gear.slotlist or "", "%d+") do
      local inv = tonumber(n)
      if GR.NAME[inv] then table.insert(out, inv) end
    end
    return out
  end
  function GR.HasSlot(inv)
    for _, i in ipairs(GR.SlotList()) do if i == inv then return true end end
  end
  function GR.ToggleSlot(inv)
    local list, out, had = GR.SlotList(), {}, false
    for _, i in ipairs(list) do if i == inv then had = true else table.insert(out, i) end end
    if not had then table.insert(out, inv) end
    local s = {}
    for _, i in ipairs(out) do table.insert(s, tostring(i)) end
    C.gear.slotlist = table.concat(s, ",")
    GR.Changed()
    return not had
  end

  local EMPTY = {}
  for _, s in ipairs(GR.SLOTS) do
    local _, tex = GetInventorySlotInfo and GetInventorySlotInfo(s[2])
    EMPTY[s[1]] = tex
  end
  GR.EMPTYTEX = EMPTY

  -- where a slot button's menu opens: as set, or (auto) towards the middle
  function GR.MenuSide(owner, vertical)
    local side = C.gear.slotside or "auto"
    if side ~= "auto" then return side end
    if vertical then
      local x = owner:GetCenter()
      return (x and x > GetScreenWidth() / 2) and "LEFT" or "RIGHT"
    end
    local _, y = owner:GetCenter()
    return (y and y > GetScreenHeight() / 2) and "BOTTOM" or "TOP"
  end

  -- one slot button (on the bar, or in the options preview: preview = true)
  function GR.NewSlotButton(parent, inv, name, preview)
    local b = CreateFrame("Button", name, parent)
    b.inv = inv
    b.preview = preview
    Flat(b, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(.07, .93, .07, .93)
    b.cd = CreateFrame("Model", name and (name .. "Cooldown") or nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.num = b:CreateFontString(nil, "OVERLAY")
    b.num:SetFont(pfUI.font_default, 12, "OUTLINE")
    b.num:SetPoint("CENTER", b, "CENTER", 0, 0)
    if preview then return b end
    GR.Bindable(b, inv)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        local link = GetInventoryItemLink("player", this.inv)
        if link then ChatFrameEditBox:Insert(link) end
        return
      end
      if arg1 == "RightButton" then
        -- right-click: the menu (if it opens on right-click), else use it if set so
        if C.gear.slotmenu == "right" then GR.SlotMenu(this)
        elseif C.gear.slotrightuse == "1" then UseInventoryItem(this.inv) end
      else
        UseInventoryItem(this.inv)
      end
    end)
    b:SetScript("OnEnter", function()
      if not GR.TipsOn or GR.TipsOn() then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if GetInventoryItemLink("player", this.inv) then GameTooltip:SetInventoryItem("player", this.inv)
        else GameTooltip:AddLine(GR.NAME[this.inv]) end
        GameTooltip:Show()
      end
      if C.gear.slotmenu == "hover" and (C.gear.slotshift ~= "1" or IsShiftKeyDown()) then GR.SlotMenu(this) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end

  function GR.SlotMenu(b)
    if C.gear.slotmenu == "off" then return end
    local inv = b.inv
    GR.Flyout(b, inv, function(item) GR.EquipItem(inv, item) end,
      { side = GR.MenuSide(b, C.gear.slotvertical == "1"), hint = (C.gear.allowhidden ~= "0") and "Alt-click: hide it here (hold Alt to see hidden ones)" or nil })
  end

  -- lay out buttons (by slot) for the slots in list, inside frame
  function GR.LayoutSlots(frame, buttons, list)
    local size = tonumber(C.gear.slotsize) or 36
    local gap = tonumber(C.gear.slotspace) or 4
    local per = math.max(1, tonumber(C.gear.slotper) or 12)
    local vertical = C.gear.slotvertical == "1"
    for _, b in pairs(buttons) do b:Hide() end
    local n = 0
    -- (the off hand stays away while a two-hander is worn and it is empty -
    -- user, 24 Oct 2026; it comes back with a one-hander)
    local noOff = GR.TwoHanded() and not GetInventoryItemLink("player", 17)
    for _, inv in ipairs(list) do
      local b = buttons[inv]
      if b and not (inv == 17 and noOff) then
        local line = math.floor(n / per)
        local pos = n - line * per
        local x, y = pos * (size + gap), line * (size + gap)
        if vertical then x, y = y, x end
        b:SetWidth(size)
        b:SetHeight(size)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
        local tex = GR.InvTex(inv)
        b.icon:SetTexture(tex or EMPTY[inv])
        b.icon:SetDesaturated(tex == nil)
        b:Show()
        n = n + 1
      end
    end
    local cols = math.min(math.max(n, 1), per)
    local lines = math.max(1, math.ceil(n / per))
    local w, h = cols * size + (cols - 1) * gap, lines * size + (lines - 1) * gap
    if vertical then w, h = h, w end
    frame:SetWidth(math.max(size, w))
    frame:SetHeight(math.max(size, h))
    return n
  end

  -- the bar
  local bar = CreateFrame("Frame", "pfGearSlots", UIParent)
  bar:SetFrameStrata("MEDIUM")
  bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 250)
  bar.buttons = {}
  for _, s in ipairs(GR.SLOTS) do
    bar.buttons[s[1]] = GR.NewSlotButton(bar, s[1], "pfGearSlot" .. s[1])
  end
  GR.slotbar = bar

  local function Wanted()
    if C.gear.slotbar ~= "1" then return false end
    if pfUI.unlock and pfUI.unlock:IsShown() then return true end
    if C.gear.slotcombat == "1" and not UnitAffectingCombat("player") then return false end
    return true
  end
  function GR.UpdateSlots()
    local n = GR.LayoutSlots(bar, bar.buttons, GR.SlotList())
    bar:SetAlpha(tonumber(C.gear.slotalpha) or 1)
    if Wanted() and n > 0 then bar:Show() else bar:Hide() end
  end
  GR.listeners.slots = GR.UpdateSlots

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_REGEN_DISABLED")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function() GR.UpdateSlots() end)
  -- cooldowns, and the bar shown while layout mode is open
  libclient.Every(bar, .2, function()
    for _, inv in ipairs(GR.SlotList()) do GR.PaintCooldown(this.buttons[inv]) end
  end)
  -- what is worn, looked at by the bar itself: the inventory event did not
  -- arrive in game when the staff went back to the bag (24 Oct 2026)
  local seen
  local look = CreateFrame("Frame")
  libclient.Every(look, .25, function()
    local s = ""
    for _, inv in ipairs(GR.SlotList()) do s = s .. inv .. "=" .. (GetInventoryItemLink("player", inv) or "-") .. ";" end
    s = s .. "16=" .. (GetInventoryItemLink("player", 16) or "-")
    if s ~= seen then
      seen = s
      GR.UpdateSlots()
    end
  end)
  local watch = CreateFrame("Frame")
  watch:SetScript("OnUpdate", function()
    local open = pfUI.unlock and pfUI.unlock:IsShown()
    if open ~= this.open then
      this.open = open
      GR.UpdateSlots()
    end
  end)
  if UpdateMovable then UpdateMovable(bar) end

  -- the character window: Alt-click a slot puts it on the bar or takes it off
  -- (instead of picking the item up)
  local function HookAlt()
    for _, s in ipairs(GR.SLOTS) do
      local slot = _G["Character" .. s[2]]
      if slot and not slot.octoAlt then
        slot.octoAlt = true
        local inv = s[1]
        local orig = slot:GetScript("OnClick")
        slot:SetScript("OnClick", function()
          if IsAltKeyDown() and C.gear.altslots ~= "0" then
            local on = GR.ToggleSlot(inv)
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r gear: " .. GR.NAME[inv] .. (on and " is on your slot buttons." or " is off your slot buttons."))
            return
          end
          if orig then orig() end
        end)
      end
    end
  end
  HookAlt()
  local boot = CreateFrame("Frame")
  boot:RegisterEvent("PLAYER_ENTERING_WORLD")
  boot:SetScript("OnEvent", function() HookAlt() GR.UpdateSlots() end)
  GR.UpdateSlots()
end)
