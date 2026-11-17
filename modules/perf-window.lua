pfUI:RegisterModule("perf-window", "vanilla", function ()
  -- pfUI Octo :: live performance window (17 Nov 2026; Geekoi on Discord: "make view of pfperf same as in pfDebug?
  -- A separate window where I can monitor in realtime. Since last updates when I use pfui and try start Scan of
  -- pfDebug my game crashes").
  -- pfDebug's Scan follows every table reachable from _G and calls GetChildren on each: with pfQuest's database and
  -- the auction history inside pfUI that runs the client out of stack (#132 in the Lua core). This window finds
  -- frames through the game's own list (EnumerateFrames) and never walks tables.
  --   Scripts  (any client) every frame's OnUpdate / OnEvent wrapped like pfDebug does: calls, time (debugprofilestop,
  --            the client's ms clock), memory made; "now" = the last second. Stop puts every script back.
  --   Add-ons  (ClassicAPI) CPU per add-on (needs the profiler, /pfperf on) and memory per add-on.
  local PF = pfUI.perf
  if not PF then return end
  local PW = {}
  PF.win = PW
  PW.data = {}     -- label -> { calls, ms, kb, lc, lm }  (lc / lm = totals at the last refresh)
  PW.hooks = {}    -- frame -> { OnUpdate = { orig, wrapper }, OnEvent = ... }
  PW.on = true
  PW.mode = "scripts"
  PW.sort = "now"
  PW.SCRIPTS = { "OnUpdate", "OnEvent" }

  local function GT() return GetTime and GetTime() or 0 end
  function PW.Clock()
    local dps = rawget(_G, "debugprofilestop")
    if type(dps) == "function" then
      local ok, v = pcall(dps)
      if ok and tonumber(v) then return v end
    end
    return GT() * 1000
  end
  local function Mem() return type(gcinfo) == "function" and gcinfo() or 0 end

  function PW.Rec(label)
    local r = PW.data[label]
    if not r then
      r = { calls = 0, ms = 0, kb = 0, lc = 0, lm = 0, nc = 0, nm = 0 }
      PW.data[label] = r
    end
    return r
  end

  function PW.Wrap(orig, rec)
    return function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
      if not PW.on then return orig(a1, a2, a3, a4, a5, a6, a7, a8, a9) end
      local m0, t0 = Mem(), PW.Clock()
      orig(a1, a2, a3, a4, a5, a6, a7, a8, a9)
      local dt, dm = PW.Clock() - t0, Mem() - m0
      rec.calls = rec.calls + 1
      if dt > 0 then rec.ms = rec.ms + dt end
      if dm > 0 then rec.kb = rec.kb + dm end
    end
  end

  local function Label(f)
    if PF.Label then return PF.Label(f) end
    return (f.GetName and f:GetName()) or "<unnamed>"
  end
  local function Mine(f)
    local p = f
    for _ = 1, 4 do
      if not p then return false end
      if p == PW.frame then return true end
      p = p.GetParent and p:GetParent()
    end
    return false
  end

  -- wraps every frame script not wrapped yet (a script swapped since the last scan is wrapped again);
  -- returns frames seen, scripts newly wrapped
  function PW.Scan()
    local ef = rawget(_G, "EnumerateFrames")
    if type(ef) ~= "function" then return 0, 0 end
    local seen, added = 0, 0
    local f = ef()
    while f and seen < 20000 do
      seen = seen + 1
      if not Mine(f) and f.GetScript and f.SetScript then
        local h = PW.hooks[f]
        for _, s in ipairs(PW.SCRIPTS) do
          local ok, fn = pcall(f.GetScript, f, s)
          if ok and type(fn) == "function" and not (h and h[s] and h[s][2] == fn) then
            local w = PW.Wrap(fn, PW.Rec(Label(f) .. ":" .. s .. "()"))
            if pcall(f.SetScript, f, s, w) then
              h = h or {}
              PW.hooks[f] = h
              h[s] = { fn, w }
              added = added + 1
            end
          end
        end
      end
      f = ef(f)
    end
    PW.scanned = true
    return seen, added
  end

  -- puts back every script still ours; returns how many
  function PW.Unhook()
    local n = 0
    for f, h in pairs(PW.hooks) do
      for s, pair in pairs(h) do
        local ok, cur = pcall(f.GetScript, f, s)
        if ok and cur == pair[2] then
          pcall(f.SetScript, f, s, pair[1])
          n = n + 1
        end
      end
    end
    PW.hooks = {}
    PW.scanned = false
    return n
  end
  function PW.Hooked()
    local n = 0
    for _, h in pairs(PW.hooks) do for _ in pairs(h) do n = n + 1 end end
    return n
  end

  function PW.Reset()
    PW.data = {}
    -- the wrappers hold their record: give them fresh ones by wrapping again
    if PW.scanned then
      local hooks = PW.hooks
      for f, h in pairs(hooks) do
        for s, pair in pairs(h) do
          local ok, cur = pcall(f.GetScript, f, s)
          if ok and cur == pair[2] then
            local w = PW.Wrap(pair[1], PW.Rec(Label(f) .. ":" .. s .. "()"))
            pcall(f.SetScript, f, s, w)
            pair[2] = w
          end
        end
      end
    end
    PW.addons = {}
    PF.Reset()
  end

  -- "now" numbers = what changed since the last refresh, per second
  function PW.Step(secs)
    secs = (secs and secs > 0) and secs or 1
    for _, r in pairs(PW.data) do
      r.nc = (r.calls - r.lc) / secs
      r.nm = (r.ms - r.lm) / secs
      r.lc, r.lm = r.calls, r.ms
    end
  end

  -- add-ons (ClassicAPI): name -> { cpu, mem, lcpu, lmem, ncpu, nmem }
  PW.addons = {}
  function PW.CanAddons() return type(_G.GetAddOnMemoryUsage) == "function" or PF.CanMeasure() end
  function PW.StepAddons(secs)
    secs = (secs and secs > 0) and secs or 1
    if _G.UpdateAddOnMemoryUsage then pcall(_G.UpdateAddOnMemoryUsage) end
    if PF.profiling and _G.UpdateAddOnCPUUsage then pcall(_G.UpdateAddOnCPUUsage) end
    for i = 1, (GetNumAddOns and GetNumAddOns() or 0) do
      local name = GetAddOnInfo(i)
      local loaded = IsAddOnLoaded and IsAddOnLoaded(i)
      if name and loaded then
        local a = PW.addons[name] or { cpu = 0, mem = 0 }
        PW.addons[name] = a
        if PF.profiling and _G.GetAddOnCPUUsage then
          local ok, v = pcall(_G.GetAddOnCPUUsage, i)
          if ok and tonumber(v) then
            a.ncpu = a.lcpu and math.max(0, (v - a.lcpu) / secs) or 0
            a.cpu, a.lcpu = v, v
          end
        end
        if _G.GetAddOnMemoryUsage then
          local ok, v = pcall(_G.GetAddOnMemoryUsage, i)
          if ok and tonumber(v) then
            a.nmem = a.lmem and (v - a.lmem) / secs or 0
            a.mem, a.lmem = v, v
          end
        end
      end
    end
  end

  -- the list: { name, cols = { text... }, key = sort value }
  PW.COLS = {
    scripts = { { "name", "Script", 300 }, { "calls", "Calls", 60 }, { "now", "Now ms/s", 80 }, { "ms", "Total ms", 80 },
      { "avg", "Avg ms", 60 }, { "kb", "KB made", 70 } },
    addons = { { "name", "Add-on", 300 }, { "now", "CPU ms/s", 80 }, { "ms", "CPU total", 80 }, { "mem", "Memory", 80 },
      { "grow", "KB/s", 70 } },
  }
  local function F(v, d) return string.format("%." .. (d or 1) .. "f", v or 0) end
  function PW.Rows()
    local out = {}
    if PW.mode == "addons" then
      for name, a in pairs(PW.addons) do
        local v = { name = string.lower(name), now = a.ncpu or 0, ms = a.cpu or 0, mem = a.mem or 0, grow = a.nmem or 0 }
        local memtxt = (a.mem or 0) >= 1024 and (F(a.mem / 1024, 1) .. " MB") or (F(a.mem, 0) .. " KB")
        table.insert(out, { label = name, v = v, cols = { name, F(v.now, 2), F(v.ms, 0), memtxt, F(v.grow, 1) } })
      end
    else
      for label, r in pairs(PW.data) do
        if r.calls > 0 then
          local v = { name = string.lower(label), calls = r.calls, now = r.nm or 0, ms = r.ms, avg = r.ms / r.calls, kb = r.kb }
          table.insert(out, { label = label, v = v, cols = { label, tostring(r.calls), F(v.now, 2), F(v.ms, 0), F(v.avg, 3), F(v.kb, 0) } })
        end
      end
    end
    local key = PW.sort
    table.sort(out, function(a, b)
      local x, y = a.v[key], b.v[key]
      if x == nil or y == nil then return a.v.name < b.v.name end
      if key == "name" then return x < y end
      if x == y then return a.v.name < b.v.name end
      return x > y
    end)
    return out
  end

  function PW.Status()
    local fps = math.floor((GetFramerate and tonumber(GetFramerate()) or 0) + .5)
    local lag = 0
    if GetNetStats then local _, _, l = GetNetStats() lag = tonumber(l) or 0 end
    local s = "FPS |cffffffff" .. fps .. "|r   Latency |cffffffff" .. lag .. " ms|r   Lua |cffffffff"
      .. F(Mem() / 1024, 1) .. " MB|r   growing |cffffffff" .. F(PF.rate or 0, 0) .. " KB/s|r"
    if PF.held then s = s .. "   |cff55ff55clean-up held for the fight|r" end
    return s
  end

  -- ---------------------------------------------------------------- the window
  local ROWS, ROWH = 20, 16
  function PW.Build()
    if PW.frame then return PW.frame end
    local ar, ag, ab = .2, 1, .8
    if GetAccentColor then ar, ag, ab = GetAccentColor() end
    local fs = C.global.font_size
    local function Text(parent, size, just)
      local t = parent:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      t:SetFont(pfUI.font_default, size or fs, "OUTLINE")
      t:SetJustifyH(just or "LEFT")
      return t
    end
    local function Btn(parent, label, w, fn, tip)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w) b:SetHeight(18)
      b:SetText(label)
      if SkinButton then SkinButton(b) end
      b:SetScript("OnClick", fn)
      if tip then
        b:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_TOP") GameTooltip:SetText(tip, 1, 1, 1, 1, true) GameTooltip:Show() end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      end
      return b
    end

    local f = CreateFrame("Frame", "pfOctoPerfWindow", UIParent)
    PW.frame = f
    f:SetFrameStrata("DIALOG")
    f:SetWidth(680)
    f:SetHeight(ROWS * ROWH + 104)
    local pos = pfUI_cache and pfUI_cache.perfwin
    if pos and pos.x then f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y) else f:SetPoint("CENTER", 0, 0) end
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function()
      this:StopMovingOrSizing()
      pfUI_cache = pfUI_cache or {}
      pfUI_cache.perfwin = { x = this:GetLeft(), y = this:GetTop() }
    end)
    f:EnableMouseWheel(1)
    f:Hide()
    CreateBackdrop(f, nil, true, .9)
    if CreateBackdropShadow then CreateBackdropShadow(f) end
    table.insert(UISpecialFrames, "pfOctoPerfWindow")

    f.title = Text(f, fs + 3)
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.title:SetText("pfUI Octo Performance")
    f.title:SetTextColor(ar, ag, ab)
    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetWidth(20) f.close:SetHeight(20)
    f.close:SetPoint("TOPRIGHT", 0, 0)
    f.close:SetScript("OnClick", function() f:Hide() end)
    if SkinCloseButton then SkinCloseButton(f.close, f, -6, -6) end

    f.status = Text(f)
    f.status:SetPoint("TOPLEFT", 10, -28)

    -- tabs + buttons
    f.tabs = {}
    local function Tab(key, label, x)
      local b = Btn(f, label, 80, function() PW.mode = key PW.sort = "now" PW.offset = 0 PW.Refresh(true) end)
      b:SetPoint("TOPLEFT", x, -46)
      f.tabs[key] = b
    end
    Tab("scripts", "Scripts", 10)
    Tab("addons", "Add-ons", 94)
    f.scan = Btn(f, "Scan", 70, function()
      local seen, added = PW.Scan()
      PW.noteUntil = GT() + 6
      PW.note = "Looked at " .. seen .. " frames, measuring " .. added .. " more scripts (" .. PW.Hooked() .. " in all)."
      PW.Refresh(true)
    end, "Measures every frame's OnUpdate and OnEvent, like pfDebug's Scan - but finds frames through the game's own list, so it never walks the game's tables (that is what crashed). Scan again later to catch frames made since.")
    f.scan:SetPoint("TOPLEFT", 200, -46)
    f.stop = Btn(f, "Stop", 60, function()
      local n = PW.Unhook()
      PW.noteUntil = GT() + 6
      PW.note = n .. " scripts put back as they were."
      PW.Refresh(true)
    end, "Puts every measured script back as it was (measuring costs a little).")
    f.stop:SetPoint("LEFT", f.scan, "RIGHT", 4, 0)
    f.pause = Btn(f, "Pause", 70, function() PW.on = not PW.on PW.Refresh(true) end, "Stops counting (scripts stay wrapped) so the numbers can be read.")
    f.pause:SetPoint("LEFT", f.stop, "RIGHT", 4, 0)
    f.reset = Btn(f, "Reset", 60, function() PW.Reset() PW.Refresh(true) end, "Counts from now on: reset before the pull.")
    f.reset:SetPoint("LEFT", f.pause, "RIGHT", 4, 0)
    f.prof = Btn(f, "CPU profiler", 100, function() PF.SetProfiling(not PF.profiling) end,
      "ClassicAPI's profiler: CPU time per add-on on the Add-ons tab. Switching reloads the game; switch it off after (it costs a little).")
    f.prof:SetPoint("LEFT", f.reset, "RIGHT", 4, 0)

    -- column heads (click = sort)
    f.heads = {}
    for i = 1, 6 do
      local h = CreateFrame("Button", nil, f)
      h:SetHeight(ROWH)
      h.text = Text(h)
      h.text:SetAllPoints()
      h.text:SetTextColor(ar, ag, ab)
      h:SetScript("OnClick", function() if this.key then PW.sort = this.key PW.Refresh(true) end end)
      f.heads[i] = h
    end
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetTexture(ar, ag, ab, .5)
    f.rule:SetHeight(1)
    f.rule:SetPoint("TOPLEFT", 8, -86)
    f.rule:SetPoint("TOPRIGHT", -8, -86)

    f.rows = {}
    for i = 1, ROWS do
      local r = CreateFrame("Frame", nil, f)
      r:SetHeight(ROWH)
      r:SetPoint("TOPLEFT", 8, -88 - (i - 1) * ROWH)
      r:SetPoint("TOPRIGHT", -8, -88 - (i - 1) * ROWH)
      r.bg = r:CreateTexture(nil, "BACKGROUND")
      r.bg:SetAllPoints()
      r.bg:SetTexture(1, 1, 1, i - math.floor(i / 2) * 2 == 0 and .04 or 0)
      r.cols = {}
      for c = 1, 6 do r.cols[c] = Text(r, nil, c == 1 and "LEFT" or "RIGHT") end
      f.rows[i] = r
    end
    f.note = Text(f)
    f.note:SetPoint("BOTTOMLEFT", 10, 8)
    f.note:SetPoint("BOTTOMRIGHT", -10, 8)
    f.note:SetTextColor(.7, .7, .7)

    f:SetScript("OnMouseWheel", function()
      PW.offset = math.max(0, (PW.offset or 0) - arg1 * 3)
      PW.Refresh(true)
    end)
    local last, lastAt = 0, GT()
    f:SetScript("OnUpdate", function()
      local now = GT()
      if now - last < 1 then return end
      local secs = now - lastAt
      last, lastAt = now, now
      if PW.on then
        PW.Step(secs)
        if PW.mode == "addons" then PW.StepAddons(secs) end
      end
      if PF.Sample then PF.Sample() end
      PW.Refresh()
    end)
    f:SetScript("OnShow", function() if PW.mode == "addons" then PW.StepAddons(1) end PW.Refresh(true) end)
    return f
  end

  function PW.Refresh()
    local f = PW.frame
    if not f or not f:IsShown() then return end
    f.status:SetText(PW.Status())
    for k, b in pairs(f.tabs) do
      local fs = b:GetFontString()
      if fs then if k == PW.mode then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(.6, .6, .6) end end
    end
    f.pause:SetText(PW.on and "Pause" or "Resume")
    f.prof:SetText(PF.profiling and "CPU profiler: on" or "CPU profiler: off")
    local scripts = PW.mode == "scripts"
    f.scan:Show() f.stop:Show()
    if not scripts then f.scan:Hide() f.stop:Hide() end
    if not PF.CanMeasure() then f.prof:Hide() else f.prof:Show() end

    -- columns
    local cols = PW.COLS[PW.mode]
    local x = 8
    for i, h in ipairs(f.heads) do
      local c = cols[i]
      if c then
        h.key = c[1]
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", f, "TOPLEFT", x, -70)
        h:SetWidth(c[3])
        h.text:SetJustifyH(i == 1 and "LEFT" or "RIGHT")
        h.text:SetText(c[2] .. (PW.sort == c[1] and " v" or ""))
        h:Show()
        for _, r in ipairs(f.rows) do
          local t = r.cols[i]
          t:ClearAllPoints()
          t:SetPoint("LEFT", r, "LEFT", x - 8, 0)
          t:SetWidth(c[3])
          t:Show()
        end
        x = x + c[3] + 8
      else
        h:Hide()
        for _, r in ipairs(f.rows) do r.cols[i]:Hide() end
      end
    end

    local list = PW.Rows()
    local n = table.getn(list)
    PW.offset = math.min(PW.offset or 0, math.max(0, n - ROWS))
    for i, r in ipairs(f.rows) do
      local e = list[i + PW.offset]
      for c = 1, table.getn(cols) do r.cols[c]:SetText(e and e.cols[c] or "") end
      if e and PW.mode == "scripts" and e.v.now >= 1 then r.cols[3]:SetTextColor(1, .4, .4)
      elseif e and PW.mode == "scripts" and e.v.now >= .25 then r.cols[3]:SetTextColor(1, .82, .3)
      else r.cols[3]:SetTextColor(1, 1, 1) end
    end

    local note
    if scripts then
      if not PW.scanned then note = "Press Scan to start measuring every frame's scripts (safe - it never walks the game's tables)."
      elseif n == 0 then note = "Measuring " .. PW.Hooked() .. " scripts - nothing has run yet."
      else note = (PW.note and (PW.noteUntil or 0) > GT()) and PW.note or ("Measuring " .. PW.Hooked() .. " scripts. Red = over 1 ms every second. Wheel scrolls, column heads sort.") end
    else
      if not PW.CanAddons() then note = "Add-on numbers need ClassicAPI (\"Install pfUI Octo DLLs.bat\")."
      elseif not PF.profiling then note = "Memory per add-on shown. CPU per add-on needs the CPU profiler (button above, reloads)."
      else note = "CPU and memory per add-on. Switch the CPU profiler off after (it costs a little)." end
    end
    if not PW.on then note = "|cffffcc00Paused.|r " .. note end
    f.note:SetText(note)
  end

  function PW.Toggle(show)
    local f = PW.Build()
    if show == nil then show = not f:IsShown() end
    if show then f:Show() else f:Hide() end
  end

  -- /pfperf now opens the window; the chat lines stay as /pfperf chat
  local old = _G.SlashCmdList.PFPERF
  _G.SlashCmdList.PFPERF = function(msg)
    local m = string.lower(msg or "")
    if m == "" or m == "window" or m == "show" then PW.Toggle() return end
    if m == "chat" then if old then old("") end return end
    if m == "scan" then PW.Toggle(true) PW.frame.scan:Click() return end
    if m == "stop" then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r performance: " .. PW.Unhook() .. " scripts put back.") return end
    if old then old(msg) end
  end
end)
