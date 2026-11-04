pfUI:RegisterModule("autoloot-log", "vanilla", function ()
  -- pfUI Octo :: the Auto Loot log window (4 Nov 2026, modules/autoloot.lua):
  -- what the area looting picked up this session. Newest first with a time,
  -- or Combine = one row per item with its total; money total on top; item
  -- tooltips on hover; mouse wheel scrolls; drag the title to move it (Move
  -- Frames too); size from the options (C.autoloot.logw / logh). A window
  -- that is moved with StartSizing / StartMoving can crash this client (#132),
  -- so the size is a setting and the move is done by hand (pfUI.api.DragStart).
  local AL = pfUI.autoloot
  if not AL then return end
  local function G() return C.autoloot end
  local ROW = 16
  local MAXROWS = 40

  local win
  local function Make()
    local f = CreateFrame("Frame", "pfAutoLootLog", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetWidth(tonumber(G().logw) or 300)
    f:SetHeight(tonumber(G().logh) or 220)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    CreateBackdrop(f, nil, true)
    f:Hide()

    local title = CreateFrame("Button", nil, f)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    title:SetHeight(22)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function()
      if G().loglock == "1" then return end
      f:SetMovable(true)
      pfUI.api.DragStart(f)
      f.moving = true
    end)
    title:SetScript("OnDragStop", function()
      if not f.moving then return end
      pfUI.api.DragStop(f)
      f.moving = nil
      SaveMovable(f)
    end)
    f.name = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.name:SetFont(pfUI.font_default, 11, "OUTLINE")
    f.name:SetPoint("LEFT", title, "LEFT", 8, 0)
    f.name:SetText("Auto loot")

    local function Btn(label, w, x, fn, tip)
      local b = CreateFrame("Button", nil, f)
      b:SetWidth(w)
      b:SetHeight(16)
      b:SetPoint("TOPRIGHT", f, "TOPRIGHT", x, -3)
      CreateBackdrop(b, nil, true)
      b.t = b:CreateFontString(nil, "OVERLAY")
      b.t:SetFont(pfUI.font_default, 10, "OUTLINE")
      b.t:SetPoint("CENTER", b, "CENTER", 0, 0)
      b.t:SetText(label)
      b:SetScript("OnClick", fn)
      b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(tip)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      return b
    end
    Btn("x", 16, -4, function() f:Hide() end, "Close")
    Btn("Clear", 38, -24, function() AL.Clear() end, "Forget everything in the log")
    f.combine = Btn("Combine", 52, -66, function()
      G().combine = G().combine == "1" and "0" or "1"
      AL.RefreshLog()
    end, "One row per item with its total")

    f.total = f:CreateFontString(nil, "OVERLAY")
    f.total:SetFont(pfUI.font_default, 10, "OUTLINE")
    f.total:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)

    f.rows = {}
    for i = 1, MAXROWS do
      local r = CreateFrame("Button", nil, f)
      r:SetHeight(ROW)
      r:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -42 - (i - 1) * ROW)
      r:SetPoint("RIGHT", f, "RIGHT", -6, 0)
      r.time = r:CreateFontString(nil, "OVERLAY")
      r.time:SetFont(pfUI.font_default, 10, "OUTLINE")
      r.time:SetPoint("LEFT", r, "LEFT", 0, 0)
      r.time:SetWidth(46)
      r.time:SetJustifyH("LEFT")
      r.time:SetTextColor(.6, .6, .6)
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetWidth(ROW - 2)
      r.icon:SetHeight(ROW - 2)
      r.icon:SetTexCoord(.08, .92, .08, .92)
      r.text = r:CreateFontString(nil, "OVERLAY")
      r.text:SetFont(pfUI.font_default, 10, "OUTLINE")
      r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
      r.text:SetPoint("RIGHT", r, "RIGHT", 0, 0)
      r.text:SetJustifyH("LEFT")
      r:SetScript("OnEnter", function()
        if this.link then
          local _, _, s = string.find(this.link, "(item:[%-%d:]+)")
          if s then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(s)
            GameTooltip:Show()
          end
        end
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r:Hide()
      f.rows[i] = r
    end
    f:SetScript("OnMouseWheel", function()
      f.offset = (f.offset or 0) - (_G.arg1 or 0)
      if f.offset < 0 then f.offset = 0 end
      AL.RefreshLog()
    end)
    UpdateMovable(f)
    return f
  end

  local function Sorted()
    local list = {}
    for _, e in pairs(AL.state.items) do table.insert(list, e) end
    table.sort(list, function(a, b)
      if a.count ~= b.count then return a.count > b.count end
      return a.name < b.name
    end)
    return list
  end

  function AL.RefreshLog()
    if not win or not win:IsShown() then return end
    local f = win
    f:SetWidth(tonumber(G().logw) or 300)
    f:SetHeight(tonumber(G().logh) or 220)
    local comb = G().combine == "1"
    f.combine.t:SetTextColor(comb and .4 or 1, comb and 1 or 1, comb and .4 or 1)
    f.total:SetText(AL.state.count .. " items   " .. AL.Money(AL.state.money))
    local shown = math.floor(((tonumber(G().logh) or 220) - 48) / ROW)
    if shown > MAXROWS then shown = MAXROWS end
    if shown < 1 then shown = 1 end
    local list = comb and Sorted() or AL.state.events
    local n = table.getn(list)
    local off = f.offset or 0
    if off > n - shown then off = n - shown end
    if off < 0 then off = 0 end
    f.offset = off
    for i = 1, MAXROWS do
      local r = f.rows[i]
      local idx = comb and (off + i) or (n - off - i + 1)   -- newest first
      local e = (i <= shown) and idx >= 1 and idx <= n and list[idx] or nil
      if e then
        r.link = e.link
        if comb then
          r.time:SetText("x" .. e.count)
        else
          r.time:SetText(date("%H:%M:%S", e.t))
        end
        if e.kind == "money" then
          r.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
          r.text:SetText(AL.Money(e.amount))
        else
          r.icon:SetTexture(e.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
          local _, _, col = string.find(e.link or "", "^(|c%x%x%x%x%x%x%x%x)")
          r.text:SetText((col or "|cffffffff") .. e.name .. "|r" .. ((not comb and e.count > 1) and (" x" .. e.count) or ""))
        end
        r.icon:SetPoint("LEFT", r.time, "RIGHT", 2, 0)
        r:Show()
      else
        r.link = nil
        r:Hide()
      end
    end
  end

  function AL.ShowLog(show)
    if not win then win = Make() end
    if show == nil then show = not win:IsShown() end
    if show then win:Show() AL.RefreshLog() else win:Hide() end
  end
end)
