pfUI:RegisterModule("actionbar-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Action Bars section (user, 22 Oct 2026: "the menu inside
  -- our addon should be SIMPLE and CLEAN and PROFESSIONAL"). Five pages:
  -- General (looks, look colours, behaviour), Bars (a tab per bar: layout,
  -- visibility, text), Buttons (every effect), Paging, Gryphons. Every
  -- setting of pfUI's old Actionbar pages is here (that category is hidden),
  -- plus the extras of actionbar-octo.lua. A pinned preview on General, Bars
  -- and Buttons: your real bars, drawn in their look, on a small copy of the
  -- screen (click one for its tab, Shift + wheel for its button size) and a
  -- sample button with every effect.
  -- 25 Oct 2026 (user: "on the whole it looks kind of messy the preview also
  -- looks off"): looks are picture tiles, colours of every part of a look in
  -- one card, small controls in even columns (Grid), picked tabs and tiles in
  -- the pick-one purple of the colour rule (octo-options.lua W.ROLE).
  local AB = pfUI.barsOcto
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not AB or not W or not O or not O.AddPage then return end
  local BUILD = {}
  local PfChk, PfSld = O.PfChk, O.PfSld
  local ICON = "Interface\\Icons\\"

  local TAB = { cur = 1 }
  local function G() return C.bars end
  local function BAR() return C.bars["bar" .. TAB.cur] end
  local function GRY() return C.bars.gryphons end
  local function U() pfUI.bars:UpdateConfig() end
  local function UG() if pfUI.gryphons and pfUI.gryphons.UpdateConfig then pfUI.gryphons:UpdateConfig() end end
  local function Px(v) return v .. " px" end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Sec(v) return v .. " s" end
  local function Str(r, g, b, a) return string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1) end

  local function Chk(p, label, desc, group, key, after) return PfChk(p, label, desc, group, key, after or U) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt, after) return PfSld(p, label, desc, min, max, step, group, key, after or U, fmt) end
  local function Drop(p, label, desc, options, group, key, after)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v)
      group()[key] = v
      ;(after or U)()
    end)
  end
  local function Color(p, label, desc, group, key, after)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      ;(after or U)()
    end)
  end
  -- pfUI's "key:label" dropdown lists
  local function DD(name)
    local out = {}
    local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns[name]
    if type(list) == "function" then list = list() end
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l }) end
    end
    return out
  end

  -- ---------------------------------------------------------------- small parts

  -- a pick-one button (bar tabs, look tiles): a purple wash when picked
  local function PickPaint(b, on)
    b.picked = on
    local pc = W.ROLE and W.ROLE.pick or { .68, .45, 1 }
    local c = W.C
    if on then
      b:SetBackdropColor(pc[1] * .3, pc[2] * .3, pc[3] * .3, 1)
      b:SetBackdropBorderColor(pc[1], pc[2], pc[3], 1)
      if b.label then b.label:SetTextColor(1, 1, 1) end
    else
      b:SetBackdropColor(c.btn[1], c.btn[2], c.btn[3], 1)
      b:SetBackdropBorderColor(c.line[1], c.line[2], c.line[3], 1)
      if b.label then b.label:SetTextColor(c.dim[1], c.dim[2], c.dim[3]) end
    end
  end

  -- the game's colour picker for get() -> r, g, b, a / set(r, g, b, a)
  local function OpenPicker(get, set, after)
    local r, g, b, a = get()
    ColorPickerFrame.func = function()
      local nr, ng, nb = ColorPickerFrame:GetColorRGB()
      set(nr, ng, nb, 1 - OpacitySliderFrame:GetValue())
      after()
    end
    ColorPickerFrame.opacityFunc = ColorPickerFrame.func
    ColorPickerFrame.cancelFunc = function()
      set(r, g, b, a)
      after()
    end
    ColorPickerFrame.hasOpacity = 1
    ColorPickerFrame.opacity = 1 - (a or 1)
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ShowUIPanel(ColorPickerFrame)
  end

  -- grid items: a tick box bound to a pfUI "1" / "0" key, or a colour
  -- (used: dims the colour while what it paints is not in use)
  local function Tick(label, desc, group, key, after)
    return { kind = "tick", label = label, desc = desc, group = group, key = key, after = after }
  end
  local function Colour(label, desc, get, set, used)
    return { kind = "colour", label = label, desc = desc, get = get, set = set, used = used }
  end
  -- a colour kept as "r,g,b,a" under group()[key]
  local function KeyColour(label, desc, group, key, used, after)
    return Colour(label, desc, function()
      return AB.ParseColor(group()[key] or "1,1,1,1")
    end, function(r, g, b, a)
      group()[key] = Str(r, g, b, a)
      ;(after or U)()
    end, used)
  end

  -- small controls in even columns, cols to a row (user, 25 Oct 2026: the
  -- Behaviour tick boxes sat unevenly)
  local function Grid(p, cols, items)
    local w = math.floor((W.CW + 8) / cols)
    local row
    for n, item in ipairs(items) do
      local d = item
      local col = math.mod(n - 1, cols)
      if col == 0 then row = W.Row(p, 24, 0, 4) end
      local cell = CreateFrame("Frame", nil, row)
      cell:SetWidth(w - 8)
      cell:SetHeight(24)
      cell:SetPoint("LEFT", row, "LEFT", col * w, 0)
      local ctl, Refresh
      if d.kind == "tick" then
        ctl = W.CheckBox(cell, 16)
        Refresh = function() ctl:SetChecked(d.group()[d.key] == "1" and 1 or nil) end
      else
        ctl = W.Swatch(cell, 16)
        -- (the tests' list of every colour picker)
        if W.ColorMade then W.ColorMade(d.label, d.get) end
        Refresh = function()
          ctl.fill:SetVertexColor(d.get())
          local off = d.used and not d.used()
          cell:SetAlpha(off and .4 or 1)
          -- (dimmed: the tooltip says why)
          local tip = (d.desc or "Click to pick a colour.") .. (off and "\n\n|cffaaaaaaNot in use with the look / style picked now.|r" or "")
          ctl.tipText = tip
          if cell.hit then cell.hit.tipText = tip end
        end
      end
      ctl:SetPoint("LEFT", cell, "LEFT", 2, 0)
      local fs = W.Font(cell:CreateFontString(nil, "OVERLAY"), 12, W.C.text[1], W.C.text[2], W.C.text[3])
      fs:SetPoint("LEFT", ctl, "RIGHT", 8, 0)
      fs:SetWidth(w - 40)
      fs:SetHeight(16)
      fs:SetJustifyH("LEFT")
      fs:SetText(d.label)
      local function Click()
        if d.kind == "tick" then
          d.group()[d.key] = ctl:GetChecked() and "1" or "0"
          ;(d.after or U)()
          W.Changed()
        else
          OpenPicker(d.get, d.set, function() Refresh() W.Changed() end)
        end
      end
      ctl:SetScript("OnClick", Click)
      -- the words work as the box does
      local hit = CreateFrame("Button", nil, cell)
      hit:SetPoint("TOPLEFT", fs, "TOPLEFT", -2, 2)
      hit:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 2, -2)
      hit:SetScript("OnClick", function()
        if d.kind == "tick" then ctl:SetChecked(not ctl:GetChecked() and 1 or nil) end
        Click()
      end)
      local tip = ctl.tipText or d.desc or (d.kind == "colour" and "Click to pick a colour." or nil)
      W.Tip(ctl, d.label, tip)
      W.Tip(hit, d.label, tip)
      cell.hit = hit
      if p.key then table.insert(W.index, { page = p, card = p.cur, label = d.label, desc = d.desc, region = row }) end
      table.insert(p.items, { Refresh = Refresh })
      Refresh()
    end
  end

  -- the skin in use, its colours and sizes
  local function SK() return AB.SKINBY[C.bars.skin or "pfui"] or AB.SKINBY.pfui end
  local function Part(label, desc, part)
    return Colour(label, desc, function() return AB.PartColor(SK(), part) end, function(r, g, b, a)
      C.bars["skin_" .. part] = Str(r, g, b, a)
      C.bars["skin_" .. part .. "_class"] = "0"
      U()
    end, function() return SK()[part] and true or false end)
  end
  -- a change to any of these redraws a look
  function AB.LookSig()
    local b = C.bars
    local s = (b.skin or "") .. (b.zoom or "") .. (b.slot_style or "") .. (b.slot_color or "") .. (b.slot_color_class or "")
      .. (b.skin_edgesize or "") .. (b.skin_outersize or "")
    for _, part in ipairs(AB.PARTS) do s = s .. (b["skin_" .. part] or "") .. (b["skin_" .. part .. "_class"] or "") end
    return s
  end
  local function FirstIcon()
    local first = pfUI.bars[1] and pfUI.bars[1][1]
    local tex = first and first.icon and first.icon:GetTexture()
    return (tex and tex ~= "") and tex or "Interface\\Icons\\Spell_Fire_FlameBolt"
  end

  -- ---------------------------------------------------------------- preview

  -- A small copy of the screen with your real bars: every button drawn as on
  -- screen (its icon, its look, empty slots only where the bar shows them,
  -- the bar's backdrop only where it has one), and a sample button with the
  -- look and every effect. select: the bar of the open tab is outlined.
  local function Mini(box, select)
    local M = { rects = {} }
    local BW, BH = box:GetWidth() or 640, box:GetHeight() or 190
    local sideW = 170
    -- the view: the part of the screen your bars are in, zoomed to fill the
    -- room left of the sample button (user, 22 Oct 2026: a whole-screen copy
    -- left the bars tiny). Worked out again on every refresh.
    local VW, VH = BW - sideW - 18, BH - 12
    local scr = CreateFrame("Frame", nil, box)
    scr:SetWidth(VW)
    scr:SetHeight(VH)
    scr:SetPoint("LEFT", box, "LEFT", 6, 0)
    local bg = scr:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(scr)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetGradient("VERTICAL", .05, .07, .09, .12, .15, .19)
    -- a line between the bars and the sample
    local split = box:CreateTexture(nil, "ARTWORK")
    split:SetTexture("Interface\\Buttons\\WHITE8X8")
    split:SetVertexColor(W.C.line[1], W.C.line[2], W.C.line[3], 1)
    split:SetWidth(1)
    split:SetPoint("TOP", box, "TOPRIGHT", -sideW - 6, -8)
    split:SetPoint("BOTTOM", box, "BOTTOMRIGHT", -sideW - 6, 8)
    local ui = UIParent:GetEffectiveScale() or 1
    local k, ox, oy = 1, 0, 0

    local function PaintRect(r)
      local bar = pfUI.bars[r.i]
      local d = C.bars["bar" .. r.i]
      local back = d and d.background == "1"
      if back then
        local br, bgg, bb, ba
        if bar and bar.backdrop and bar.backdrop.GetBackdropColor then br, bgg, bb, ba = bar.backdrop:GetBackdropColor() end
        r:SetBackdropColor(tonumber(br) or .06, tonumber(bgg) or .06, tonumber(bb) or .06, tonumber(ba) or .8)
      else
        r:SetBackdropColor(0, 0, 0, 0)
      end
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      if r.hover then
        r:SetBackdropBorderColor(1, 1, 1, .7)
      elseif select and TAB.cur == r.i then
        r:SetBackdropBorderColor(ar, ag, ab, 1)
      elseif back then
        r:SetBackdropBorderColor(0, 0, 0, 1)
      else
        r:SetBackdropBorderColor(0, 0, 0, 0)
      end
    end

    local function Rect(i)
      local r = M.rects[i]
      if r then return r end
      r = CreateFrame("Button", nil, scr)
      r.i = i
      r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
                      insets = { left = 0, right = 0, top = 0, bottom = 0 } })
      r.btns = {}
      r:SetScript("OnEnter", function()
        this.hover = true
        PaintRect(this)
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine(AB.NAMES[this.i])
        GameTooltip:AddLine("Click: its settings", 1, 1, 1)
        GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller buttons", 1, 1, 1)
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() this.hover = nil PaintRect(this) GameTooltip:Hide() end)
      r:SetScript("OnClick", function()
        TAB.cur = this.i
        O:Open("abbars")
        O:Refresh()
      end)
      r:EnableMouseWheel(true)
      r:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() then
          local d = C.bars["bar" .. this.i]
          d.icon_size = tostring(math.max(10, math.min(64, (tonumber(d.icon_size) or 20) + (arg1 or 0))))
          U()
        elseif pfUI.plates and pfUI.plates.PassWheel then
          pfUI.plates.PassWheel(this)
        end
      end)
      M.rects[i] = r
      return r
    end

    -- a frame's place on screen, in UIParent's units
    local function Box(region)
      local l, t, r, b = region:GetLeft(), region:GetTop(), region:GetRight(), region:GetBottom()
      if not (l and t and r and b) then return end
      local s = (region:GetEffectiveScale() or 1) / ui
      return l * s, t * s, r * s, b * s
    end

    -- where it sits in the view
    local function Place(f, region)
      local l, t, r, b = Box(region)
      if not l then return end
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", scr, "TOPLEFT", (l - ox) * k, (t - oy) * k)
      f:SetWidth(math.max(2, (r - l) * k))
      f:SetHeight(math.max(2, (t - b) * k))
      return true
    end

    -- the view frames every shown bar with a margin, centred
    local function Frame()
      local ul, ut, ur, ub
      for _, i in ipairs(AB.ORDER) do
        local bar = pfUI.bars[i]
        if bar and bar:IsShown() then
          local l, t, r, b = Box(bar)
          if l then
            ul, ur = math.min(ul or l, l), math.max(ur or r, r)
            ut, ub = math.max(ut or t, t), math.min(ub or b, b)
          end
        end
      end
      if not ul then return end
      local m = 16
      local w, h = (ur - ul) + 2 * m, (ut - ub) + 2 * m
      k = math.min(VW / w, VH / h, 1.6)
      -- centre what the bars cover in the view
      ox = ul - m - (VW / k - w) / 2
      oy = ut + m + (VH / k - h) / 2
    end

    -- a copy of a button: real size, shrunk by the view's scale, so its look
    -- (lines, halo, gloss) keeps the real proportions
    local function MiniButton(r)
      local mb = CreateFrame("Frame", nil, r)
      mb:SetFrameLevel(r:GetFrameLevel() + 3)
      CreateBackdrop(mb)
      -- (the picture on its own layer, on top: under the copies' parts every
      -- icon came out dark - user, 26 Oct 2026 "still dark")
      mb.art = CreateFrame("Frame", nil, mb)
      mb.art:SetAllPoints(mb)
      mb.art:SetFrameLevel(mb:GetFrameLevel() + 6)
      mb.icon = mb.art:CreateTexture(nil, "OVERLAY")
      mb.icon:SetAllPoints(mb)
      return mb
    end

    function M.Refresh()
      Frame()
      local sig = AB.LookSig() .. k
      local redraw = sig ~= M.sig
      M.sig = sig
      for _, i in ipairs(AB.ORDER) do
        local bar = pfUI.bars[i]
        local r = Rect(i)
        if bar and bar:IsShown() and Place(r, bar) then
          PaintRect(r)
          for j = 1, 12 do
            local btn = bar[j]
            local mb = r.btns[j]
            -- (pfUI hides an empty slot's backdrop when the bar hides empty slots)
            local shown = btn and btn:IsShown() and not (btn.backdrop and not btn.backdrop:IsShown())
            local l, t, rr, bb
            if shown then l, t, rr, bb = Box(btn) end
            if l then
              local fresh = not mb
              if not mb then
                mb = MiniButton(r)
                r.btns[j] = mb
              end
              mb:SetScale(math.max(.05, k))
              mb:ClearAllPoints()
              -- (offsets are in the copy's own, shrunk units)
              mb:SetPoint("TOPLEFT", scr, "TOPLEFT", l - ox, t - oy)
              local w, h = math.max(2, rr - l), math.max(2, t - bb)
              local resized = math.abs((mb.w or 0) - w) > .5
              mb.w = w
              mb:SetWidth(w)
              mb:SetHeight(h)
              local tex = btn.icon and btn.icon:GetTexture()
              if tex and tex ~= "" then mb.icon:SetTexture(tex) mb.icon:Show() else mb.icon:Hide() end
              if fresh or redraw or resized then
                AB.Zoom(mb)
                AB.Draw(mb, C.bars.skin)
                AB.Slot(mb)
                -- (no inner shade or frame overlay on these tiny copies: they covered
                -- most of each icon - user, 26 Oct 2026 "so dark i cant see the
                -- bars"; the sample button on the right shows the whole look)
                for _, kk in ipairs({ "octoShade", "octoFrame" }) do
                  if mb[kk] then mb[kk].want = nil mb[kk]:Hide() end
                end
              end
              mb:Show()
            elseif mb then
              mb:Hide()
            end
          end
          r:Show()
        else
          r:Hide()
        end
      end
    end

    -- the sample button, with the look
    local side = CreateFrame("Frame", nil, box)
    side:SetWidth(sideW)
    side:SetHeight(BH - 10)
    side:SetPoint("RIGHT", box, "RIGHT", -6, 0)
    local cap = W.Font(side:CreateFontString(nil, "OVERLAY"), 10, W.C.dim[1], W.C.dim[2], W.C.dim[3])
    cap:SetPoint("TOP", side, "TOP", 0, -4)
    cap:SetText("SAMPLE BUTTON")
    local b = CreateFrame("Frame", nil, side)
    b:SetWidth(64)
    b:SetHeight(64)
    b:SetPoint("CENTER", side, "CENTER", 0, 4)
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints(b)
    CreateBackdrop(b)
    -- each text in its own corner, as on a real button
    b.hotkey = b:CreateFontString(nil, "OVERLAY")
    b.hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)
    b.macro = b:CreateFontString(nil, "OVERLAY")
    b.macro:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 3)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.cd = b:CreateFontString(nil, "OVERLAY")
    b.cd:SetPoint("CENTER", b, "CENTER", 0, 2)
    -- the cooldown: a dark sweep down the button (as pfUI's on 1.12)
    b.sweep = b:CreateTexture(nil, "OVERLAY")
    b.sweep:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.sweep:SetVertexColor(0, 0, 0, .65)
    b.sweep:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.sweep:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.sweep:Hide()
    -- the press animation, made as pfUI makes it for a real button
    b.animation = CreateFrame("Frame", nil, b)
    b.animation.parent = b
    b.animation:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.animation:SetFrameLevel(b:GetFrameLevel() + 6)
    b.animation.tex = b.animation:CreateTexture(nil, "BACKGROUND")
    b.animation.tex:SetTexCoord(.08, .92, .08, .92)
    b.animation.tex:SetAllPoints(b.animation)
    b.animation:Hide()
    -- the effects (actionbar-octo.lua), as on a real button
    b.hover = AB.Layer(b, 2)
    b.press = AB.Layer(b, 3)
    -- pfUI's own hover glow
    b.pfhl = CreateFrame("Frame", nil, b)
    b.pfhl:SetAllPoints(b)
    b.pfhl:SetFrameLevel(b:GetFrameLevel() + 2)
    b.pfhl:SetBackdrop({ edgeFile = pfUI.media["img:glow"], edgeSize = 8 })
    b.pfhl:SetBackdropBorderColor(1, 1, 1, .8)
    b.pfhl:Hide()
    -- an empty slot (left) and an equipped item (right), small as on a bar
    local function Small(anchor, x)
      local s = CreateFrame("Frame", nil, side)
      s:SetWidth(28) s:SetHeight(28)
      s:SetPoint(anchor, b, anchor == "RIGHT" and "LEFT" or "RIGHT", x, -18)
      s.icon = s:CreateTexture(nil, "BACKGROUND")
      s.icon:SetAllPoints(s)
      CreateBackdrop(s)
      return s
    end
    local empty = Small("RIGHT", -12)
    local worn = Small("LEFT", 12)
    worn.icon:SetTexture("Interface\\Icons\\INV_Jewelry_Talisman_07")
    worn.tint = worn:CreateTexture(nil, "OVERLAY")
    worn.tint:SetAllPoints(worn)
    worn.edge = AB.Layer(worn, 2)
    local note = W.Font(side:CreateFontString(nil, "OVERLAY"), 11, W.C.dim[1], W.C.dim[2], W.C.dim[3])
    note:SetPoint("BOTTOM", side, "BOTTOM", 0, 4)
    note:SetWidth(sideW - 6)
    b.note = note

    -- every part of the sample opens its setting (pfUI.plates.OpenSection
    -- opens a page at a card)
    local function Hot(region, title, card, page, level)
      local h = CreateFrame("Button", nil, side)
      h:SetFrameLevel(b:GetFrameLevel() + (level or 10))
      h:SetAllPoints(region)
      h.hl = h:CreateTexture(nil, "OVERLAY")
      h.hl:SetAllPoints(h)
      h.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
      h.hl:SetVertexColor(1, 1, 1, .2)
      h.hl:Hide()
      h:SetScript("OnEnter", function()
        this.hl:Show()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine(title)
        GameTooltip:AddLine("Click to change it", 1, 1, 1)
        GameTooltip:Show()
      end)
      h:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
      h:SetScript("OnClick", function()
        -- (the note's target follows what the sample is showing)
        local pg, cd = page, card
        if this.follow then pg, cd = b.notePage or page, b.noteCard or card end
        if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection(pg, cd) else O:Open(pg) end
      end)
      return h
    end
    Hot(empty, "Empty slot fill", "Button", "abbuttons")
    Hot(worn, "Equipped item mark", "Equipped items", "abbuttons")
    -- the button itself opens what it is showing (hover, press, glow...),
    -- else its border and icon
    local whole = Hot(b, "This button", "Button", "abbuttons", 8)
    whole.follow = true
    whole:SetScript("OnEnter", function()
      this.hl:Show()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:AddLine("Sample button")
      GameTooltip:AddLine("Click: the settings for what it shows now (" .. (b.noteCard or "Button") .. ")", 1, 1, 1)
      GameTooltip:AddLine("Its letters and cooldown number open their own", .7, .7, .7)
      GameTooltip:Show()
    end)
    Hot(b.hotkey, "Key text", "Letters", "abbuttons")
    Hot(b.macro, "Macro text", "Letters", "abbuttons")
    Hot(b.count, "Count text", "Letters", "abbuttons")
    -- the cooldown number comes and goes, so its spot is a fixed square
    local cdSpot = CreateFrame("Frame", nil, b)
    cdSpot:SetWidth(30) cdSpot:SetHeight(24)
    cdSpot:SetPoint("CENTER", b, "CENTER", 0, 0)
    Hot(cdSpot, "Cooldown swipe and number", "Cooldown swipe", "abbuttons")
    Hot(note, "What the sample shows now", "Button", "abbuttons").follow = true

    local function Text(fs, size, color, text)
      local font = pfUI.media[C.bars.font] or pfUI.font_default
      -- (the sample is about twice a real button: the texts grow with it)
      fs:SetFont(font, (tonumber(size) or 10) * 1.4, "OUTLINE")
      local r, g, bb = GetStringColor(color or "1,1,1,1")
      fs:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(bb) or 1)
      fs:SetText(text)
    end
    function M.Sample()
      b.icon:SetTexture(FirstIcon())
      AB.Zoom(b)
      AB.Skin(b)
      -- the small ones wear the look too
      AB.Draw(empty, C.bars.skin)
      AB.Draw(worn, C.bars.skin)
      AB.Zoom(worn)
      Text(b.hotkey, C.bars.bind_size, C.bars.bind_color, "S1")
      Text(b.macro, C.bars.macro_size, C.bars.macro_color, "Mac")
      Text(b.count, C.bars.count_size, C.bars.count_color, "20")
      Text(b.cd, C.bars.cd_size, "1,1,1,1", b.cd:GetText() or "")
      b.animation:SetScript("OnUpdate", pfUI.bars.animations and pfUI.bars.animations[C.bars.animation] or nil)
      -- effects
      AB.Slot(empty, empty)
      local eq = C.bars.eq_style or "fill"
      local tr, tg, tb, ta = GetStringColor(C.bars.eqcolor or ".2,.8,.2,.2")
      worn.tint:SetTexture(tonumber(tr) or .2, tonumber(tg) or .8, tonumber(tb) or .2, tonumber(ta) or .2)
      if C.bars.showequipped == "1" and (eq == "fill" or eq == "both") then worn.tint:Show() else worn.tint:Hide() end
      worn.edge.fill:Hide()
      if C.bars.showequipped == "1" and (eq == "border" or eq == "both") then
        AB.Edges(worn.edge, tonumber(C.bars.eq_size) or 2, .64, .21, .93, 1)  -- an epic's purple
        worn.edge:Show()
      else
        worn.edge:Hide()
      end
      b.hoverPfui = not AB.Paint(b.hover, "hover")
      b.pressOn = AB.Paint(b.press, "press") and C.bars.press_style ~= "none"
      -- a changed glow setting repaints a lit glow
      local sig = (C.bars.glow_style or "") .. (C.bars.glow_color or "") .. (C.bars.glow_color_class or "")
        .. (C.bars.glow_thick or "") .. (C.bars.glow_burst or "")
      if sig ~= b.glowSig and b.octoGlow then b.octoGlow.lit = nil end
      b.glowSig = sig
    end

    -- The sample in use, on a 13 s loop: a 6 s cooldown with the chosen swipe
    -- and the counting number; a press (press look + animation); a hover; the
    -- highlight colours (out of range, out of mana, not usable); a proc glow.
    -- The note says what shows, and clicking it opens that setting.
    local LOOP = 13
    local STATES = {
      { 7.5, 8.3, "glowrange", "rangecolor", "out of range" },
      { 8.3, 9.1, "showoom", "oomcolor", "out of mana" },
      { 9.1, 9.9, "showna", "nacolor", "not usable" },
    }
    local function Note(text, page, card)
      b.note:SetText(text)
      b.notePage, b.noteCard = page, card
    end
    -- Test buttons play one part of the loop on demand: { from, to, seconds }
    M.PLAYS = {
      cooldown = { 0, 6.2, 6.2 },
      press = { 5.95, 6.4, .6 },
      hover = { 7, 7, 2.5 },
      highlights = { 7.5, 9.9, 2.4 },
      glow = { 10, 12.9, 4 },
    }
    function M.Play(kind)
      local pl = M.PLAYS[kind]
      if not pl then return end
      M.force = { pl[1], pl[2], pl[3], GetTime() }
      b.pressed = kind ~= "cooldown" and kind ~= "press" and true or nil
      if kind == "glow" and b.octoGlow then AB.Glow(b, false) end
    end
    function M.Animate(now)
      local t = math.mod(now, LOOP)
      local key = math.floor(now / LOOP)
      local f = M.force
      if f then
        local e = now - f[4]
        if e < f[3] then
          t = f[1] + (f[2] - f[1]) * e / f[3]
          key = "test" .. f[4]
        else
          M.force = nil
        end
      end
      local size = b:GetHeight() or 64
      local style = C.bars.cd_style or "clock"
      -- cooldown
      if t < 6 then
        if style == "clock" then
          b.sweep:SetHeight(math.max(1, size * (6 - t) / 6))
          b.sweep:Show()
        else
          b.sweep:Hide()
          -- (the real swipe, started once per loop and on a style change)
          if not b.drainFor or b.drainFor ~= style .. key then
            b.drainFor = style .. key
            AB.Drain(b, now - t, 6, 1)
          end
        end
        -- pfUI's own cooldown text, so its colours and tenths show as in game
        b.cd:SetTextColor(1, 1, 1)
        b.cd:SetText(GetColoredTimeString(6 - t))
        Note("cooldown", "abbuttons", "Cooldown swipe")
      else
        b.sweep:Hide()
        if b.octoDrain then b.octoDrain:Hide() end
        b.drainFor = nil
        b.cd:SetText("")
        Note("ready", "abbuttons", "Button")
      end
      -- the press: the press look held for a moment, and the press animation
      if t >= 6 and t < 6.35 then
        if b.pressOn then b.press:Show() else b.press:Hide() end
        Note("pressed", "abbuttons", "Hover and press")
      else
        b.press:Hide()
      end
      if t >= 6 and not b.pressed then
        b.pressed = true
        if C.bars.animation ~= "none" then
          b.animation.active = 0
          b.animation:Show()
        end
      elseif t < 6 then
        b.pressed = nil
      end
      -- the hover
      if t >= 6.5 and t < 7.5 then
        if b.hoverPfui then b.pfhl:Show() b.hover:Hide() else b.pfhl:Hide() b.hover:Show() end
        Note("mouse over", "abbuttons", "Hover and press")
      else
        b.pfhl:Hide()
        b.hover:Hide()
      end
      -- highlight colours
      local r, g, bl = 1, 1, 1
      for _, s in ipairs(STATES) do
        if t >= s[1] and t < s[2] and C.bars[s[3]] == "1" then
          r, g, bl = GetStringColor(C.bars[s[4]] or "1,1,1,1")
          Note(s[5], "abbuttons", "Highlights")
        end
      end
      b.icon:SetVertexColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(bl) or 1)
      -- a proc
      local glow = t >= 10
      AB.Glow(b, glow)
      if glow then Note("proc glow", "abbuttons", "Proc glow") end
      -- a button on the bars lights up now and then, as if pressed
      if (M.flashAt or 0) < now then
        M.flashAt = now + .7
        if M.lit then M.lit:SetVertexColor(1, 1, 1) end
        M.lit = nil
        local all = {}
        for _, r2 in pairs(M.rects) do
          if r2:IsShown() then
            for _, mb in pairs(r2.btns) do if mb:IsShown() and mb.icon:IsShown() then table.insert(all, mb.icon) end end
          end
        end
        local n = table.getn(all)
        if n > 0 then
          M.lit = all[math.random(1, n)]
          M.lit:SetVertexColor(.55, .55, .55)
        end
      end
    end

    box:SetScript("OnUpdate", function()
      local now = GetTime()
      M.Animate(now)
      if (this.tick or 0) > now then return end
      this.tick = now + .5
      M.Refresh()
      M.Sample()
    end)
    M.Refresh()
    M.Sample()
    return M
  end

  local TESTS = {
    { "cooldown", "Cooldown", "The swipe and the number counting down." },
    { "press", "Press", "The press look and the press animation." },
    { "hover", "Hover", "The look while the mouse is over a button." },
    { "glow", "Proc glow", "The glow, with its burst." },
    { "highlights", "Highlights", "Out of range, out of mana, not usable." },
  }

  local function Preview(p, tests, select)
    W.Pin(p, "Preview", "Your bars on a small copy of the screen, drawn in their look, and a sample button. Click a bar for its "
      .. "settings, hold Shift and scroll the mouse wheel over it for bigger or smaller buttons. Move frames (top) "
      .. "moves the bars themselves. Click this bar to fold it away.", function(p)
      local mini = Mini((W.ZoomBox or W.Box)(p, 150), select)
      table.insert(p.items, { Refresh = function() mini.Refresh() mini.Sample() end })
      -- test buttons: one effect on the sample now, or all of them on your bars
      if tests then
        local row = W.Row(p, 24, 0, 6)
        local x = 0
        for _, tt in ipairs(TESTS) do
          local bt = W.Button(row, "Test: " .. tt[2], 118, 22)
          bt:SetPoint("LEFT", row, "LEFT", x, 0)
          bt.kind = tt[1]
          if W.Tint then W.Tint(bt, "go") end
          -- (lit while its effect plays)
          bt:SetScript("OnClick", function() this.litUntil = GetTime() + 3 mini.Play(this.kind) end)
          W.Tip(bt, "Test " .. string.lower(tt[2]), tt[3] .. " Plays on the sample button.")
          x = x + 124
        end
        local mine = W.Button(row, "Test on my bars", 140, 22)
        mine:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        if W.Tint then W.Tint(mine, "go") end
        mine:SetScript("OnClick", function() if GetTime() < (AB.testUntil or 0) then AB.testUntil = 0 else AB.Test(6) end end)
        W.Tip(mine, "Test on my bars", "For 6 seconds every button on your bars glows, runs a cooldown and flashes its press look. Click again to stop.")
        row:SetScript("OnUpdate", function()
          if (this.tick or 0) > GetTime() then return end
          this.tick = GetTime() + .2
          for _, bt in ipairs({ this:GetChildren() }) do
            if bt.kind then W.Lit(bt, GetTime() < (bt.litUntil or 0)) end
          end
          W.Lit(mine, GetTime() < (AB.testUntil or 0))
        end)
      end
      -- how to use it: a soft blue wash (blue = open) with white words
      local band = W.Row(p, 20, 0, 6)
      local open = W.ROLE and W.ROLE.open or { .35, .7, 1 }
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      bg:SetGradientAlpha("HORIZONTAL", open[1], open[2], open[3], .22, open[1], open[2], open[3], .04)
      local how = W.Font(band:CreateFontString(nil, "OVERLAY"), 11, 1, 1, 1)
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      how:SetText("Click a bar: its settings          Shift + wheel: button size          Move frames: move the bars")
      if W.HowTo then W.HowTo(p, band, how:GetText()) end
    end)
  end

  -- ---------------------------------------------------------------- general

  -- the looks as picture tiles, seven to a row: each draws a button in that
  -- look; the one in use is lit purple and shows your own colours
  local TILE_W, TILE_H, PER = 104, 76, 7
  local function Looks(p)
    local tiles = {}
    local row
    local function Paint(force)
      local cur = AB.CurrentLook()
      local sig = AB.LookSig() .. tostring(cur) .. FirstIcon()
      for _, t in ipairs(tiles) do
        if t.picked ~= (t.key == cur) or force then PickPaint(t, t.key == cur) end
        if force or sig ~= t.sig then
          t.sig = sig
          local mine = t.key == cur
          local z = mine and (tonumber(C.bars.zoom) or .08) or t.zoom
          t.sample.icon:SetTexture(FirstIcon())
          t.sample.icon:SetTexCoord(z, 1 - z, z, 1 - z)
          AB.Draw(t.sample, t.skin, not mine)
        end
      end
    end
    for i, pr in ipairs(AB.PRESETS) do
      local col = math.mod(i - 1, PER)
      if col == 0 then row = W.Row(p, TILE_H, 0, 6) end
      local t = W.Button(row, pr[2], TILE_W, TILE_H)
      t:SetPoint("LEFT", row, "LEFT", col * (TILE_W + 6), 0)
      t.label:ClearAllPoints()
      t.label:SetPoint("BOTTOM", t, "BOTTOM", 0, 8)
      local s = CreateFrame("Frame", nil, t)
      s:SetWidth(32)
      s:SetHeight(32)
      s:SetPoint("TOP", t, "TOP", 0, -11)
      s.icon = s:CreateTexture(nil, "BACKGROUND")
      s.icon:SetAllPoints(s)
      CreateBackdrop(s)
      t.sample = s
      t.key, t.skin, t.zoom = pr[1], pr[3].skin, tonumber(pr[3].zoom) or .08
      t:SetScript("OnClick", function()
        AB.ApplyPreset(this.key)
        Paint(true)
        O:Refresh()
      end)
      W.Tip(t, pr[2], (pr[5] or "") .. "\n\nClick to use it on every bar: border, icon zoom, spacing, bar backdrops and "
        .. "empty slots change with it. Its colours are under Look colours.")
      if p.key then table.insert(W.index, { page = p, card = p.cur, label = "Look: " .. pr[2], desc = pr[5], region = row }) end
      table.insert(tiles, t)
    end
    W.Live(p, function()
      local key, label, exact = AB.CurrentLook()
      if not key then return "In use: |cffffffffyour own mix|r" end
      local idea
      for _, pr in ipairs(AB.PRESETS) do if pr[1] == key then idea = pr[5] end end
      return "In use: |cffffffff" .. label .. (exact and "" or " with your own changes") .. "|r   " .. (idea or "")
    end)
    row:SetScript("OnUpdate", function()
      if (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + .5
      Paint()
    end)
    table.insert(p.items, { Refresh = function() Paint() end })
    Paint(true)
  end

  -- every colour of the look, four to a row
  local function LookColours(p)
    -- used unless its style is one of two
    local function Not(key, a, b)
      return function()
        local v = C.bars[key]
        return v ~= a and v ~= b
      end
    end
    Grid(p, 4, {
      Part("Border", "The line round each button.", "edge"),
      Part("Outline", "The thin line round the border (Pixel, Metal, Dark).", "line2"),
      Part("Glow / shadow", "The soft halo or shadow outside (Neon's halo, Clean's shadow).", "outer"),
      Part("Gloss", "The shine over the top of the icon. Its opacity is how strong it is.", "gloss"),
      Part("Inner shade", "The dark inner edges over the icon.", "shade"),
      Part("Game frame", "The game's own button frame (Game look).", "frame"),
      KeyColour("Empty slot", "What fills a slot behind the icon. Picking a colour turns the fill on.", G, "slot_color", nil, function()
        if (C.bars.slot_style or "pfui") == "pfui" then C.bars.slot_style = "solid" end
        U()
      end),
      Colour("Bar backdrop", "Behind a whole bar, on bars with Background on (Bars page).", function()
        local v = C.bars.bar_bg
        if not v or v == "" then v = C.appearance.border.background end
        return AB.ParseColor(v)
      end, function(r, g, b, a) C.bars.bar_bg = Str(r, g, b, a) U() end),
      KeyColour("Hover", "The hover look's colour (Buttons > Hover and press).", G, "hover_color", Not("hover_style", "pfui", "none")),
      KeyColour("Press", "The press look's colour (Buttons > Hover and press).", G, "press_color", Not("press_style", "pfui", "none")),
      KeyColour("Proc glow", nil, G, "glow_color"),
      KeyColour("Cooldown swipe", "The dark part of a draining swipe.", G, "cd_color", Not("cd_style", "clock", "none")),
    })
    Grid(p, 4, {
      Tick("Border: class colour", "The border in your class colour.", G, "skin_edge_class"),
      Tick("Glow: class colour", "The halo / shadow in your class colour.", G, "skin_outer_class"),
      Tick("Slot: class colour", nil, G, "slot_color_class"),
      Tick("Proc: class colour", nil, G, "glow_color_class", function() AB.GlowRepaint() U() end),
    })
    W.Slider(p, "Border thickness", "0 = no border line.", 0, 8, 1, function() return AB.PartSize(SK(), "edge") end,
      function(v) C.bars.skin_edgesize = tostring(v) U() end, Px)
    W.Slider(p, "Glow / shadow size", "0 = none.", 0, 16, 1, function() return AB.PartSize(SK(), "outer") end,
      function(v) C.bars.skin_outersize = tostring(v) U() end, Px)
    Sld(p, "Icon zoom", "Cuts the icon's edges: 0 = the whole picture.", 0, .25, .01, G, "zoom", Pct)
    W.Slider(p, "Spacing, every bar", "The space between buttons on all bars (one bar: Bars page).", 0, 20, 1,
      function() return tonumber(C.bars.bar1.spacing) or 1 end,
      function(v) for i = 1, 12 do C.bars["bar" .. i].spacing = tostring(v) end U() end, Px)
    W.Buttons(p, {
      { "Reset to the look's own colours", function() AB.ClearColors() U() end, 230,
        "Every colour and size above back to what the look in use came with." },
    })
  end

  BUILD.abgeneral = function(p)
    W.Heading(p, "Action bars", { on = O.ModuleSwitch("actionbar", "Action bars"), about = "Your action bars: their look, its colours, and how buttons behave. "
      .. "Each bar's layout and when it shows are on Bars; every button effect (hover, press, cooldown, glow, letters) on Buttons." })
    Preview(p)
    W.Card(p, "Looks", { icon = ICON .. "INV_Misc_Gem_Variety_01", tip = "Ready-made looks for every bar, from ideas in "
      .. "Masque's skins, ElvUI, Bartender and the game. Click one to use it." })
    Looks(p)
    W.Card(p, "Look colours", { icon = ICON .. "INV_Fabric_Silk_02", tip = "Every part of the look in your own colours. "
      .. "Parts the look in use does not have are dimmed. Picking another look starts from its own colours again." })
    LookColours(p)
    W.Card(p, "Behaviour", { icon = ICON .. "INV_Misc_Gear_01" })
    Grid(p, 4, {
      Tick("Cast on key down", "Actions go off when the key goes down, not when it comes back up.", G, "keydown"),
      Tick("Lock the bars", "Buttons cannot be dragged off.", function() return _G end, "LOCK_ACTIONBAR"),
      Tick("Shift-drag always", "Shift lets you drag a button even when the bars are locked.", G, "shiftdrag"),
      Tick("Reagent count", "How many reagents you carry, on spells that use them.", G, "reagents"),
      Tick("Self-cast: Alt", "Hold Alt to cast on yourself.", G, "altself"),
      Tick("Self-cast: right-click", "Right-click casts on yourself.", G, "rightself"),
      Tick("Spells in macros", "Macros show the cooldown, range and icon of the spell they cast.", G, "macroscan"),
      Tick("Pet autocast mark", "The mark on pet abilities that cast by themselves.", G, "showcastable"),
    })
  end

  -- ---------------------------------------------------------------- bars

  local VIS_COMBAT = { { key = "any", label = "Always" }, { key = "combat", label = "Only in combat" }, { key = "nocombat", label = "Only out of combat" } }
  local VIS_PET = { { key = "any", label = "Always" }, { key = "pet", label = "Only with a pet" }, { key = "nopet", label = "Only without a pet" } }
  local VIS_TARGET = { { key = "any", label = "Always" }, { key = "target", label = "Only with a target" } }
  local VIS_STEALTH = { { key = "any", label = "Always" }, { key = "hide", label = "Hide while stealthed" } }

  BUILD.abbars = function(p)
    W.Heading(p, "Bars", { about = "Pick a bar, then its layout, when it shows, and its text. Move frames (top) moves the bars." })
    Preview(p, false, true)
    -- the bars as tabs, two rows of six (pick one: purple)
    local rows = { W.Row(p, 24, 0, 8), W.Row(p, 24, 0, 4) }
    local tabs = {}
    for n, i in ipairs(AB.ORDER) do
      local b = W.Button(rows[(n <= 6) and 1 or 2], AB.NAMES[i], 124, 22)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(n - 1, 6) * 128.8, 0)
      b.i = i
      b:SetScript("OnClick", function()
        TAB.cur = this.i
        O:Refresh()
      end)
      tabs[n] = b
    end
    table.insert(p.items, { Refresh = function()
      for _, b in ipairs(tabs) do PickPaint(b, b.i == TAB.cur) end
    end })
    W.Card(p, "Layout", { on = { function() return BAR().enable == "1" end, function(v) BAR().enable = v and "1" or "0"; U() end,
      "This bar on or off." } })
    -- (user, 26 Oct 2026: "when i choose 9 buttons the right option should change to 1x9") the shapes
    -- listed are the ones for this bar's button count, and a new count keeps the shape nearest the old
    -- one (1 x 12 -> 1 x 9, 6 x 2 -> 3 x 3); a shape that does not fit the count made pfUI fall back to one row.
    local function Count()
      if TAB.cur == 11 then return math.max(1, GetNumShapeshiftForms and GetNumShapeshiftForms() or 10) end
      if TAB.cur == 12 then return NUM_PET_ACTION_SLOTS or 10 end
      return math.min(12, math.max(1, tonumber(BAR().buttons) or 12))
    end
    local function Shapes(n) return pfGridmath and pfGridmath[n] or {} end
    local function ShapeOf(ff)
      local c, r = string.gfind(tostring(ff or ""), "(%d+) x (%d+)")()
      return tonumber(c), tonumber(r)
    end
    local function Fits(n, ff)
      local c, r = ShapeOf(ff)
      return c and r and c * r == n
    end
    -- the shape for n buttons nearest the bar's current one (api.lua BarLayoutNearest; the bars use it too)
    local Nearest = BarLayoutNearest
    W.Dropdown(p, "Buttons", "How many buttons this bar has. Rows and columns changes to fit.", (function()
      local o = {}
      for n = 1, 12 do table.insert(o, { key = tostring(n), label = tostring(n) }) end
      return o
    end)(), function() return BAR().buttons end, function(v)
      BAR().buttons = v
      local n = math.min(12, math.max(1, tonumber(v) or 12))
      if not Fits(n, BAR().formfactor) then BAR().formfactor = Nearest(n, BAR().formfactor) end
      U()
    end)
    W.Dropdown(p, "Rows and columns", "How the buttons are laid out: columns x rows. Only the shapes that fit this bar's number of buttons are listed.", function()
      local o = {}
      for _, s in ipairs(Shapes(Count())) do
        local f = string.format("%d x %d", s[1], s[2])
        local tip = (s[2] == 1) and "One row." or (s[1] == 1) and "One column." or (s[2] .. " rows of " .. s[1] .. ".")
        table.insert(o, { key = f, label = f, tip = tip })
      end
      return o
    end, function()
      local n, ff = Count(), BAR().formfactor
      if Fits(n, ff) then return ff end
      return Nearest(n, ff)
    end, function(v) BAR().formfactor = v; U() end)
    Sld(p, "Button size", nil, 10, 64, 1, BAR, "icon_size", Px)
    Sld(p, "Spacing", "Space between the buttons.", 0, 20, 1, BAR, "spacing", Px)
    Sld(p, "Scale", "The whole bar bigger or smaller.", .5, 2, .05, BAR, "scale", Pct)
    Sld(p, "Opacity", nil, .1, 1, .05, BAR, "alpha", Pct)
    Grid(p, 3, {
      Tick("Background", "A backdrop behind the bar (its colour: General > Look colours).", BAR, "background"),
      Tick("Empty slots", "Show buttons with nothing on them.", BAR, "showempty"),
      Tick("Pageable", "This bar changes with the action bar page.", BAR, "pageable"),
    })
    -- (user, 25 Oct 2026: "match size buttons so you can easily match your
    -- other action bars"; one bar at a time: layout mode's Match size...)
    W.Buttons(p, { { "Match all bars to this one", function()
      local frames = {}
      for i = 1, 10 do if i ~= TAB.cur and pfUI.bars[i] then table.insert(frames, pfUI.bars[i]) end end
      local n = 0
      local function Do()
        n = AB.MatchAll(TAB.cur)
        U()
      end
      -- (bars stay where they are saved: pfUI.unlock.KeepPlaces)
      if pfUI.unlock and pfUI.unlock.KeepPlaces then pfUI.unlock.KeepPlaces(frames, Do) else Do() end
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. n .. " bars now match the " .. AB.NAMES[TAB.cur] .. ".")
      O:Refresh()
    end, 210, "Every other bar that is on gets this bar's button size, spacing and scale, so bars with the same buttons are the "
      .. "same size. Each stays where it is. One bar at a time: Move frames, click a bar, Match size..." } })
    W.Card(p, "Visibility", { icon = ICON .. "INV_Misc_Eye_01", tip = "When the bar shows. All the rules have to agree." })
    W.Dropdown(p, "Combat", nil, VIS_COMBAT, function() return BAR().vis_combat end, function(v) BAR().vis_combat = v; U() end)
    W.Dropdown(p, "Pet", nil, VIS_PET, function() return BAR().vis_pet end, function(v) BAR().vis_pet = v; U() end)
    W.Dropdown(p, "Target", nil, VIS_TARGET, function() return BAR().vis_target end, function(v) BAR().vis_target = v; U() end)
    W.Dropdown(p, "Stealth", nil, VIS_STEALTH, function() return BAR().vis_stealth end, function(v) BAR().vis_stealth = v; U() end)
    Grid(p, 3, {
      Tick("Fade out on mouse-off", "The bar fades after a moment without the mouse over it.", BAR, "autohide"),
      Tick("Show in combat", "While fading out: full again as soon as you fight.", BAR, "hide_combat"),
    })
    Sld(p, "Fade after", nil, 0, 10, .5, BAR, "hide_time", Sec)
    Sld(p, "Fade to", "0 = gone. Higher keeps a faint bar.", 0, 1, .05, BAR, "fadeto", Pct)
    W.Card(p, "Text")
    Grid(p, 3, {
      Tick("Key", "The key bound to each button.", BAR, "showkeybind"),
      Tick("Macro name", nil, BAR, "showmacro"),
      Tick("Count", "Items and charges left.", BAR, "showcount"),
    })
  end


  -- ---------------------------------------------------------------- buttons

  local function List(src)
    local out = {}
    for _, s in ipairs(src) do table.insert(out, { key = s.key, label = s.label, texture = s.path or (s.tex and (AB.ART .. s.tex)) or nil }) end
    return out
  end

  -- Everything about a button on one page, one card per part of the sample
  -- (user, 22 Oct 2026: "All options available for this button should be on
  -- the same page"). The sample's parts open these cards by title. In every
  -- card: menus and sliders two to a row, then colours and tick boxes in
  -- even columns.
  -- (31 Oct 2026, user: the menus are "overwhelming" - Action Bars first.
  -- Buttons had 9 cards in one long page: now tabs under the preview show one
  -- group at a time, as Unit Frames does.) { key, tab, picture, card titles }
  AB.BSECTIONS = {
    { "look", "Look", "INV_Misc_StoneTablet_05", { "Button", "Highlights", "Equipped items" } },
    { "hover", "Hover and press", "Spell_Holy_SearingLight", { "Hover and press" } },
    { "cd", "Cooldowns", "INV_Misc_PocketWatch_02", { "Cooldown swipe", "Countdown number", "When it is ready" } },
    { "glow", "Proc glow", "Spell_Holy_PowerInfusion", { "Proc glow" } },
    { "text", "Letters", "INV_Misc_Note_01", { "Letters" } },
  }
  AB.bsec = AB.bsec or "look"
  AB.BSECTION_OF = {}
  for _, s in ipairs(AB.BSECTIONS) do
    for _, t in ipairs(s[4]) do AB.BSECTION_OF[t] = s[1] end
  end

  function AB.BFilter(p)
    p = p or O.pages.abbuttons
    if not p or not p.cards or not p.abFirst then return end
    p.onReveal = p.onReveal or function(e)
      local s = e.card and AB.BSECTION_OF[e.card.title]
      if s and s ~= AB.bsec then AB.BSetSection(s, true) end
    end
    local prev, gap = p.abFirst, 13
    for _, c in ipairs(p.cards) do
      if (AB.BSECTION_OF[c.title] or "look") == AB.bsec then
        c.card:ClearAllPoints()
        c.card:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        c.card:Show()
        prev, gap = c.card, 9
      else
        c.card:Hide()
      end
    end
    p.last = prev
  end

  function AB.BSetSection(key, keepFolds)
    AB.bsec = key
    local p = O.pages.abbuttons
    if p then
      if not keepFolds then
        -- (only the first card opens; the others stay as you left them)
        for _, c in ipairs(p.cards) do
          if AB.BSECTION_OF[c.title] == key then
            if not W.IsOpen(c) then W.SetOpen(c, true) end
            break
          end
        end
      end
      AB.BFilter(p)
      local sb = getglobal((p.frame:GetName() or "") .. "ScrollBar")
      if sb then sb:SetValue(0) elseif p.frame.SetVerticalScroll then p.frame:SetVerticalScroll(0) end
    end
    if O.Refresh then O:Refresh() end
  end

  local function ButtonTabs(p)
    local row = W.Row(p, 24, 0, 6)
    local n = table.getn(AB.BSECTIONS)
    local w = math.floor((W.CW - (n - 1) * 4) / n)
    local tabs = {}
    for i, s in ipairs(AB.BSECTIONS) do
      local b = W.Button(row, s[2], w, 22)
      b:SetPoint("LEFT", row, "LEFT", (i - 1) * (w + 4), 0)
      b.key = s[1]
      local pic = b:CreateTexture(nil, "OVERLAY")
      pic:SetTexture(ICON .. s[3])
      pic:SetTexCoord(.08, .92, .08, .92)
      pic:SetWidth(16)
      pic:SetHeight(16)
      pic:SetPoint("LEFT", b, "LEFT", 5, 0)
      if b.label then
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", pic, "RIGHT", 5, 0)
        b.label:SetPoint("RIGHT", b, "RIGHT", -4, 0)
        b.label:SetJustifyH("LEFT")
      end
      W.Tip(b, s[2], "Shows: " .. table.concat(s[4], ", ") .. ".")
      b:SetScript("OnClick", function() AB.BSetSection(this.key) end)
      tabs[i] = b
    end
    table.insert(p.items, { Refresh = function()
      for _, b in ipairs(tabs) do W.Pick(b, b.key == AB.bsec) end
    end })
  end

  BUILD.abbuttons = function(p)
    W.Heading(p, "Buttons", { about = "Everything about a button. Pick a group with the tabs under the sample: its look, "
      .. "hover and press, cooldowns, proc glow or letters. Click a part of the sample button to jump to it; the Test buttons "
      .. "play an effect on the sample or on your own bars." })
    Preview(p, true)
    ButtonTabs(p)
    p.abFirst = p.last
    -- a click on the sample (or Find) for a card in another tab: that tab first
    local P = pfUI.plates
    if P and P.OpenSection and not AB.bwrapped then
      AB.bwrapped = true
      local OpenSection = P.OpenSection
      P.OpenSection = function(key, title)
        local sec = key == "abbuttons" and AB.BSECTION_OF[title]
        if sec and sec ~= AB.bsec then AB.BSetSection(sec, true) end
        return OpenSection(key, title)
      end
    end

    W.Card(p, "Button", { icon = ICON .. "INV_Misc_StoneTablet_05", tip = "The look round every button, the icon, and what fills an empty slot. Ready-made looks: General." })
    local skins = {}
    for _, s in ipairs(AB.SKINS) do table.insert(skins, { key = s.key, label = s.label }) end
    -- (another border starts from its own colours)
    Drop(p, "Border", nil, skins, G, "skin", function() AB.ClearColors() U() end)
    Drop(p, "Empty slot fill", "Behind the icon: shows in empty slots.", List(AB.SLOTS), G, "slot_style")
    Sld(p, "Icon zoom", "Cuts the icon's edges: 0 = the whole picture.", 0, .25, .01, G, "zoom", Pct)
    W.Slider(p, "Border thickness", "0 = no border line.", 0, 8, 1, function() return AB.PartSize(SK(), "edge") end,
      function(v) C.bars.skin_edgesize = tostring(v) U() end, Px)
    Grid(p, 4, {
      Part("Border colour", "The line round each button.", "edge"),
      Part("Glow / shadow", "The soft halo or shadow outside.", "outer"),
      KeyColour("Slot colour", nil, G, "slot_color"),
      Tick("Slot: class colour", nil, G, "slot_color_class"),
    })

    W.Card(p, "Hover and press", { icon = ICON .. "Spell_Holy_SearingLight", tip = "Hover: the mouse is over a button. Press: it is held down, by mouse or key." })
    Drop(p, "Hover look", nil, List(AB.STYLES), G, "hover_style")
    Drop(p, "Press look", nil, List(AB.STYLES), G, "press_style")
    Sld(p, "Hover border", "Thickness for Border only.", 1, 6, 1, G, "hover_size", Px)
    Sld(p, "Press border", "Thickness for Border only.", 1, 6, 1, G, "press_size", Px)
    Grid(p, 4, {
      KeyColour("Hover colour", nil, G, "hover_color"),
      Tick("Hover: class colour", nil, G, "hover_color_class"),
      KeyColour("Press colour", nil, G, "press_color"),
      Tick("Press: class colour", nil, G, "press_color_class"),
    })
    Drop(p, "Press animation", "Plays over the icon as the action goes off.", DD("actionbuttonanimations"), G, "animation")
    Drop(p, "Animate on", nil, DD("animationmode"), G, "animmode")
    Grid(p, 4, {
      Tick("Animate hidden bars", "The press animation shows even on bars that are faded out.", G, "animalways"),
    })

    -- (31 Oct 2026, user: more countdown options and ready effects, and the page
    -- "overwhelming": one card per job - the swipe, the number, the ready moment)
    local function CD() return C.appearance.cd end
    local function Re() if pfUI.api.ResetTimeColors then pfUI.api.ResetTimeColors() end end
    local CDX = pfUI.cooldown or {}
    W.Card(p, "Cooldown swipe", { icon = ICON .. "INV_Misc_PocketWatch_02", tip = "The dark part over a button cooling down." })
    Drop(p, "Swipe", nil, List(AB.CDSTYLES), G, "cd_style")
    Sld(p, "Hide cooldowns shorter than", "No swipe or number on short ones, like the global cooldown.", 0, 10, .5, CD, "threshold", Sec, Re)
    Grid(p, 3, {
      KeyColour("Swipe colour", nil, G, "cd_color"),
      KeyColour("Edge colour", "The bright line where the swipe ends.", G, "cd_edgecolor"),
      Tick("Edge line", "A bright line where the swipe ends.", G, "cd_edge"),
      Tick("Swipe the other way", "The dark part grows as the cooldown runs out (with ClassicAPI).", G, "cooldown_reverse"),
      Tick("Edge: class colour", nil, G, "cd_edgecolor_class"),
    })

    W.Card(p, "Countdown number", { icon = ICON .. "Spell_Nature_TimeStop", tip = "The seconds counting down on every cooldown." })
    if CDX.FORMATS then Drop(p, "Format", "How the time left is written.", CDX.FORMATS, CD, "format", Re) end
    if CDX.POINTS then Drop(p, "Where on the button", "New cooldowns use it; ones running keep their spot.", CDX.POINTS, CD, "pos", Re) end
    Sld(p, "Number size", nil, 6, 30, 1, G, "cd_size", Px)
    Grid(p, 3, {
      KeyColour("Seconds", "Seconds left.", CD, "normalcolor", nil, Re),
      KeyColour("Last 5 seconds", "When it is nearly ready.", CD, "lowcolor", nil, Re),
      KeyColour("Minutes", nil, CD, "minutecolor", nil, Re),
      KeyColour("Hours", nil, CD, "hourcolor", nil, Re),
      Tick("Tenths at the end", "Shows 4.2 instead of 4 in the last 5 seconds.", CD, "milliseconds", Re),
      Tick("Grow at the end", "The number gets bigger in the last 5 seconds.", CD, "lowgrow", Re),
      Tick("Size from the button", "The number follows the button's size (never smaller than Number size).", CD, "dynamicsize", Re),
    })

    W.Card(p, "When it is ready", { icon = ICON .. "Spell_Holy_HolyNova", tip = "An effect on the button the moment its cooldown ends." })
    if CDX.EFFECTS then Drop(p, "Effect", nil, CDX.EFFECTS, CD, "finish", Re) end
    if CDX.SOUNDS then Drop(p, "Sound", nil, CDX.SOUNDS, CD, "finishsound", Re) end
    Sld(p, "Only after cooldowns of", "Shorter cooldowns end quietly.", 0, 60, 1, CD, "finishmin", Sec, Re)
    Grid(p, 3, {
      KeyColour("Effect colour", nil, CD, "finishcolor", nil, Re),
    })
    W.Buttons(p, { { "Try it on my bars", function()
      for i = 1, 12 do
        local b = _G["pfActionBarMainButton" .. i]
        if b and b:IsVisible() and CDX.Finish then CDX.Finish(b, (C.appearance.cd.finish ~= "none") and C.appearance.cd.finish or "all") end
      end
    end } })

    W.Card(p, "Proc glow", { icon = ICON .. "Spell_Holy_PowerInfusion", tip = "Lights a button when it is worth pressing now." })
    Drop(p, "Glow", nil, List(AB.GLOWS), G, "glow_style", function() AB.GlowRepaint() U() end)
    Sld(p, "Speed", nil, 1, 10, 1, G, "glow_speed")
    Sld(p, "Lines", "For Marching lines.", 2, 16, 1, G, "glow_lines")
    Sld(p, "Thickness", nil, 1, 6, 1, G, "glow_thick", Px, function() AB.GlowRepaint() U() end)
    Grid(p, 3, {
      Tick("Reactive abilities", "Overpower, Revenge, Execute, Riposte, Counterattack, Mongoose Bite and Hammer of Wrath while usable.", G, "glow_reactive"),
      Tick("Procs", "Shadow Bolt during Shadow Trance (Nightfall).", G, "glow_procs"),
      Tick("Burst as it starts", "A ring grows out of the button when the glow begins.", G, "glow_burst", function() AB.GlowRepaint() U() end),
      KeyColour("Glow colour", nil, G, "glow_color", nil, function() AB.GlowRepaint() U() end),
      Tick("Glow: class colour", nil, G, "glow_color_class", function() AB.GlowRepaint() U() end),
    })

    W.Card(p, "Highlights", { icon = ICON .. "Spell_Frost_Stun", tip = "The icon changes colour when the action cannot be used right now." })
    Grid(p, 3, {
      Tick("Out of range", nil, G, "glowrange"),
      Tick("Out of mana", nil, G, "showoom"),
      Tick("Not usable", nil, G, "showna"),
      KeyColour("Range colour", nil, G, "rangecolor"),
      KeyColour("Mana colour", nil, G, "oomcolor"),
      KeyColour("Not usable colour", nil, G, "nacolor"),
    })

    W.Card(p, "Letters", { tip = "The key, macro name and count on each button. The cooldown number is under Cooldowns." })
    local fonts = {}
    for _, f in ipairs(W.Fonts()) do table.insert(fonts, { key = f.key, label = f.label, font = f.key }) end
    Drop(p, "Font", nil, fonts, G, "font")
    Sld(p, "Text inset", "Moves the texts in from the button's edges.", -5, 10, 1, G, "font_offset", Px)
    Sld(p, "Key size", nil, 6, 20, 1, G, "bind_size", Px)
    Sld(p, "Macro size", nil, 6, 20, 1, G, "macro_size", Px)
    Sld(p, "Count size", nil, 6, 20, 1, G, "count_size", Px)
    Grid(p, 3, {
      KeyColour("Key colour", nil, G, "bind_color"),
      KeyColour("Macro colour", nil, G, "macro_color"),
      KeyColour("Count colour", nil, G, "count_color"),
    })

    W.Card(p, "Equipped items", { tip = "Items you wear, put on a bar (trinkets, weapons)." })
    Drop(p, "Mark", nil, List(AB.EQSTYLES), G, "eq_style")
    Sld(p, "Border", "In the item's quality colour.", 1, 4, 1, G, "eq_size", Px)
    Grid(p, 3, {
      Tick("Mark equipped items", nil, G, "showequipped"),
      KeyColour("Tint colour", nil, G, "eqcolor"),
    })
    AB.BFilter(p)
    table.insert(p.items, { Refresh = function() AB.BFilter(p) end })
  end

  -- ---------------------------------------------------------------- paging

  BUILD.abpaging = function(p)
    W.Heading(p, "Paging", { about = "Switch the main bar's page with a key held down, in druid stealth, or by range (hunters)." })
    W.Card(p, "Switch pages", { icon = ICON .. "Spell_Arcane_PortalIronForge" })
    Grid(p, 3, {
      Tick("While Alt is held", nil, G, "pagemasteralt"),
      Tick("While Shift is held", nil, G, "pagemastershift"),
      Tick("While Ctrl is held", nil, G, "pagemasterctrl"),
      Tick("In druid stealth", "Prowling gives its own page.", G, "druidstealth"),
      Tick("Hunters: by range", "Melee and ranged pages swap by distance.", G, "hunterbar"),
    })
    W.Card(p, "Bars that page", { tip = "These bars change with the main bar's page." })
    local list = {}
    for _, i in ipairs(AB.ORDER) do
      if i ~= 1 and i <= 10 then
        local id = i
        table.insert(list, Tick(AB.NAMES[id], nil, function() return C.bars["bar" .. id] end, "pageable"))
      end
    end
    Grid(p, 3, list)
  end

  -- ---------------------------------------------------------------- gryphons

  -- the end art: a sample bar with both ends drawn from the settings, and
  -- one click per picture (the one in use lit)
  -- (read when used: this module starts before gryphons.lua, so pfUI.gryphons
  -- is not there yet at load - the Art list only ever showed None, 25 Oct 2026)
  local function GR() return pfUI.gryphons end
  local function ArtList()
    local out = { { key = "None", label = "None" } }
    for _, a in ipairs(GR() and GR().art or {}) do table.insert(out, { key = a.key, label = a.label, texture = a.tex }) end
    return out
  end
  AB.ArtList = ArtList
  local function GryPreview(p)
    W.Pin(p, "Preview", "A bar with your end art, as it will look. Click a picture under it to use it; hold Shift and "
      .. "scroll the mouse wheel over the art for a bigger or smaller one. Click this bar to fold it away.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 130)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local bar = CreateFrame("Frame", nil, holder)
      bar:SetWidth(12 * 30 + 11 * 2)
      bar:SetHeight(30)
      bar:SetPoint("BOTTOM", box, "BOTTOM", 0, 14)
      for i = 1, 12 do
        local b = bar:CreateTexture(nil, "ARTWORK")
        b:SetTexture("Interface\\Buttons\\WHITE8X8")
        b:SetVertexColor(.12, .12, .14, 1)
        b:SetWidth(30)
        b:SetHeight(30)
        b:SetPoint("LEFT", bar, "LEFT", (i - 1) * 32, 0)
      end
      local ends = {}
      for _, side in ipairs({ "left", "right" }) do
        local e = CreateFrame("Button", nil, holder)
        e:SetFrameLevel(bar:GetFrameLevel() + 4)
        e.tex = e:CreateTexture(nil, "OVERLAY")
        e.tex:SetAllPoints(e)
        e.side = side
        e:EnableMouseWheel(true)
        e:SetScript("OnMouseWheel", function()
          if IsShiftKeyDown() then
            GRY().size = tostring(math.max(16, math.min(160, (tonumber(GRY().size) or 64) + 4 * (arg1 or 0))))
            UG()
            O:Refresh()
          elseif pfUI.plates and pfUI.plates.PassWheel then
            pfUI.plates.PassWheel(this)
          end
        end)
        e:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:AddLine("End art")
          GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller", 1, 1, 1)
          GameTooltip:Show()
        end)
        e:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ends[side] = e
      end
      AB.gryEnds = ends
      -- the same drawing as gryphons.lua, scaled to the box
      local function Paint()
        local set = GRY()
        local art = GR() and GR().Art(set.texture)
        local c = art and art.coords or { 0, 1, 0, 1 }
        local size = math.min(100, tonumber(set.size) or 64)
        local aspect = math.max(.2, (c[2] - c[1]) / math.max(.01, c[4] - c[3]))
        local r, g, b, a = GetStringColor(set.color or "1,1,1,1")
        for side, e in pairs(ends) do
          local show = art and (set.sides == nil or set.sides == "both" or set.sides == side)
          e:SetWidth(size * aspect)
          e:SetHeight(size)
          e:ClearAllPoints()
          e:SetPoint(side == "left" and "BOTTOMRIGHT" or "BOTTOMLEFT", bar, side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT",
            side == "left" and 14 or -14, -6)
          e.tex:SetTexture(art and art.tex or nil)
          e.tex:SetVertexColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1)
          local mirror = side == "right"
          if set.mirror == "1" then mirror = not mirror end
          if mirror then e.tex:SetTexCoord(c[2], c[1], c[3], c[4]) else e.tex:SetTexCoord(c[1], c[2], c[3], c[4]) end
          if show then e:Show() else e:Hide() end
        end
      end
      AB.PaintGry = Paint
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end
      -- one click per picture
      local list = ArtList()
      local rows = { {}, {} }
      for i, e in ipairs(list) do
        local key = e.key
        table.insert(rows[i <= 4 and 1 or 2], { e.label, function()
          GRY().texture = key
          UG()
          Paint()
          O:Refresh()
        end, nil, e.label, on = function() return GRY().texture == key end })
      end
      W.Buttons(pp, rows[1])
      W.Buttons(pp, rows[2])
    end)
  end

  BUILD.abgryphons = function(p)
    W.Heading(p, "Gryphons", { on = O.ModuleSwitch("gryphons", "Gryphons"), about = "The art at the ends of the main bar: the game's gryphon, lion and dragons." })
    GryPreview(p)
    local function UGP() UG() if AB.PaintGry then AB.PaintGry() end end
    W.Card(p, "Gryphons")
    Drop(p, "Art", "Each choice shows its picture.", ArtList(), GRY, "texture", UGP)
    Drop(p, "Ends", nil, { { key = "both", label = "Both ends" }, { key = "left", label = "Left end only" },
      { key = "right", label = "Right end only" } }, GRY, "sides", UGP)
    Chk(p, "Mirror", "Turn the art round: it faces away from the bar.", GRY, "mirror", UGP)
    Color(p, "Colour", nil, GRY, "color", UGP)
    Sld(p, "Size", "Or Shift + wheel over the art in the preview.", 16, 160, 1, GRY, "size", Px, UGP)
    Drop(p, "Left end at", nil, DD("xpanchors"), GRY, "anchor_left", UGP)
    Drop(p, "Right end at", nil, DD("xpanchors"), GRY, "anchor_right", UGP)
    Sld(p, "Left / right", nil, -200, 200, 1, GRY, "offset_h", Px, UGP)
    Sld(p, "Up / down", nil, -100, 100, 1, GRY, "offset_v", Px, UGP)
  end

  O.replaced[T["Actionbar"]] = true
  O:AddPage("Action Bars", "abgeneral", "General", BUILD.abgeneral)
  O:AddPage("Action Bars", "abbars", "Bars", BUILD.abbars)
  O:AddPage("Action Bars", "abbuttons", "Buttons", BUILD.abbuttons)
  O:AddPage("Action Bars", "abpaging", "Paging", BUILD.abpaging)
  O:AddPage("Action Bars", "abgryphons", "Gryphons", BUILD.abgryphons)
  AB.TAB = TAB
  -- O:Open("abbars", n) opens the Bars page on bar n's tab (layout mode's right-click on a bar)
  O.tabs = O.tabs or {}
  O.tabs.abbars = function(i) if tonumber(i) and C.bars["bar" .. tonumber(i)] then TAB.cur = tonumber(i) end end
end)
