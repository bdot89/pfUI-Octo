pfUI:RegisterModule("meters-hover", "vanilla", function ()
  -- pfUI Octo :: the meter bars' hover panel (18 Nov 2026; user, with ClassicAPI's meter spell window beside ours:
  -- "make our tooltip look like this with icons and the bar ours looks bad when hovering over"). One row per spell
  -- (or source / target): its picture, a bar in the player's class colour as long as its share of the top one, the
  -- name on the bar, then total, per second and share. Drawn on our own frame, so other add-ons' tooltip lines
  -- (guild, target, rank) do not get mixed in. Spell pictures: the breakdown's SpellIcon (ClassicAPI's spell id from
  -- the combat log, else the spell book), else ClassicAPI's meter's own spell id, else a school-less question mark.
  local M = pfUI.meters
  if not M or not M.MODES then return end
  local floor, min, max = math.floor, math.min, math.max
  local ROW, ICON, PAD = 22, 20, 8
  local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
  local function Font() return pfUI.font_default end
  local function Num(v) return M.Num and M.Num(v) or tostring(floor(v + .5)) end

  local f = CreateFrame("Frame", "pfMeterHover", UIParent)
  f:SetFrameStrata("TOOLTIP")
  f:SetClampedToScreen(true)
  f:Hide()
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  f.bg:SetAllPoints(f)
  f.bg:SetVertexColor(.02, .02, .025, .92)
  f.edge = {}
  for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" }, { "TOPLEFT", "BOTTOMLEFT", "v" },
                       { "TOPRIGHT", "BOTTOMRIGHT", "v" } }) do
    local t = f:CreateTexture(nil, "BORDER")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(.35, .36, .4, 1)
    if p[3] == "h" then t:SetHeight(1) else t:SetWidth(1) end
    t:SetPoint(p[1], f, p[1], 0, 0)
    t:SetPoint(p[2], f, p[2], 0, 0)
    f.edge[i] = t
  end
  -- head: class picture, name in class colour, the display, its total
  f.cicon = f:CreateTexture(nil, "ARTWORK")
  f.cicon:SetWidth(18)
  f.cicon:SetHeight(18)
  f.cicon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
  f.name = f:CreateFontString(nil, "OVERLAY")
  f.name:SetPoint("LEFT", f.cicon, "RIGHT", 6, 0)
  f.name:SetJustifyH("LEFT")
  f.total = f:CreateFontString(nil, "OVERLAY")
  f.total:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, -PAD - 9)
  f.total:SetJustifyH("RIGHT")
  f.mode = f:CreateFontString(nil, "OVERLAY")
  f.mode:SetPoint("TOPLEFT", f.cicon, "BOTTOMLEFT", 0, -3)
  f.mode:SetJustifyH("LEFT")
  f.foot = f:CreateFontString(nil, "OVERLAY")
  f.foot:SetJustifyH("LEFT")
  f.rows = {}
  M.hover = f

  local function Row(i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, f)
    r:SetHeight(ROW)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(ICON)
    r.icon:SetHeight(ICON)
    r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.icon:SetTexCoord(.08, .92, .08, .92)
    r.back = r:CreateTexture(nil, "BACKGROUND")
    r.back:SetTexture("Interface\\Buttons\\WHITE8X8")
    r.back:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 3, -1)
    r.back:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 1)
    r.back:SetVertexColor(1, 1, 1, .06)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 3, -1)
    r.bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 1)
    r.bar:SetMinMaxValues(0, 1)
    r.name = r.bar:CreateFontString(nil, "OVERLAY")
    r.name:SetPoint("LEFT", r.bar, "LEFT", 5, 0)
    r.name:SetJustifyH("LEFT")
    r.value = r.bar:CreateFontString(nil, "OVERLAY")
    r.value:SetPoint("RIGHT", r.bar, "RIGHT", -5, 0)
    r.value:SetJustifyH("RIGHT")
    r.name:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
    f.rows[i] = r
    return r
  end

  local function Icon(name, id)
    local B = M.breakdown
    local tex = B and B.SpellIcon and B.SpellIcon(name)
    if not tex and id then
      local CS = _G.C_Spell
      if CS and CS.GetSpellTexture then
        local ok, t = pcall(CS.GetSpellTexture, id)
        if ok and t and t ~= "" then tex = t end
      end
    end
    return tex or QUESTION
  end

  -- the entries for a row: { { name, v, icon } }, the total, and per-second divisor (seconds) or nil
  function M.HoverEntries(row, mode, win)
    local out, total, secs = {}, 0, nil
    local a = row.actor
    if a and mode.list then
      local list
      list, total = mode.list(a)
      for name, s in pairs(list or {}) do table.insert(out, { name = name, v = s.total or 0 }) end
      secs = M.ActiveTime and M.ActiveTime(a)
    elseif a and mode.plain then
      local list
      list, total = mode.plain(a)
      for name, v in pairs(list or {}) do table.insert(out, { name = name, v = v, plain = true }) end
    elseif row.tlist then
      total = row.value
      for name, v in pairs(row.tlist) do table.insert(out, { name = name, v = v, plain = true }) end
    end
    -- ClassicAPI's meter row with no actor of ours: its own spells
    if not out[1] and row.capi and M.capi and M.capi.Spells then
      local sp = M.capi.Spells(win and win.segment or "current", mode.key, row.capi)
      total = 0
      for _, e in ipairs(sp or {}) do
        table.insert(out, { name = e.name, v = e.total, id = e.id, ps = e.ps })
        total = total + e.total
      end
    end
    table.sort(out, function(x, y) return x.v > y.v end)
    return out, total or 0, secs
  end

  -- returns true when it drew the panel
  function M.HoverPanel(bar)
    local row, win = bar.row, bar.win
    if not row or not win or C.meters.tooltip == "0" or row.pullrow or row.tank then return end
    local mode
    for _, m in ipairs(M.MODES) do if m.key == win.mode then mode = m end end
    if not mode or mode.key == "threat" then return end
    local list, total, secs = M.HoverEntries(row, mode, win)
    if not list[1] then return end
    local n = min(tonumber(C.meters.tooltiplines) or 8, table.getn(list))
    local font = Font()
    -- class colour
    local cc = row.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.class]
    local r, g, b = .55, .6, .7
    if cc then r, g, b = cc.r, cc.g, cc.b end
    local tc = row.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[row.class]
    if tc then
      f.cicon:SetTexture(pfUI.media["img:classicons"])
      f.cicon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    else
      f.cicon:SetTexture(row.foe and "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" or QUESTION)
      f.cicon:SetTexCoord(0, 1, 0, 1)
    end
    f.name:SetFont(font, 13, "OUTLINE")
    f.name:SetText(row.name or "")
    f.name:SetTextColor(r, g, b)
    f.total:SetFont(font, 13, "OUTLINE")
    f.total:SetText(row.text or "")
    f.mode:SetFont(font, 10, "")
    f.mode:SetTextColor(.6, .62, .66)
    f.mode:SetText(mode.name .. (row.capi and "  |cff40d977(ClassicAPI)|r" or ""))
    local top = list[1].v > 0 and list[1].v or 1
    local width = 300
    local tex = (M.S and M.S(win) and M.S(win).texture) or "Interface\\TargetingFrame\\UI-StatusBar"
    for i = 1, n do
      local e = list[i]
      local rr = Row(i)
      rr:ClearAllPoints()
      rr:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(PAD + 40 + (i - 1) * (ROW + 2)))
      rr:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
      rr.icon:SetTexture(e.plain and QUESTION or Icon(e.name, e.id))
      if e.plain then
        -- sources / targets: their class picture when they are a player of the group, else none
        local w = M.Who and M.Who(e.name)
        local ct = w and w.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[w.class]
        if ct then
          rr.icon:SetTexture(pfUI.media["img:classicons"])
          rr.icon:SetTexCoord(ct[1], ct[2], ct[3], ct[4])
        else
          rr.icon:SetTexCoord(.08, .92, .08, .92)
        end
      else
        rr.icon:SetTexCoord(.08, .92, .08, .92)
      end
      rr.bar:SetStatusBarTexture(tex)
      rr.bar:SetStatusBarColor(r, g, b, .85)
      rr.bar:SetValue(max(0, min(1, e.v / top)))
      rr.name:SetFont(font, 12, "OUTLINE")
      rr.name:SetText(e.name or "?")
      rr.value:SetFont(font, 12, "OUTLINE")
      local v = mode.text and mode.text(e.v) or Num(e.v)
      local ps = e.ps or (secs and secs > 0 and not e.plain and e.v / secs)
      local pct = total > 0 and floor(e.v / total * 100 + .5) .. "%" or ""
      rr.value:SetText(v .. (ps and ("  |cffb0b0b0(" .. Num(ps) .. ")|r") or "") .. "  " .. pct)
      local need = (rr.name:GetStringWidth() or 0) + (rr.value:GetStringWidth() or 0) + ICON + 30
      if need > width then width = min(460, need) end
      rr:Show()
    end
    for i = n + 1, table.getn(f.rows) do f.rows[i]:Hide() end
    f.foot:ClearAllPoints()
    f.foot:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(PAD + 40 + n * (ROW + 2) + 2))
    f.foot:SetFont(font, 10, "")
    f.foot:SetTextColor(.5, .52, .56)
    local more = table.getn(list) - n
    f.foot:SetText((more > 0 and ("+" .. more .. " more   ") or "") .. "Click for the full breakdown")
    f:SetWidth(width + PAD * 2)
    f:SetHeight(PAD + 40 + n * (ROW + 2) + 18 + PAD)
    -- beside the window, on the side with room
    f:ClearAllPoints()
    local x = win:GetCenter()
    local sw = UIParent:GetWidth() or 1024
    if x and x * (win:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1) > sw / 2 then
      f:SetPoint("TOPRIGHT", bar, "TOPLEFT", -8, 0)
    else
      f:SetPoint("TOPLEFT", bar, "TOPRIGHT", 8, 0)
    end
    f:Show()
    return true
  end
  function M.HoverHide() f:Hide() end
end)
