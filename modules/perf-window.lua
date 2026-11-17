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

  -- the clock the wrappers read: the game's own, called directly (17 Nov 2026: going through PW.Clock's checks cost
  -- about 3 microseconds a call, so every idle OnUpdate looked like 0.3-0.8 ms a second). PW.over = what one clock
  -- read itself costs, taken off each measurement.
  local clockFn, memFn = PW.Clock, Mem
  PW.over = 0
  function PW.Calibrate()
    local dps = rawget(_G, "debugprofilestop")
    clockFn = type(dps) == "function" and pcall(dps) and dps or PW.Clock
    memFn = type(gcinfo) == "function" and gcinfo or Mem
    local t0 = clockFn()
    for _ = 1, 200 do clockFn() end
    PW.over = math.max(0, (clockFn() - t0) / 201)
  end

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
      local m0, t0 = memFn(), clockFn()
      orig(a1, a2, a3, a4, a5, a6, a7, a8, a9)
      local dt, dm = clockFn() - t0 - PW.over, memFn() - m0
      rec.calls = rec.calls + 1
      if dt > 0 then rec.ms = rec.ms + dt end
      if dm > 0 then rec.kb = rec.kb + dm end
    end
  end

  local function Label(f)
    local l = PF.Label and PF.Label(f) or (f.GetName and f:GetName())
    -- nothing to go by (another add-on's or the game's unnamed frame): say so instead of a bare "Frame"
    local kind = f.GetObjectType and f:GetObjectType()
    if not l or l == kind then return "unnamed " .. (kind or "frame") .. " (other add-ons / game)" end
    return l
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
    PW.Calibrate()
    if not PW.since then PW.since = GT() end
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
    PW.since = GT()
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
    -- (widths + 8 px gaps must stay inside the list, 680 - 32 = 648 px: they were 698 and the last column ran out)
    scripts = { { "name", "Script", 270 }, { "calls", "Calls", 60 }, { "now", "Now ms/s", 70 }, { "ms", "Total ms", 70 },
      { "avg", "Avg ms", 56 }, { "kb", "KB made", 60 } },
    addons = { { "name", "Add-on", 270 }, { "now", "CPU ms/s", 80 }, { "ms", "CPU total", 80 }, { "mem", "Memory", 80 },
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

  -- ---------------------------------------------------------------- copy everything as text
  -- (17 Nov 2026, user: "a way to copy all this data in one ... screenshots would take alot ... without lag").
  -- Made only when Copy is pressed: one pass over the records, plain text, no colour codes.
  -- (same day, user: "over 2500 scripts we need a way to get all of them without loosing which we already did"):
  -- every script goes in, and the text is frozen when Copy is pressed (PW.snap) and cut into parts of PW.PARTLINES
  -- lines; the copy box steps through them and marks each part copied, so the numbers never shift between parts.
  PW.PARTLINES = 400
  local function Plain(s) return (string.gsub(string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", ""), "|r", "")) end
  local function Pad(s, n)
    s = tostring(s)
    local l = string.len(s)
    if l >= n then return s end
    return string.rep(" ", n - l) .. s
  end
  -- every line of the report as a list
  function PW.Lines()
    local out = {}
    local secs = math.max(1, GT() - (PW.since or GT()))
    table.insert(out, "pfUI Octo performance - " .. (date and date("%Y-%m-%d %H:%M") or "") .. " - over " .. math.floor(secs) .. " s"
      .. " - pfUI Octo " .. tostring(pfUI.version and pfUI.version.octo or "?"))
    table.insert(out, Plain(PW.Status()))
    -- scripts, by total time (the ones that never ran last, by name)
    local list = {}
    for label, r in pairs(PW.data) do table.insert(list, { label, r }) end
    table.sort(list, function(a, b)
      if a[2].ms ~= b[2].ms then return a[2].ms > b[2].ms end
      if a[2].calls ~= b[2].calls then return a[2].calls > b[2].calls end
      return a[1] < b[1]
    end)
    local n, ran = table.getn(list), 0
    for i = 1, n do if list[i][2].calls > 0 then ran = ran + 1 end end
    table.insert(out, "")
    table.insert(out, "SCRIPTS (" .. PW.Hooked() .. " measured, " .. n .. " listed, " .. ran .. " ran)")
    table.insert(out, "     # |   ms/s |  total ms |   calls |  avg ms |    KB | script")
    for i = 1, n do
      local label, r = list[i][1], list[i][2]
      table.insert(out, Pad(i, 6) .. " | " .. Pad(F(r.ms / secs, 2), 6) .. " | " .. Pad(F(r.ms, 0), 9) .. " | " .. Pad(r.calls, 7) .. " | "
        .. Pad(r.calls > 0 and F(r.ms / r.calls, 3) or "-", 7) .. " | " .. Pad(F(r.kb, 0), 5) .. " | " .. label)
    end
    -- add-ons, by memory
    if PW.CanAddons() then
      PW.StepAddons(secs)
      local al = {}
      for name, a in pairs(PW.addons) do table.insert(al, { name, a }) end
      table.sort(al, function(a, b) return (a[2].mem or 0) > (b[2].mem or 0) end)
      table.insert(out, "")
      table.insert(out, "ADD-ONS (" .. table.getn(al) .. ")" .. (PF.profiling and "" or " - CPU needs the CPU profiler"))
      table.insert(out, "  memory KB | CPU total ms | add-on")
      for _, e in ipairs(al) do
        table.insert(out, Pad(F(e[2].mem, 0), 11) .. " | " .. Pad(PF.profiling and F(e[2].cpu, 0) or "-", 12) .. " | " .. e[1])
      end
    end
    return out
  end
  function PW.Text()
    local out = PW.Lines()
    return table.concat(out, "\n"), table.getn(out)
  end

  -- a frozen report cut into parts: { lines, parts = { { from, to } }, done = { [k] = true }, at = k }
  function PW.Snapshot()
    local lines = PW.Lines()
    local n = table.getn(lines)
    local snap = { lines = lines, parts = {}, done = {}, at = 1, made = GT() }
    local per = PW.PARTLINES
    local from = 1
    while from <= n do
      table.insert(snap.parts, { from, math.min(n, from + per - 1) })
      from = from + per
    end
    PW.snap = snap
    return snap
  end
  -- the text of one part, with a heading saying which it is
  function PW.PartText(k)
    local snap = PW.snap
    local p = snap and snap.parts[k]
    if not p then return "" end
    local total = table.getn(snap.parts)
    local head = "=== pfUI Octo performance - part " .. k .. " of " .. total .. " (lines " .. p[1] .. "-" .. p[2]
      .. " of " .. table.getn(snap.lines) .. ") ==="
    local out = { head }
    for i = p[1], p[2] do table.insert(out, snap.lines[i]) end
    return table.concat(out, "\n")
  end

  local function Clip(text)
    local lc = pfUI.api and pfUI.api.libclient
    return lc and lc.Copy and lc.Copy(text, true)
  end
  PW.MAXPARTBTN = 16

  -- the copy box: one part at a time, selected for Ctrl+C; parts already copied are marked
  function PW.BuildCopy()
    if PW.copybox then return PW.copybox end
    local ar, ag, ab = .2, 1, .8
    if GetAccentColor then ar, ag, ab = GetAccentColor() end
    local b = CreateFrame("Frame", "pfOctoPerfCopy", UIParent)
    b:SetWidth(720) b:SetHeight(470)
    b:SetPoint("CENTER", 0, 40)
    b:SetFrameStrata("FULLSCREEN_DIALOG")
    b:EnableMouse(true)
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() this:StartMoving() end)
    b:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    CreateBackdrop(b, nil, true, .95)
    b.title = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.title:SetPoint("TOPLEFT", 10, -8)
    b.title:SetPoint("TOPRIGHT", -30, -8)
    b.title:SetJustifyH("LEFT")
    b.title:SetTextColor(ar, ag, ab)
    local close = CreateFrame("Button", nil, b, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() b:Hide() end)
    if SkinCloseButton then SkinCloseButton(close, b, -6, -6) end
    local function Btn(label, w, fn)
      local x = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
      x:SetWidth(w) x:SetHeight(18)
      x:SetText(label)
      if SkinButton then SkinButton(x) end
      x:SetScript("OnClick", fn)
      return x
    end
    b.prev = Btn("< Previous", 90, function() PW.ShowPart(PW.snap.at - 1) end)
    b.prev:SetPoint("TOPLEFT", 10, -28)
    b.copy = Btn("Copy this part", 120, function() PW.CopyPart() end)
    b.copy:SetPoint("LEFT", b.prev, "RIGHT", 4, 0)
    b.next = Btn("Next >", 90, function() PW.ShowPart(PW.snap.at + 1) end)
    b.next:SetPoint("LEFT", b.copy, "RIGHT", 4, 0)
    b.all = Btn("Copy all at once", 130, function()
      if Clip(table.concat(PW.snap.lines, "\n")) then
        for k in ipairs(PW.snap.parts) do PW.snap.done[k] = true end
        b.say = "Every part copied to the clipboard in one go."
      else
        b.say = "No clipboard here (needs ClassicAPI): copy the parts one by one."
      end
      PW.ShowPart(PW.snap.at)
    end)
    b.all:SetPoint("LEFT", b.next, "RIGHT", 4, 0)
    b.fresh = Btn("New numbers", 100, function() PW.Snapshot() b.say = "New numbers taken: start again at part 1." PW.ShowPart(1) end)
    b.fresh:SetPoint("LEFT", b.all, "RIGHT", 4, 0)
    -- one small button per part: grey = not yet, green = copied, white edge = shown
    b.pbtn = {}
    for k = 1, PW.MAXPARTBTN do
      local x = Btn(tostring(k), 34, function() PW.ShowPart(this.part) end)
      x.part = k
      x:SetPoint("TOPLEFT", 10 + (k - 1) * 38, -50)
      b.pbtn[k] = x
    end
    b.say = nil
    b.info = b:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    b.info:SetPoint("BOTTOMLEFT", 10, 8)
    b.info:SetPoint("BOTTOMRIGHT", -10, 8)
    b.info:SetJustifyH("LEFT")
    b.info:SetTextColor(.75, .75, .75)
    local sf = CreateFrame("ScrollFrame", "pfOctoPerfCopyScroll", b, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 10, -74)
    sf:SetPoint("BOTTOMRIGHT", -30, 26)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetWidth(670)
    eb:SetScript("OnEscapePressed", function() b:Hide() end)
    -- Ctrl+C in the box counts the shown part as copied
    eb:SetScript("OnKeyDown", function()
      if arg1 == "C" and IsControlKeyDown() and PW.snap then
        PW.snap.done[PW.snap.at] = true
        PW.PaintParts()
      end
    end)
    sf:SetScrollChild(eb)
    b.scroll = sf
    b.edit = eb
    table.insert(UISpecialFrames, "pfOctoPerfCopy")
    PW.copybox = b
    return b
  end

  function PW.PaintParts()
    local b, snap = PW.copybox, PW.snap
    if not b or not snap then return end
    local total = table.getn(snap.parts)
    local done = 0
    for k in pairs(snap.done) do if k <= total then done = done + 1 end end
    for k, x in ipairs(b.pbtn) do
      if k <= total then
        x:Show()
        local fs = x:GetFontString()
        if fs then
          if snap.done[k] then fs:SetTextColor(.3, 1, .4) elseif k == snap.at then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(.55, .55, .55) end
        end
        x:SetText(snap.done[k] and (k .. "+") or tostring(k))
      else
        x:Hide()
      end
    end
    if snap.at > 1 then b.prev:Enable() else b.prev:Disable() end
    if snap.at < total then b.next:Enable() else b.next:Disable() end
    local p = snap.parts[snap.at] or { 0, 0 }
    b.title:SetText("Part " .. snap.at .. " of " .. total .. "  (lines " .. p[1] .. "-" .. p[2] .. " of " .. table.getn(snap.lines) .. ")   -   "
      .. done .. " of " .. total .. " copied")
    b.info:SetText(b.say or ((done >= total) and "|cff55ff55All parts copied.|r Paste each one in order - the numbers stay as they were when Copy was pressed."
      or "Ctrl+C copies the part shown (or \"Copy this part\"), then Next. Green + = copied. The numbers are frozen until \"New numbers\"."))
    b.say = nil
  end

  function PW.ShowPart(k)
    local snap = PW.snap or PW.Snapshot()
    local total = table.getn(snap.parts)
    k = math.max(1, math.min(total, k or 1))
    snap.at = k
    local b = PW.BuildCopy()
    b.edit:SetText(PW.PartText(k))
    if b.scroll.SetVerticalScroll then b.scroll:SetVerticalScroll(0) end
    b:Show()
    b.edit:SetFocus()
    b.edit:HighlightText()
    PW.PaintParts()
  end

  function PW.CopyPart()
    local snap = PW.snap
    if not snap then return end
    if Clip(PW.PartText(snap.at)) then
      snap.done[snap.at] = true
      PW.copybox.say = "Part " .. snap.at .. " copied to the clipboard - paste it, then Next."
    else
      PW.copybox.say = "No clipboard here (needs ClassicAPI): press Ctrl+C in the box."
    end
    PW.PaintParts()
  end

  -- Copy all: freeze the numbers, open part 1 (or carry on where you were with the same numbers)
  function PW.CopyAll()
    local snap = PW.snap
    if not snap or (PW.copybox and not PW.copybox:IsShown() and snap.done[table.getn(snap.parts)]) then snap = PW.Snapshot() end
    PW.ShowPart(snap.at or 1)
    PW.note = table.getn(snap.lines) .. " lines in " .. table.getn(snap.parts) .. " parts - the box steps through them."
    PW.noteUntil = GT() + 8
    PW.Refresh(true)
  end

  -- text cut to fit its width with "..." (user, 17 Nov 2026: "the text also still leaves the window"). Only works when
  -- the text or width changed; a cut text loses its colour codes (they could be cut in half).
  function PW.Fit(t, text, w)
    text = text or ""
    if t.fitFull == text and t.fitW == w then return end
    t.fitFull, t.fitW = text, w
    t:SetText(text)
    if not w or w <= 0 or (t:GetStringWidth() or 0) <= w then return end
    local plain = Plain(text)
    local lo, hi = 0, string.len(plain)
    while lo < hi do
      local mid = math.floor((lo + hi + 1) / 2)
      t:SetText(string.sub(plain, 1, mid) .. "...")
      if (t:GetStringWidth() or 0) <= w then lo = mid else hi = mid - 1 end
    end
    t:SetText(string.sub(plain, 1, lo) .. "...")
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
        -- (the title, then the text as a wrapping line: 1.12's SetText has no wrap and ran off the screen)
        b:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:SetText(label, 1, 1, 1)
          GameTooltip:AddLine(tip, .85, .85, .85, 1)
          GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      end
      return b
    end

    local f = CreateFrame("Frame", "pfOctoPerfWindow", UIParent)
    PW.frame = f
    f:SetFrameStrata("DIALOG")
    f:SetWidth(680)
    f:SetHeight(ROWS * ROWH + 116)
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
    f.copy = Btn(f, "Copy all", 76, function() PW.CopyAll() end,
      "Every script and add-on as text, in parts of " .. PW.PARTLINES .. " lines: the numbers are frozen when you press it, "
      .. "a box steps through the parts (Ctrl+C or Copy this part) and marks the ones copied. Made only when pressed, so it costs nothing while you play.")
    f.copy:SetPoint("LEFT", f.prof, "RIGHT", 4, 0)

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
      r:SetPoint("TOPRIGHT", -24, -88 - (i - 1) * ROWH)
      r.bg = r:CreateTexture(nil, "BACKGROUND")
      r.bg:SetAllPoints()
      r.bg:SetTexture(1, 1, 1, i - math.floor(i / 2) * 2 == 0 and .04 or 0)
      r.cols = {}
      for c = 1, 6 do r.cols[c] = Text(r, nil, c == 1 and "LEFT" or "RIGHT") end
      -- hover: the whole name (long ones are cut to fit)
      r:EnableMouse(true)
      r:SetScript("OnEnter", function()
        if not this.full then return end
        GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
        GameTooltip:SetText(this.full, 1, 1, 1)
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r:EnableMouseWheel(1)
      r:SetScript("OnMouseWheel", function() local w = f:GetScript("OnMouseWheel") if w then w() end end)
      f.rows[i] = r
    end
    -- scroll bar: shows where you are in the list; drag it, or the wheel anywhere on the window
    local bar = CreateFrame("Slider", nil, f)
    f.bar = bar
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(10)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -88)
    bar:SetHeight(ROWS * ROWH)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetTexture(0, 0, 0, .5)
    bar.thumb = bar:CreateTexture(nil, "OVERLAY")
    bar.thumb:SetTexture(ar, ag, ab, .9)
    bar.thumb:SetWidth(10)
    bar.thumb:SetHeight(30)
    bar:SetThumbTexture(bar.thumb)
    bar:SetValueStep(1)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function()
      if PW.syncing then return end
      PW.offset = math.floor((this:GetValue() or 0) + .5)
      PW.Refresh(true)
    end)

    f.count = Text(f, nil, "RIGHT")
    f.count:SetPoint("BOTTOMRIGHT", -10, 8)
    f.count:SetWidth(120)
    f.count:SetTextColor(.7, .7, .7)
    f.note = Text(f)
    f.note:SetPoint("BOTTOMLEFT", 10, 8)
    f.note:SetPoint("BOTTOMRIGHT", -134, 8)
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
    PW.Fit(f.status, PW.Status(), (f:GetWidth() or 680) - 40)
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
    -- the scroll bar follows (its own OnValueChanged kept quiet meanwhile)
    local maxOff = math.max(0, n - ROWS)
    PW.syncing = true
    f.bar:SetMinMaxValues(0, maxOff)
    f.bar:SetValue(PW.offset)
    PW.syncing = nil
    if maxOff > 0 then f.bar:Show() else f.bar:Hide() end
    f.count:SetText(n == 0 and "" or ((PW.offset + 1) .. "-" .. math.min(n, PW.offset + ROWS) .. " of " .. n))
    for i, r in ipairs(f.rows) do
      local e = list[i + PW.offset]
      for c = 1, table.getn(cols) do PW.Fit(r.cols[c], e and e.cols[c] or "", cols[c][3]) end
      -- the full name on hover when it had to be cut
      r.full = e and e.label
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
    if PW.note and (PW.noteUntil or 0) > GT() then note = PW.note end
    if not PW.on then note = "|cffffcc00Paused.|r " .. note end
    PW.Fit(f.note, note, (f:GetWidth() or 680) - 150)
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
