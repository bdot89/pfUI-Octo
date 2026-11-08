pfUI:RegisterModule("castbar-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Castbar page (user, 22 Oct 2026: "give this a preview
  -- window also with a animated cast bar"). Under Unit Frames, in place of
  -- pfUI's Castbar page (hidden). Tabs Player / Target / Focus; a pinned
  -- preview with a sample cast bar drawn as pfUI draws one, that casts
  -- (casting colour, filling) and then channels (channel colour, emptying)
  -- on a loop, with spell name, rank, timer, lag and icon as the settings
  -- say. Every part can be clicked for its card; Shift + wheel over the bar
  -- changes its height. Changes reach the real cast bars at once where pfUI
  -- allows; the rest (fonts, turning bars on or off) after a reload.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local PfChk, PfSld = O.PfChk, O.PfSld

  local CB = { cur = "player" }
  pfUI.castbarOcto = CB
  CB.UNITS = { { "player", "Player" }, { "target", "Target" }, { "focus", "Focus" } }

  local function S() return C.castbar[CB.cur] end
  local function A() return C.appearance.castbar end
  local function Px(v) return v .. " px" end
  local function Reload() if pfUI.gui then pfUI.gui.settingChanged = true end end

  local function Font()
    if C.castbar.use_unitfonts == "1" then return pfUI.font_unit, tonumber(C.global.font_unit_size) or 12 end
    return pfUI.font_default, tonumber(C.global.font_size) or 12
  end

  -- the width and height a cast bar gets (-1 = as wide as its unit frame)
  function CB.Size(unit)
    local s = C.castbar[unit]
    local _, fsize = Font()
    local w = tonumber(s.width) or -1
    if w <= 0 then
      local uf = pfUI.uf and pfUI.uf[unit]
      w = (uf and uf.GetWidth and uf:GetWidth()) or tonumber(C.unitframes[unit] and C.unitframes[unit].width) or 200
      if not w or w <= 0 then w = 200 end
    end
    local h = tonumber(s.height) or -1
    if h <= 0 then h = fsize * 1.5 end
    return w, h
  end

  -- what can change on pfUI's real cast bars without a reload
  function CB.Apply(unit)
    unit = unit or CB.cur
    local cb = pfUI.castbar and pfUI.castbar[unit]
    if cb then
      local s = C.castbar[unit]
      cb.showicon = s.showicon == "1" and true or nil
      cb.showname = s.showname == "1" and true or nil
      cb.showtimer = s.showtimer == "1" and true or nil
      cb.showlag = s.showlag == "1" and true or nil
      cb.showpush = s.showpush ~= "0" and true or nil
      cb.showrank = s.showrank == "1" and true or nil
      local w, h = CB.Size(unit)
      cb:SetWidth(w)
      if tonumber(s.height) and tonumber(s.height) > 0 then cb:SetHeight(h) end
      if cb.bar then
        cb.bar:SetStatusBarTexture(pfUI.media[A().texture])
        cb.bar.left:ClearAllPoints()
        cb.bar.left:SetPoint("TOPLEFT", cb.bar, "TOPLEFT", 3 + s.txtleftoffx, s.txtleftoffy)
        cb.bar.left:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT", -3 + s.txtleftoffx, s.txtleftoffy)
        cb.bar.right:ClearAllPoints()
        cb.bar.right:SetPoint("TOPLEFT", cb.bar, "TOPLEFT", 3 + s.txtrightoffx, s.txtrightoffy)
        cb.bar.right:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT", -3 + s.txtrightoffx, s.txtrightoffy)
        if not cb.showtimer then cb.bar.right:SetText("") end
      end
      -- (a new cast picks up the rest)
      cb.endTime = nil
    end
    if CB.mini then CB.mini.Refresh() end
  end
  local function Up() CB.Apply() end
  local function UpAll() for _, u in ipairs(CB.UNITS) do CB.Apply(u[1]) end end

  local function Chk(p, label, desc, group, key, after) return PfChk(p, label, desc, group, key, after or Up) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt, after) return PfSld(p, label, desc, min, max, step, group, key, after or Up, fmt) end
  local function Color(p, label, desc, group, key, after)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      ;(after or UpAll)()
    end)
  end
  local function Textures()
    local out = {}
    local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns.uf_bartexture
    if type(list) == "function" then list = list() end
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l, texture = k }) end
    end
    return out
  end

  -- ---------------------------------------------------------------- preview

  CB.GO = { bar = "Bar", name = "Text", timer = "Text", icon = "Icon and lag", lag = "Icon and lag", fill = "All cast bars" }
  CB.DRAG = { name = { "txtleftoffx", "txtleftoffy" }, timer = { "txtrightoffx", "txtrightoffy" } }
  CB.HOTLABEL = { bar = "The bar: size", name = "Spell name and rank", timer = "Timer", icon = "Spell icon", lag = "Lag",
    fill = "The fill: casting / channeling colour and texture" }

  function CB.Open(what)
    local title = CB.GO[what] or "Bar"
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("ufcastbar", title) else O:Open("ufcastbar") end
  end

  -- the spells the sample casts, then channels
  CB.SAMPLES = {
    { "Frostbolt", "Rank 9", "Interface\\Icons\\Spell_Frost_FrostBolt02", 2.5 },
    { "Arcane Missiles", "Rank 7", "Interface\\Icons\\Spell_Nature_StarFall", 3, true },
    { "Greater Heal", "Rank 4", "Interface\\Icons\\Spell_Holy_GreaterHeal", 2.5 },
    { "Drain Life", "Rank 6", "Interface\\Icons\\Spell_Shadow_LifeDrain02", 3, true },
  }

  function CB.Mini(box)
    local M = {}
    CB.mini = M
    -- in a layer of its own above the window (as the other previews)
    local holder = CreateFrame("Frame", nil, box)
    holder:SetAllPoints(box)
    -- (on the box's own level + 1, as the swing preview: on level 1 it lay
    -- under the zoom box's frames and came out dark - user, 8 Nov 2026)
    holder:SetFrameStrata("FULLSCREEN")
    local cap = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cap:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
    cap:SetTextColor(.6, .6, .6)
    local off = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    off:SetPoint("BOTTOM", box, "BOTTOM", 0, 6)

    -- the sample, built like pfUI's CreateCastbar
    local _, border = GetBorderSize("unitframes")
    local cb = CreateFrame("Frame", nil, holder)
    cb.icon = CreateFrame("Frame", nil, cb)
    cb.icon:SetPoint("TOPLEFT", cb, "TOPLEFT", 0, 0)
    cb.icon.texture = cb.icon:CreateTexture(nil, "OVERLAY")
    cb.icon.texture:SetAllPoints(cb.icon)
    cb.icon.texture:SetTexCoord(.08, .92, .08, .92)
    CreateBackdrop(cb.icon, border)
    cb.bar = CreateFrame("StatusBar", nil, cb)
    cb.bar:SetMinMaxValues(0, 100)
    CreateBackdrop(cb.bar, border)
    cb.bar.left = cb.bar:CreateFontString(nil, "OVERLAY")
    cb.bar.left:SetJustifyH("LEFT")
    cb.bar.right = cb.bar:CreateFontString(nil, "OVERLAY")
    cb.bar.right:SetJustifyH("RIGHT")
    cb.bar.lag = cb.bar:CreateTexture(nil, "OVERLAY")
    cb.bar.lag:SetPoint("TOPRIGHT", cb.bar, "TOPRIGHT", 0, 0)
    cb.bar.lag:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT", 0, 0)
    cb.bar.lag:SetTexture(1, .2, .2, .35)
    M.cb = cb

    -- clickable spots
    M.hots = {}
    local function Hot(what, level)
      local h = CreateFrame("Button", nil, holder)
      h:SetFrameLevel(holder:GetFrameLevel() + 20 + (level or 0))
      h.what = what
      h.hl = h:CreateTexture(nil, "OVERLAY")
      h.hl:SetAllPoints(h)
      h.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      h.hl:SetVertexColor(ar, ag, ab, .3)
      h.hl:Hide()
      h:SetScript("OnEnter", function()
        this.hl:Show()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine(CB.HOTLABEL[this.what] or this.what)
        GameTooltip:AddLine("Click: its settings", 1, 1, 1)
        if this.what == "bar" then GameTooltip:AddLine("Shift + mouse wheel: taller / shorter", 1, 1, 1) end
        if CB.DRAG[this.what] then
          GameTooltip:AddLine("Drag: move it", 1, 1, 1)
          GameTooltip:AddLine("Right-click: put it back", 1, 1, 1)
        end
        GameTooltip:Show()
      end)
      h:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
      -- the name and timer can be dragged (their offsets); right-click puts them back
      local drag = CB.DRAG[what]
      h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      if drag then
        h:SetScript("OnMouseDown", function()
          if arg1 == "RightButton" then return end
          local s = S()
          local cx, cy = GetCursorPosition()
          this.down = { cx, cy, tonumber(s[drag[1]]) or 0, tonumber(s[drag[2]]) or 0 }
          this.moved = nil
          this:SetScript("OnUpdate", function()
            local d = this.down
            if not d then return end
            local x, y = GetCursorPosition()
            local k = cb:GetEffectiveScale() or 1
            local dx, dy = (x - d[1]) / k, (y - d[2]) / k
            if not this.moved and math.abs(dx) + math.abs(dy) < 3 then return end
            this.moved = true
            local st = S()
            st[drag[1]] = tostring(math.floor(d[3] + dx + .5))
            st[drag[2]] = tostring(math.floor(d[4] + dy + .5))
            M.Refresh()
          end)
        end)
        h:SetScript("OnMouseUp", function()
          this.down = nil
          this:SetScript("OnUpdate", nil)
          if this.moved then Up() end
        end)
      end
      h:SetScript("OnClick", function()
        if arg1 == "RightButton" then
          local d = CB.DRAG[this.what]
          if d then
            S()[d[1]], S()[d[2]] = "0", "0"
            Up()
          end
          return
        end
        if this.moved then this.moved = nil return end
        CB.Open(this.what)
      end)
      h:EnableMouseWheel(true)
      h:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() and this.what == "bar" then
          local s = S()
          local _, cur = CB.Size(CB.cur)
          s.height = tostring(math.max(6, math.min(60, math.floor(cur + .5) + (arg1 or 0))))
          Up()
        elseif pfUI.plates and pfUI.plates.PassWheel then
          pfUI.plates.PassWheel(this)
        end
      end)
      M.hots[what] = h
      return h
    end
    Hot("bar", 0):SetAllPoints(cb.bar)
    -- the filled part follows the cast
    local fill = Hot("fill", 1)
    fill:SetPoint("TOPLEFT", cb.bar, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", cb.bar, "BOTTOMLEFT", 0, 0)
    Hot("icon", 1):SetAllPoints(cb.icon)
    Hot("lag", 2):SetAllPoints(cb.bar.lag)
    Hot("name", 3)
    Hot("timer", 3)

    -- a text's spot is as wide as its words
    local function Spot(h, fs, left)
      local w = fs:GetStringWidth() or 0
      if not fs:IsVisible() or (fs:GetText() or "") == "" or w <= 0 then h:Hide() return end
      local _, size = fs:GetFont()
      h:ClearAllPoints()
      h:SetWidth(w + 4)
      h:SetHeight((tonumber(size) or 10) + 4)
      if left then h:SetPoint("LEFT", fs, "LEFT", -2, 0) else h:SetPoint("RIGHT", fs, "RIGHT", 2, 0) end
      h:Show()
    end

    -- the look, from the settings of the chosen tab
    function M.Refresh()
      local unit = CB.cur
      local s = C.castbar[unit]
      local w, h = CB.Size(unit)
      -- bigger in the preview, to fit the box
      local bw = (box:GetWidth() or 600) - 60
      local k = math.max(.6, math.min(2, bw / (w + h), 60 / h))
      cb:SetScale(k)
      cb:SetWidth(w)
      cb:SetHeight(h)
      cb:ClearAllPoints()
      cb:SetPoint("CENTER", box, "CENTER", 0, -4)
      cb.bar:SetStatusBarTexture(pfUI.media[A().texture])
      local font, size = Font()
      for _, fs in ipairs({ cb.bar.left, cb.bar.right }) do fs:SetFont(font, size, "OUTLINE") fs:SetTextColor(1, 1, 1, 1) end
      cb.bar.left:ClearAllPoints()
      cb.bar.left:SetPoint("TOPLEFT", cb.bar, "TOPLEFT", 3 + (tonumber(s.txtleftoffx) or 0), tonumber(s.txtleftoffy) or 0)
      cb.bar.left:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT", -3 + (tonumber(s.txtleftoffx) or 0), tonumber(s.txtleftoffy) or 0)
      cb.bar.right:ClearAllPoints()
      cb.bar.right:SetPoint("TOPLEFT", cb.bar, "TOPLEFT", 3 + (tonumber(s.txtrightoffx) or 0), tonumber(s.txtrightoffy) or 0)
      cb.bar.right:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT", -3 + (tonumber(s.txtrightoffx) or 0), tonumber(s.txtrightoffy) or 0)
      -- the icon at the left, as tall as the bar
      local spacing = border * 2 + (tonumber(C.unitframes[unit] and C.unitframes[unit].pspace) or 0) * GetPerfectPixel()
      cb.bar:ClearAllPoints()
      if s.showicon == "1" then
        cb.icon:SetWidth(h)
        cb.icon:SetHeight(h)
        cb.icon:Show()
        cb.bar:SetPoint("TOPLEFT", cb.icon, "TOPRIGHT", spacing, 0)
      else
        cb.icon:Hide()
        cb.bar:SetPoint("TOPLEFT", cb, "TOPLEFT", 0, 0)
      end
      cb.bar:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", 0, 0)
      local name
      for _, u in ipairs(CB.UNITS) do if u[1] == unit then name = u[2] end end
      cap:SetText((name or unit) .. " cast bar: casting, then channeling")
      if s.hide_pfui == "1" then
        off:SetText("|cffff8080This cast bar is off: Bar card (after a reload)|r")
      else
        off:SetText("")
      end
    end

    -- the loop: each sample spell in turn, then a short pause
    function M.Animate(now)
      local s = C.castbar[CB.cur]
      local n = table.getn(CB.SAMPLES)
      local slot = 4
      local i = math.mod(math.floor(now / slot), n) + 1
      local sp = CB.SAMPLES[i]
      local t = math.mod(now, slot)
      local dur = sp[4]
      local channel = sp[5]
      local colour = A()[channel and "channelcolor" or "castbarcolor"]
      local r, g, b, a = GetStringColor(colour or "1,1,1,1")
      cb.bar:SetStatusBarColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1)
      cb.bar:SetMinMaxValues(0, dur)
      if t < dur then
        local cur = channel and (dur - t) or t
        cb.bar:SetValue(cur)
        cb:SetAlpha(1)
        local left = (s.showname == "1" and sp[1] .. " " or "")
        if s.showrank == "1" then left = left .. "|cffaaffcc[" .. sp[2] .. "]|r" end
        cb.bar.left:SetText(left)
        cb.bar.right:SetText(s.showtimer == "1" and (string.format("%.1f", cur) .. " / " .. dur) or "")
      else
        -- done: it fades out as pfUI's does
        cb.bar:SetValue(dur)
        cb:SetAlpha(math.max(0, 1 - (t - dur) / .8))
      end
      cb.icon.texture:SetTexture(sp[3])
      if s.showlag == "1" then
        -- a sample 150 ms of lag at the end of the bar
        cb.bar.lag:SetWidth(math.max(1, (cb.bar:GetWidth() or 100) * .15 / dur))
        cb.bar.lag:Show()
      else
        cb.bar.lag:Hide()
      end
      local _, mx = cb.bar:GetMinMaxValues()
      local part = (mx and mx > 0) and (cb.bar:GetValue() or 0) / mx or 0
      M.hots.fill:SetWidth(math.max(1, (cb.bar:GetWidth() or 100) * part))
      if part > .02 and cb:GetAlpha() > .3 then M.hots.fill:Show() else M.hots.fill:Hide() end
      Spot(M.hots.name, cb.bar.left, true)
      Spot(M.hots.timer, cb.bar.right, false)
      if cb.icon:IsShown() then M.hots.icon:Show() else M.hots.icon:Hide() end
      if cb.bar.lag:IsShown() then M.hots.lag:Show() else M.hots.lag:Hide() end
    end

    holder:SetScript("OnUpdate", function()
      local now = GetTime()
      M.Animate(now)
      if (this.tick or 0) < now then
        this.tick = now + .5
        M.Refresh()
      end
    end)
    M.Refresh()
    M.Animate(GetTime())
    return M
  end

  -- one cast bar's settings onto another (not whether it is on), undoable
  function CB.Copy(from, to)
    local src, dst = C.castbar[from], C.castbar[to]
    if not src or not dst or from == to then return 0 end
    local was, n = {}, 0
    for k, v in pairs(src) do
      if not string.find(k, "^hide_") and type(v) ~= "table" and dst[k] ~= v then
        was[k] = dst[k] == nil and false or dst[k]
        dst[k] = v
        n = n + 1
      end
    end
    CB.lastCopy = { to = to, was = was }
    CB.Apply(to)
    return n
  end
  function CB.Undo()
    local lc = CB.lastCopy
    if not lc then return end
    for k, v in pairs(lc.was) do
      if v == false then C.castbar[lc.to][k] = nil else C.castbar[lc.to][k] = v end
    end
    CB.lastCopy = nil
    CB.Apply(lc.to)
  end
  function CB.CopyMenu(anchor)
    W.CloseMenus()
    local function Label(key) for _, u in ipairs(CB.UNITS) do if u[1] == key then return u[2] end end return key end
    local opts = {}
    if CB.lastCopy then table.insert(opts, { key = "!undo", label = "Undo: " .. Label(CB.lastCopy.to) .. " as before" }) end
    table.insert(opts, { label = "Copy into " .. Label(CB.cur) .. " from:", group = true })
    for _, u in ipairs(CB.UNITS) do
      if u[1] ~= CB.cur then table.insert(opts, { key = u[1], label = u[2] }) end
    end
    local m = W.Menu(anchor, opts, 200, function(from)
      if from == "!undo" then
        CB.Undo()
      else
        local n = CB.Copy(from, CB.cur)
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. Label(CB.cur) .. " cast bar now has " .. Label(from)
          .. "'s settings (" .. n .. " changed). Copy from... > Undo puts it back.")
      end
      if CB.mini then CB.mini.Refresh() end
      if O.Refresh then O:Refresh() end
    end)
    m:Show()
    CB.copyMenu = m
    return m
  end

  local function Preview(p)
    W.Pin(p, "Preview", "A sample cast bar with your settings, casting and channeling on a loop. Pick a cast bar with the "
      .. "tabs. Click a part for its settings; hold Shift and scroll the mouse wheel over the bar to make it taller "
      .. "or shorter. Click this bar to fold it away.", function(p)
      local row = W.Row(p, 24, 0, 4)
      local tabs = {}
      for n, u in ipairs(CB.UNITS) do
        local b = W.Button(row, u[2], 124, 22)
        b:SetPoint("LEFT", row, "LEFT", (n - 1) * 128, 0)
        b.key = u[1]
        b:SetScript("OnClick", function()
          CB.cur = this.key
          if CB.mini then CB.mini.Refresh() end
          O:Refresh()
        end)
        tabs[n] = b
      end
      -- (25 Oct 2026, user: copy ALL the settings of one frame to another)
      local copy = W.Button(row, "Copy from...", 114, 22)
      copy:SetPoint("RIGHT", row, "RIGHT", 0, 0)
      if W.Tint then W.Tint(copy, "save") end
      W.Tip(copy, "Copy from another cast bar", "This cast bar gets the size, texts, icon and offsets of another one. "
        .. "Whether it is on stays its own. The last copy can be undone here.")
      copy:SetScript("OnClick", function() CB.CopyMenu(this) end)
      local mini = CB.Mini((W.ZoomBox or W.Box)(p, 110))
      table.insert(p.items, { Refresh = function()
        for _, b in ipairs(tabs) do W.Pick(b, b.key == CB.cur) end
        mini.Refresh()
      end })
      local band = W.Row(p, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r a part  its settings     " .. k .. "Drag|r the name or timer  move it     " .. k .. "Right-click|r  put back     "
        .. k .. "Shift + wheel|r  height     " .. k .. "Move frames|r  move it")
      W.HowTo(p, band, how:GetText(), nil, 0)
    end)
  end

  -- ---------------------------------------------------------------- page

  local function Build(p)
    W.Heading(p, "Cast bars", { on = O.ModuleSwitch("castbar", "Cast bars"), about = "The cast bars under the player, target and focus frames. Pick one with the tabs; "
      .. "the colours and texture at the bottom are for all of them." })
    Preview(p)
    W.Card(p, "Bar", { tip = "Whether this cast bar shows, and its size." })
    W.Check(p, "Show this cast bar", "After a reload.", function() return S().hide_pfui ~= "1" end, function(v)
      S().hide_pfui = v and "0" or "1"
      Reload()
      if CB.mini then CB.mini.Refresh() end
    end)
    Sld(p, "Width", "-1 = as wide as its unit frame.", -1, 500, 1, S, "width", Px)
    Sld(p, "Height", "-1 = from the font size.", -1, 60, 1, S, "height", Px)
    W.Card(p, "Text", { tip = "The spell's name (and rank) on the left, the timer on the right." })
    Chk(p, "Spell name", nil, S, "showname")
    Chk(p, "Spell rank", nil, S, "showrank")
    Chk(p, "Timer", nil, S, "showtimer")
    Sld(p, "Name: across", nil, -50, 50, 1, S, "txtleftoffx", Px)
    Sld(p, "Name: up / down", nil, -30, 30, 1, S, "txtleftoffy", Px)
    Sld(p, "Timer: across", nil, -50, 50, 1, S, "txtrightoffx", Px)
    Sld(p, "Timer: up / down", nil, -30, 30, 1, S, "txtrightoffy", Px)
    W.Card(p, "Icon and lag")
    Chk(p, "Spell icon", "At the left of the bar, as tall as it.", S, "showicon")
    Chk(p, "Lag", "Your latency in red at the end of the bar: you can start the next spell there.", S, "showlag")
    Chk(p, "Pushback", "Time a cast lost to hits: \"+0.5\" in the timer and a red stretch at the end of the bar. Your own casts, and with ClassicAPI anyone's (your target's too).", S, "showpush")
    PfChk(p, "Queued spell", "Your cast bar: the spell you queued shows at its right end until it goes off (needs nampower; after a reload).",
      function() return C.castbar.player end, "spellqueue", Reload)
    W.Card(p, "All cast bars", { tip = "For the player, target and focus cast bars." })
    Color(p, "Casting", nil, A, "castbarcolor")
    Color(p, "Channeling", nil, A, "channelcolor")
    Color(p, "Can't be interrupted", "Casts none of your kicks or silences can stop (ClassicAPI tells; without it bars keep the colours above).", A, "nointcolor")
    W.Dropdown(p, "Texture", nil, Textures(), function() return A().texture end, function(v)
      A().texture = v
      UpAll()
    end)
    PfChk(p, "Unit frame font", "The cast bars use the unit frames' font (after a reload).", function() return C.castbar end, "use_unitfonts", function()
      Reload()
      if CB.mini then CB.mini.Refresh() end
    end)
    PfChk(p, "Hide the game's cast bar", "After a reload.", function() return C.castbar.player end, "hide_blizz", Reload)
  end

  -- layout mode's right-click on a cast bar opens its tab
  O.tabs = O.tabs or {}
  O.tabs.ufcastbar = function(key)
    for _, u in ipairs(CB.UNITS) do
      if u[1] == key then
        CB.cur = key
        if CB.mini then CB.mini.Refresh() end
      end
    end
  end

  O.replaced[T["Castbar"]] = true
  O:AddPage("Unit Frames", "ufcastbar", "Cast bars", Build)
end)
