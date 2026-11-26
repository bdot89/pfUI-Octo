-- pfUI Octo :: performance (16 Nov 2026; user: "optimize this addon now whereever we can make the FPS as good as it
-- can possibly be it should not stutter in any raids all should be smooth max FPS. use DLLs where needed").
--   smooth   the game's Lua (5.0) cleans its memory all at once, the whole game stopped while it walks every table -
--            with pfQuest's database loaded that is a hitch you see, and it comes when memory has doubled, often
--            in the middle of a pull. In a fight the clean-up waits (its threshold is raised by a set amount); two
--            seconds after the fight, and after a loading screen, it runs - where a short hitch does not matter.
--   raid fx  in raids (or any instance) the costly screen effects are lowered: full screen glow, weather, particles,
--            footprint particles, view distance; the player's own values are kept (pfUI_cache.perfsaved, so a crash
--            in a raid still gets them back) and put back on leaving.
--   measure  ClassicAPI's profiler (CVar scriptProfile, a reload to switch): CPU time of every add-on and of the
--            busiest frames, frames made by pfUI labelled with the module that made them; /pfperf.
-- The labelling wraps CreateFrame only while measuring (pfUI.loading is the module starting, pfUI.lua).

pfUI.perf = pfUI.perf or { tags = setmetatable({}, { __mode = "k" }) }
do
  local PF = pfUI.perf
  local ok, v = pcall(function() return GetCVar and GetCVar("scriptProfile") end)
  PF.profiling = ok and (v == "1" or v == 1) or false
  if PF.profiling and type(CreateFrame) == "function" and not PF.wrapped then
    PF.wrapped = true
    local raw = CreateFrame
    CreateFrame = function(a, b, c, d, e)
      local f = raw(a, b, c, d, e)
      if f and pfUI.loading then PF.tags[f] = pfUI.loading end
      return f
    end
  end
end

pfUI:RegisterModule("perf", "vanilla", function ()
  local PF = pfUI.perf
  local function G() return C.perf end
  local function On(k) return G()[k] == "1" end
  local function Num(k, d) return tonumber(G()[k]) or d end
  local function Now() return GetTime and GetTime() or 0 end
  local function Say(t) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r performance: " .. t) end
  PF.cleans, PF.held = 0, false

  -- ---------------------------------------------------------------- memory: no clean-up in a fight
  function PF.CanGC() return type(collectgarbage) == "function" and type(gcinfo) == "function" end
  -- (18 Nov 2026, Wolfahrt on Discord: "critical error" #132 after an import and at logins; the same crash on the
  -- user's own client: an ACCESS_VIOLATION in DXVK's d3d9.dll memset writing near address 0 = a memory request that
  -- came back empty - the game ran out of memory). pfUI + pfQuest hold ~290 MB of Lua memory; Lua 5.0 lets garbage
  -- pile up until the total doubles (580 MB) before it cleans, and the fight hold above added up to 150 MB more on top.
  -- With DXVK's own ~1 GB that runs the 32-bit game out of room. So: a ceiling. Out of a fight garbage may grow by
  -- C.perf.gcroom MB (not double), in a fight by gcextra, and never past C.perf.gcmax MB in all.
  PF.live = nil   -- Lua memory right after the last clean-up (KB): what is really in use
  function PF.Ceiling() return Num("gcmax", 600) * 1024 end
  -- the most garbage allowed now (KB above PF.live)
  function PF.Room() return (PF.held and Num("gcextra", 150) or Num("gcroom", 64)) * 1024 end
  -- lower Lua's own threshold to live + room (never past the ceiling); clean at once if already past the ceiling
  PF.FORCE_GAP = 30
  function PF.Steer()
    if not On("gccap") or not PF.CanGC() then return end
    local kb, th = gcinfo()
    if not kb then return end
    -- a clean-up ran (by Lua or by us) since the last look: what is left is the real use
    if not PF.live or (PF.lastKb and kb < PF.lastKb - 2048) then PF.live = kb end
    PF.lastKb = kb
    local ceiling = PF.Ceiling()
    -- (22 Nov 2026, Wolfahrt in BWL: "huge lag spikes (1 FPS)") when what is really in use is already near the
    -- ceiling, a clean-up cannot bring it under: it ran a full collectgarbage() - over half a second on 600 MB -
    -- EVERY second. A ceiling below the real use is no ceiling: it moves up to live + room, and a forced
    -- clean-up runs at most once every PF.FORCE_GAP seconds.
    if PF.live and PF.live + Num("gcroom", 64) * 1024 > ceiling then
      ceiling = PF.live + PF.Room()
      if not PF.toldBig then
        PF.toldBig = true
        Say("your add-ons hold " .. math.floor(PF.live / 1024) .. " MB of Lua memory, more than the " .. Num("gcmax", 600) ..
          " MB ceiling (Settings > Performance). Turning off add-ons you do not use (or pfQuest's database) frees the most.")
      end
    end
    if kb >= ceiling and Now() - (PF.forcedAt or -1000) >= PF.FORCE_GAP then
      PF.forcedAt = Now()
      -- a hitch now is better than the game crashing out of memory, in a fight too
      PF.Clean("over the " .. Num("gcmax", 600) .. " MB ceiling")
      PF.live = gcinfo()
      PF.lastKb = PF.live
      return
    end
    local want = math.min(PF.live + PF.Room(), ceiling)
    -- past the ceiling but a forced clean-up ran under PF.FORCE_GAP ago: room again, so Lua does not clean right away
    -- by itself (the same full stop, just from Lua)
    if kb >= ceiling then want = kb + PF.Room() end
    -- never so low that it cleans this instant (that is PF.Clean's job)
    if want < kb + 2048 then want = kb + 2048 end
    if not th or want < th - 1024 or (PF.held and want > th + 1024) then collectgarbage(math.floor(want)) end
  end
  function PF.Hold()
    if not On("gc") or not PF.CanGC() then return end
    PF.held = true
    local kb, th = gcinfo()
    local want = math.min(kb + Num("gcextra", 150) * 1024, PF.Ceiling())
    if On("gccap") then PF.Steer() elseif not th or want > th then collectgarbage(want) end
  end
  function PF.Clean(why)
    if not PF.CanGC() then return end
    local before = gcinfo()
    local t0 = Now()
    collectgarbage()
    PF.held = false
    PF.live = gcinfo()
    PF.lastKb = PF.live
    PF.cleans = PF.cleans + 1
    PF.last = { why = why, freed = before - gcinfo(), ms = math.floor((Now() - t0) * 1000 + .5), at = Now() }
  end

  -- ---------------------------------------------------------------- raid graphics
  PF.FX = {
    { key = "fxglow", cvar = "ffxGlow", low = "0", label = "Full screen glow", tip = "The bloom over the whole picture: one of the costliest effects." },
    { key = "fxweather", cvar = "weatherDensity", low = "0", label = "Weather", tip = "Rain, snow and sand storms." },
    { key = "fxparticles", cvar = "particleDensity", low = "0.4", label = "Fewer spell particles", tip = "Spell effects with fewer particles (40%)." },
    { key = "fxfoot", cvar = "showfootprintparticles", low = "0", label = "Footstep dust", tip = "The little puffs under 40 pairs of feet." },
    { key = "fxfarclip", cvar = "farclip", low = "farclip", label = "Shorter view distance", tip = "Only lowered, never raised: inside a raid you rarely need to see far." },
  }
  local function Saved()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.perfsaved = pfUI_cache.perfsaved or {}
    return pfUI_cache.perfsaved
  end
  local function CVar(name)
    local ok, v = pcall(GetCVar, name)
    if ok then return v end
  end
  function PF.WantFX()
    if not On("raidfx") then return false end
    local inside, kind = false, nil
    if IsInInstance then inside, kind = IsInInstance() end
    if not inside then return false end
    local w = G().raidfxwhere or "raid"
    -- (16 Nov 2026, user: "this should have nowhere ... for people who dont care")
    if w == "off" then return false end
    if w == "raid" then return kind == "raid" end
    if w == "group" then return kind == "raid" or kind == "party" end
    return true
  end
  function PF.ApplyFX()
    local saved = Saved()
    local want = PF.WantFX()
    PF.fxOn = {}
    for _, fx in ipairs(PF.FX) do
      local cur = CVar(fx.cvar)
      if cur ~= nil then
        if want and On(fx.key) then
          local low = fx.low == "farclip" and tostring(math.min(tonumber(cur) or 9999, Num("farclip", 350))) or fx.low
          if saved[fx.cvar] == nil then saved[fx.cvar] = cur end
          if cur ~= low then pcall(SetCVar, fx.cvar, low) end
          table.insert(PF.fxOn, fx.label)
        elseif saved[fx.cvar] ~= nil then
          pcall(SetCVar, fx.cvar, saved[fx.cvar])
          saved[fx.cvar] = nil
        end
      end
    end
  end

  -- ---------------------------------------------------------------- measuring (ClassicAPI)
  function PF.CanMeasure()
    return type(_G.GetFrameCPUUsage) == "function" and type(_G.GetAddOnCPUUsage) == "function"
  end
  function PF.SetProfiling(on)
    pcall(SetCVar, "scriptProfile", on and "1" or "0")
    ReloadUI()
  end
  function PF.Reset()
    if _G.ResetCPUUsage then pcall(_G.ResetCPUUsage) end
    PF.since = Now()
    PF.report = nil
  end
  local function Label(f)
    local tag = PF.tags[f]
    local name = f.GetName and f:GetName()
    if tag then return tag .. (name and (" (" .. name .. ")") or "") end
    if name then return name end
    -- (17 Nov 2026) pfUI's own unnamed frames: the file and line that made them (profiler.lua notes them at load)
    local where = pfUI.prof and pfUI.prof.where and pfUI.prof.where[f]
    if where then return "pfUI " .. where end
    local p = f.GetParent and f:GetParent()
    local depth = 0
    while p and depth < 6 do
      local t, n = PF.tags[p], p.GetName and p:GetName()
      if t or n then return (t or n) .. " > " .. (f.GetObjectType and f:GetObjectType() or "?") end
      p = p.GetParent and p:GetParent()
      depth = depth + 1
    end
    return f.GetObjectType and f:GetObjectType() or "?"
  end
  PF.Label = Label
  -- -> { secs, pfui = ms, addons = { { name, ms } }, frames = { { label, ms } }, parts = { { module, ms } } }
  function PF.Measure()
    if not PF.CanMeasure() then return nil end
    if _G.UpdateAddOnCPUUsage then pcall(_G.UpdateAddOnCPUUsage) end
    local secs = math.max(1, Now() - (PF.since or 0))
    local r = { secs = secs, addons = {}, frames = {}, parts = {} }
    for i = 1, (GetNumAddOns and GetNumAddOns() or 0) do
      local name = GetAddOnInfo(i)
      local ok, ms = pcall(_G.GetAddOnCPUUsage, i)
      if ok and tonumber(ms) and ms > 0 then table.insert(r.addons, { name, ms }) end
      if name == "pfUI" and ok then r.pfui = ms end
    end
    table.sort(r.addons, function(a, b) return a[2] > b[2] end)
    local parts = {}
    local f = EnumerateFrames and EnumerateFrames()
    local n = 0
    while f and n < 20000 do
      local ok, ms = pcall(_G.GetFrameCPUUsage, f, false)
      if ok and tonumber(ms) and ms > 0 then
        table.insert(r.frames, { Label(f), ms })
        local tag = PF.tags[f]
        if tag then parts[tag] = (parts[tag] or 0) + ms end
      end
      f = EnumerateFrames(f)
      n = n + 1
    end
    table.sort(r.frames, function(a, b) return a[2] > b[2] end)
    for k, v in pairs(parts) do table.insert(r.parts, { k, v }) end
    table.sort(r.parts, function(a, b) return a[2] > b[2] end)
    PF.report = r
    return r
  end
  function PF.Lines(r, top)
    top = top or 10
    local out = {}
    local function Ms(v) return string.format("%.2f ms/s", v / r.secs) end
    table.insert(out, "pfUI Octo: |cffffffff" .. Ms(r.pfui or 0) .. "|r over " .. math.floor(r.secs) .. " s")
    table.insert(out, "|cffffd24dAdd-ons|r")
    for i = 1, math.min(top, table.getn(r.addons)) do table.insert(out, "  " .. r.addons[i][1] .. "  " .. Ms(r.addons[i][2])) end
    if table.getn(r.parts) > 0 then
      table.insert(out, "|cffffd24dParts of pfUI Octo|r")
      for i = 1, math.min(top, table.getn(r.parts)) do table.insert(out, "  " .. r.parts[i][1] .. "  " .. Ms(r.parts[i][2])) end
    end
    table.insert(out, "|cffffd24dBusiest frames|r")
    for i = 1, math.min(top, table.getn(r.frames)) do table.insert(out, "  " .. r.frames[i][1] .. "  " .. Ms(r.frames[i][2])) end
    return out
  end

  -- ---------------------------------------------------------------- the game's own UI ticker
  -- (17 Nov 2026, /pfperf: UIParent's OnUpdate was the costliest script, 10 ms a second.) The game runs it every
  -- frame: fades, flashes, the chat frames' mouse check, button pulses, popup menus, battleground map dots, the
  -- ready check. With C.perf.uitick on it runs 30 times a second and is given all the time since its last run,
  -- so fades and flashes keep their speed. Off = every frame again at once.
  PF.UITICK = 1 / 30
  function PF.WrapUIParent()
    local p = rawget(_G, "UIParent")
    if not p or PF.uiWrapped or not p.GetScript then return end
    local orig = p:GetScript("OnUpdate")
    if type(orig) ~= "function" then return end
    PF.uiWrapped, PF.uiOrig = true, orig
    local acc = 0
    p:SetScript("OnUpdate", function()
      local e = tonumber(_G.arg1) or 0
      if not On("uitick") then acc = 0 return orig() end
      acc = acc + e
      if acc < PF.UITICK then return end
      _G.arg1 = acc
      acc = 0
      orig()
      _G.arg1 = e
    end)
  end
  PF.WrapUIParent()

  -- (22 Nov 2026, user's HUD standing still: WorldFrame 3.4 ms a second.) The game's WorldFrame_OnUpdate runs every
  -- frame and walks its 4 popup dialogs and 3 breath / fatigue bars by name ("StaticPopup" .. i) - work that only
  -- matters while the UI is hidden (Alt+Z, the world map): then a popup's or bar's own script cannot run and this one
  -- runs it for them. With C.perf.wftick on, the frame rate text is kept up as the game does and the walk only happens
  -- while UIParent cannot be seen, over frames looked up once. Off = the game's own function.
  function PF.WrapWorldFrame()
    local orig = rawget(_G, "WorldFrame_OnUpdate")
    if type(orig) ~= "function" or PF.wfOrig then return end
    PF.wfOrig = orig
    local dialogs, bars
    _G.WorldFrame_OnUpdate = function(elapsed)
      if not On("wftick") then return orig(elapsed) end
      local wf = _G.this
      local ft = rawget(_G, "FramerateText")
      if wf and ft and ft:IsVisible() then
        local left = (wf.fpsTime or 0) - (elapsed or 0)
        if left <= 0 then
          wf.fpsTime = _G.FRAMERATE_FREQUENCY or .25
          ft:SetText(string.format("%.1f", GetFramerate()))
        else
          wf.fpsTime = left
        end
      end
      local ui = rawget(_G, "UIParent")
      if ui and ui:IsVisible() then return end
      if not dialogs then
        dialogs, bars = {}, {}
        for i = 1, (tonumber(_G.STATICPOPUP_NUMDIALOGS) or 4) do table.insert(dialogs, _G["StaticPopup" .. i] or false) end
        for i = 1, (tonumber(_G.MIRRORTIMER_NUMTIMERS) or 3) do table.insert(bars, _G["MirrorTimer" .. i] or false) end
      end
      for i = 1, table.getn(dialogs) do
        local d = dialogs[i]
        if d and d:IsShown() and not d:IsVisible() and _G.StaticPopup_OnUpdate then _G.StaticPopup_OnUpdate(d, elapsed) end
      end
      for i = 1, table.getn(bars) do
        local b = bars[i]
        if b and b:IsShown() and not b:IsVisible() and _G.MirrorTimerFrame_OnUpdate then _G.MirrorTimerFrame_OnUpdate(b, _G.arg1) end
      end
    end
  end
  PF.WrapWorldFrame()

  -- ---------------------------------------------------------------- memory growth (KB a second)
  local lastKB, lastAt = nil, 0
  function PF.Sample()
    if type(gcinfo) ~= "function" then return end
    local kb = gcinfo()
    local now = Now()
    if lastKB and kb >= lastKB and now > lastAt then PF.rate = (kb - lastKB) / (now - lastAt) end
    lastKB, lastAt = kb, now
    PF.kb = kb
  end

  -- ---------------------------------------------------------------- monitor Hz, Linux, PerfBoost (20 Nov 2026)
  -- (user: "a setting on the UI that optimizes the UI for linux ... using DLLS everywhere we can", and "a hz option
  -- where you can set your montitor hz which in turn will optimize the hidden settings and game settings".)
  -- What this client really has (checked in WoW.exe 20 Nov): gxRefresh, gxVSync, gxTripleBuffer, gxFixLag, gxCursor,
  -- RestartGx(), GetRefreshRates(). There is NO frame rate cap in 1.12 (no maxFPS CVar), and ClassicAPI's only
  -- framerate call is SetMaxAnimFramerate (its animations, default 30). A real cap comes from DXVK (dxvk.conf
  -- d3d9.maxFrameRate, or DXVK_FRAME_RATE on Linux): the page copies that line. Graphics changes go through
  -- PF.GxChange: set, RestartGx(), and a 15 s "keep it?" box that puts everything back unless kept (a wrong
  -- refresh rate can leave the screen black - safe-ui rule).
  local function CVar(name)
    local ok, v = pcall(GetCVar, name)
    if ok then return v end
  end
  PF.CVar = CVar
  PF.HZ_FALLBACK = { 60, 75, 100, 120, 144, 165, 170, 180, 240, 280, 360 }
  -- the refresh rates the game offers for this screen (numbers, low to high)
  function PF.Rates()
    local list, seen = {}, {}
    local function Add(v)
      local _, _, n = string.find(tostring(v or ""), "(%d+)")
      n = tonumber(n)
      if n and n >= 24 and n <= 600 and not seen[n] then seen[n] = true table.insert(list, n) end
    end
    if type(_G.GetRefreshRates) == "function" then
      local r = { pcall(_G.GetRefreshRates) }
      if r[1] then
        for i = 2, table.getn(r) do
          if type(r[i]) == "table" then for _, v in pairs(r[i]) do Add(v) end else Add(r[i]) end
        end
      end
    end
    PF.ratesFromGame = table.getn(list) > 0
    if not PF.ratesFromGame then for _, v in ipairs(PF.HZ_FALLBACK) do Add(v) end end
    Add(PF.CurrentHz())
    table.sort(list)
    return list
  end
  function PF.CurrentHz() return tonumber(CVar("gxRefresh")) end
  function PF.Windowed() return CVar("gxWindow") == "1" end
  -- the frame cap to give DXVK: just under the refresh rate with G-Sync / FreeSync (stays inside its range), else it
  function PF.CapFor(hz)
    hz = tonumber(hz) or PF.CurrentHz() or 60
    if On("vrr") then return math.max(30, hz - 3) end
    return hz
  end
  function PF.CapLines(hz)
    local n = PF.CapFor(hz)
    return { steam = "DXVK_FRAME_RATE=" .. n .. " %command%", env = "DXVK_FRAME_RATE=" .. n, conf = "d3d9.maxFrameRate = " .. n }
  end
  -- ClassicAPI's animations at the monitor's rate (30 a second otherwise)
  function PF.ApplyAnim()
    if type(_G.SetMaxAnimFramerate) ~= "function" then return end
    local hz = On("hzanim") and math.min(PF.CurrentHz() or 60, 240) or 30
    pcall(_G.SetMaxAnimFramerate, hz)
  end

  -- change graphics CVars, restart the graphics, ask to keep them: list = { { cvar, value }, ... }
  function PF.GxChange(list, what, after)
    if UnitAffectingCombat and UnitAffectingCombat("player") then Say("not in a fight - try again after it.") return end
    local old, changed = {}, false
    for _, c in ipairs(list) do
      local cur = CVar(c[1])
      if cur ~= nil and tostring(cur) ~= tostring(c[2]) then
        table.insert(old, { c[1], cur })
        pcall(SetCVar, c[1], tostring(c[2]))
        changed = true
      end
    end
    if not changed then if after then after(false) end return false end
    if type(_G.RestartGx) == "function" then pcall(_G.RestartGx) end
    PF.ShowKeep(old, what)
    PF.ApplyAnim()
    if after then after(true) end
    return true
  end
  function PF.UndoGx()
    local k = PF.keepOld
    PF.keepOld = nil
    if PF.keepBox then PF.keepBox:Hide() end
    if not k then return end
    for _, c in ipairs(k) do pcall(SetCVar, c[1], tostring(c[2])) end
    if type(_G.RestartGx) == "function" then pcall(_G.RestartGx) end
    PF.ApplyAnim()
    Say("graphics put back as they were.")
  end
  function PF.KeepGx()
    PF.keepOld = nil
    if PF.keepBox then PF.keepBox:Hide() end
  end
  PF.KEEPSECS = 15
  function PF.ShowKeep(old, what)
    PF.keepOld, PF.keepUntil = old, Now() + PF.KEEPSECS
    local b = PF.keepBox
    if not b then
      b = CreateFrame("Frame", "pfOctoGxKeep", UIParent)
      PF.keepBox = b
      b:SetWidth(360) b:SetHeight(96)
      b:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
      b:SetFrameStrata("FULLSCREEN_DIALOG")
      if pfUI.api.CreateBackdrop then pfUI.api.CreateBackdrop(b) end
      b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      b.text:SetPoint("TOP", b, "TOP", 0, -12)
      b.text:SetWidth(336)
      local function Btn(label, x, fn)
        local bt = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
        bt:SetWidth(120) bt:SetHeight(24)
        bt:SetPoint("BOTTOM", b, "BOTTOM", x, 12)
        bt:SetText(label)
        bt:SetScript("OnClick", fn)
        if pfUI.api.SkinButton then pcall(pfUI.api.SkinButton, bt) end
        return bt
      end
      b.keep = Btn("Keep it", -66, function() PF.KeepGx() end)
      b.undo = Btn("Put it back", 66, function() PF.UndoGx() end)
      b:SetScript("OnUpdate", function()
        local left = math.ceil((PF.keepUntil or 0) - Now())
        if left <= 0 then PF.UndoGx() return end
        b.text:SetText((b.what or "Graphics changed") .. "\nKeep it? Going back by itself in |cffffd24d" .. left .. " s|r.")
      end)
    end
    b.what = what
    b:Show()
  end

  -- the monitor card's Apply: refresh rate + vsync + triple buffering
  function PF.SetDisplay(hz, vsync, triple)
    local list = {}
    if tonumber(hz) then table.insert(list, { "gxRefresh", math.floor(tonumber(hz)) }) end
    if vsync ~= nil then table.insert(list, { "gxVSync", vsync and "1" or "0" }) end
    if triple ~= nil then table.insert(list, { "gxTripleBuffer", triple and "1" or "0" }) end
    G().hz = tostring(hz or "")
    return PF.GxChange(list, "Screen: " .. tostring(hz) .. " Hz, vsync " .. (vsync and "on" or "off") .. ".")
  end

  -- Linux (Wine / Proton / Lutris) - the game cannot tell, so it is the player's switch. What it sets:
  PF.LINUX = {
    { key = "lxfixlag", cvar = "gxFixLag", val = "0", label = "No forced wait for the graphics card",
      tip = "gxFixLag 0. With it on, the game waits for the card to finish every frame (a little less mouse delay). Off = more frames, which matters most through DXVK / Wine." },
    { key = "lxcursor", cvar = "gxCursor", val = "1", label = "Hardware mouse pointer",
      tip = "gxCursor 1. The pointer is drawn by your desktop, so it stays smooth even when the game's frame rate drops." },
  }
  local function LinuxSaved()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.perflinux = pfUI_cache.perflinux or {}
    return pfUI_cache.perflinux
  end
  function PF.WantLinux(e) return On("linux") and On(e.key) end
  -- on: each ticked part set (your own value kept to put back), effects lowered in dungeons too, memory ceiling on
  function PF.ApplyLinux(quiet)
    local saved = LinuxSaved()
    local list = {}
    for _, e in ipairs(PF.LINUX) do
      local cur = CVar(e.cvar)
      if cur ~= nil then
        if PF.WantLinux(e) then
          if saved[e.cvar] == nil then saved[e.cvar] = cur end
          table.insert(list, { e.cvar, e.val })
        elseif saved[e.cvar] ~= nil then
          table.insert(list, { e.cvar, saved[e.cvar] })
          saved[e.cvar] = nil
        end
      end
    end
    local S = G()
    if On("linux") and On("lxfx") then
      if saved.raidfxwhere == nil then saved.raidfx, saved.raidfxwhere = S.raidfx, S.raidfxwhere end
      S.raidfx = "1"
      if S.raidfxwhere == "off" or S.raidfxwhere == "raid" then S.raidfxwhere = "group" end
      S.gccap = "1"
    elseif saved.raidfxwhere ~= nil then
      S.raidfx, S.raidfxwhere = saved.raidfx or S.raidfx, saved.raidfxwhere
      saved.raidfx, saved.raidfxwhere = nil, nil
    end
    PF.ApplyFX()
    PF.Steer()
    PF.ApplyAnim()
    if quiet then
      -- (at login: no graphics restart, the CVars stay in Config.wtf anyway)
      for _, c in ipairs(list) do if tostring(CVar(c[1])) ~= tostring(c[2]) then pcall(SetCVar, c[1], tostring(c[2])) end end
      return
    end
    PF.GxChange(list, On("linux") and "Linux settings on." or "Linux settings off - your own back.")
  end

  -- the DLLs this client loaded (VanillaFixes is what loads them, so any of them = it runs)
  function PF.DLLs()
    local pb = CVar("PB_Enabled") ~= nil
    return {
      { "SuperWoW", _G.SUPERWOW_VERSION ~= nil },
      { "ClassicAPI", _G.C_UnitAuras ~= nil or type(_G.CopyToClipboard) == "function" },
      { "nampower", type(_G.QueueSpellByName) == "function" or type(_G.GetSpellRecField) == "function" },
      { "UnitXP_SP3", type(_G.UnitXP) == "function" },
      { "PerfBoost", pb },
    }
  end

  -- PerfBoost (perf_boost.dll): draws far-away players, pets and trash less - the biggest FPS gain in raids.
  -- Its settings are CVars (PB_*, -1 = no limit, in yards up to 100); PerfBoostSettings (the add-on) sets them at login
  -- from its own profile when it is on.
  function PF.HasPB() return CVar("PB_Enabled") ~= nil end
  PF.PB = {
    { cvar = "PB_PlayerRenderDist", label = "Players", tip = "How far away other players are still drawn, out of combat." },
    { cvar = "PB_PlayerRenderDistInCombat", label = "Players in combat", tip = "The same in a fight: the setting that saves the most frames in raids." },
    { cvar = "PB_PlayerRenderDistInCities", label = "Players in cities", tip = "Cities are full of players: drawing only the near ones helps a lot." },
    { cvar = "PB_PetRenderDistInCombat", label = "Pets in combat", tip = "Other players' pets in a fight. Your own pet is always drawn." },
    { cvar = "PB_TrashUnitRenderDistInCombat", label = "Trash in combat", tip = "Small enemies in a fight. Bosses and named ones are always drawn." },
  }
  PF.PBLOOKS = {
    all = { label = "Show everything", vals = { -1, -1, -1, -1, -1 } },
    balanced = { label = "Balanced", vals = { 80, 60, 40, 40, 60 } },
    raid = { label = "Most FPS in raids", vals = { 60, 30, 30, 20, 45 } },
  }
  function PF.SetPBLook(key)
    local l = PF.PBLOOKS[key]
    if not l or not PF.HasPB() then return end
    pcall(SetCVar, "PB_Enabled", "1")
    for i, e in ipairs(PF.PB) do pcall(SetCVar, e.cvar, tostring(l.vals[i])) end
  end
  function PF.PBLook()
    for k, l in pairs(PF.PBLOOKS) do
      local same = true
      for i, e in ipairs(PF.PB) do if tonumber(CVar(e.cvar)) ~= l.vals[i] then same = false end end
      if same then return k end
    end
  end

  -- ---------------------------------------------------------------- events
  local f = CreateFrame("Frame", "pfOctoPerf")
  PF.frame = f
  for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do f:RegisterEvent(e) end
  local cleanAt, fxAt, sampleAt = nil, nil, 0
  local function Wake() f:SetScript("OnUpdate", PF.Tick) end
  function PF.Tick()
    local now = Now()
    if cleanAt and now >= cleanAt then
      cleanAt = nil
      if not (UnitAffectingCombat and UnitAffectingCombat("player")) then PF.Clean(PF.why or "after the fight") end
    end
    if fxAt and now >= fxAt then fxAt = nil PF.ApplyFX() end
    if now >= sampleAt then sampleAt = now + 2 PF.Sample() end
    -- nothing waiting and no page reading the numbers: stop ticking
    if PF.watching and not (PF.watchFrame and PF.watchFrame.IsVisible and PF.watchFrame:IsVisible()) then PF.watching = false end
    if not cleanAt and not fxAt and not PF.watching then f:SetScript("OnUpdate", nil) end
  end
  f:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then
      cleanAt = nil
      PF.Hold()
    elseif event == "PLAYER_REGEN_ENABLED" then
      if On("gc") and On("gcafter") and PF.held then cleanAt, PF.why = Now() + 2, "after the fight" Wake() end
    elseif event == "PLAYER_ENTERING_WORLD" then
      if not PF.since then
        PF.since = Now()
        -- (first world entry) ClassicAPI animations at the monitor's rate; Linux CVars kept as picked
        PF.ApplyAnim()
        if On("linux") then PF.ApplyLinux(true) end
      end
      if On("gcload") then cleanAt, PF.why = Now() + 1, "after a loading screen" end
      fxAt = Now() + 1
      Wake()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      fxAt = Now() + 1
      Wake()
    end
  end)
  function PF.Watch(on, frame) PF.watching, PF.watchFrame = on, frame if on then Wake() end end
  -- the memory ceiling: a look once a second (ClassicAPI's timer when there, else a throttled OnUpdate)
  local steer = CreateFrame("Frame", "pfOctoPerfSteer")
  PF.steer = steer
  local lc = pfUI.api.libclient
  if lc and lc.Every then
    lc.Every(steer, 1, function() PF.Steer() end)
  else
    steer:SetScript("OnUpdate", function()
      if (this.at or 0) > Now() then return end
      this.at = Now() + 1
      PF.Steer()
    end)
  end

  -- ------------------------------------------------------------ raid stress test (26 Nov 2026)
  -- User: "a stress test ... 40 characters and a boss ... all casting spells all classes same as a raid" after a raider's
  -- 1 FPS that stopped when OctoDoTs was switched off. PF.Stress(seconds): the Demo's raid (40 pretend players, a boss,
  -- casts, heals, damage on the frames and meters), 40 pretend mobs on OctoDoTs with 14 debuffs each and 200 aura
  -- changes a second (what a real 40-man pull gives it), and a frame-time recorder. At the end: FPS, worst frames,
  -- memory, and how long OctoDoTs' passes took - said in chat and kept in PF.stressLast.
  PF.STRESS_MOBS, PF.STRESS_EVENTS = 40, 800
  local function Ms() return debugprofilestop and debugprofilestop() or (Now() * 1000) end
  -- the pretend mobs' GUIDs in order (slot 1 = the boss); a dying add gets a NEW GUID, as in a raid
  PF.stressGuids, PF.stressNext = {}, 0
  local function NewMob(D, slot)
    PF.stressNext = PF.stressNext + 1
    local g = string.format("0xF13000STRESS%05d", PF.stressNext)
    D.units[g] = { guid = g, added = Now(), seen = Now(), auras = {}, na = 0, stress = true,
      stressName = slot == 1 and PF.StressBossName() or PF.StressAddName(), stressMark = slot <= 8 and slot or nil }
    D.n = (D.n or 0) + 1
    PF.stressGuids[slot] = g
    return g
  end
  function PF.StressMobs(on)
    local D = pfUI.dots
    if not (D and D.units) then return 0 end
    local n = 0
    if on then
      for i = 1, PF.STRESS_MOBS do NewMob(D, i) n = n + 1 end
    else
      for g, u in pairs(D.units) do if u.stress then D.Remove(g) n = n + 1 end end
      PF.stressGuids = {}
    end
    D.dirty = true
    return n
  end
  -- an add died: gone from OctoDoTs, a new one in its slot
  function PF.StressChurn(slot)
    local D = pfUI.dots
    if not (D and D.units) or slot < 2 then return end
    local old = PF.stressGuids[slot]
    if old and D.units[old] then D.Remove(old) end
    NewMob(D, slot)
    D.dirty = true
  end

  -- ------------------------------------------------------------ the combat log feed (26 Nov 2026)
  -- User, after the stage: "it is just on the UI not stress in game" - add-on code cannot put anything into the world,
  -- but what made the raider's 1 FPS was add-on DATA piling up. So the test feeds a raid's combat log to every add-on:
  -- the game's own templates (GlobalStrings), hundreds of lines a second - your and the raid's spell hits and crits,
  -- Frost Novas on the adds, melee, heals, debuffs going on, DoT ticks, the boss hitting the raid, adds dying (new
  -- ones come with new GUIDs) - handed to each frame that listens for that event (ClassicAPI frame:IsEventRegistered),
  -- with the event and arg1 set as the game does. Chat windows are left out (they would print all of it).
  -- Add-ons that save fights (WhoDidIt, meters) record this pretend fight too.
  PF.STRESS_LINES = 400
  PF.STRESS_NAMES = { "Yara", "Delia", "Isolde", "Torvald", "Xander", "Cedric", "Hesper", "Mirelle", "Wren", "Briar",
    "Gideon", "Lucan", "Varek", "Ansel", "Faye", "Kestra", "Zorik", "Emrys", "Joren", "Nessa", "Sable", "Magnus", "Rowan",
    "Quill", "Kael", "Pella", "Ulric", "Orin", "Nyx", "Lira", "Thane", "Brenna", "Corin", "Dagny", "Elric", "Fen", "Garrick",
    "Hale", "Ilsa", "Jory" }
  PF.STRESS_NUKES = { { "Frostbolt", "Frost" }, { "Fireball", "Fire" }, { "Frost Nova", "Frost" }, { "Arcane Explosion", "Arcane" },
    { "Shadow Bolt", "Shadow" }, { "Mind Blast", "Shadow" }, { "Lightning Bolt", "Nature" }, { "Chain Lightning", "Nature" },
    { "Starfire", "Arcane" }, { "Moonfire", "Arcane" }, { "Hellfire", "Fire" }, { "Rain of Fire", "Fire" }, { "Blizzard", "Frost" },
    { "Flamestrike", "Fire" }, { "Consecration", "Holy" }, { "Holy Nova", "Holy" }, { "Cone of Cold", "Frost" } }
  PF.STRESS_HEALS = { "Flash Heal", "Greater Heal", "Healing Wave", "Chain Heal", "Healing Touch", "Rejuvenation", "Holy Light",
    "Flash of Light", "Renew", "Prayer of Healing" }
  PF.STRESS_DEBUFFS = { { "Corruption", "Shadow" }, { "Curse of Agony", "Shadow" }, { "Shadow Word: Pain", "Shadow" },
    { "Immolate", "Fire" }, { "Serpent Sting", "Nature" }, { "Moonfire", "Arcane" }, { "Frost Nova", nil }, { "Sunder Armor", nil },
    { "Faerie Fire", nil }, { "Hunter's Mark", nil }, { "Winter's Chill", nil }, { "Scorch", nil } }
  PF.STRESS_EVENTS_FED = { "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_PARTY_DAMAGE", "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
    "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_COMBAT_PARTY_HITS", "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF", "CHAT_MSG_SPELL_PARTY_BUFF", "CHAT_MSG_SPELL_SELF_BUFF",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
    "CHAT_MSG_COMBAT_HOSTILE_DEATH", "UNIT_CASTEVENT", "UNIT_AURA", "UNIT_HEALTH", "UNIT_MANA" }
  -- a listener's name for the report: its own (or a parent's) name, else the file and line of its event handler
  -- (unnamed frames all read "Frame" otherwise)
  function PF.StressFrameName(f)
    local l = PF.Label(f)
    if l ~= "Frame" and not string.find(l, "^Frame$") then return l end
    local ok, h = pcall(f.GetScript, f, "OnEvent")
    local info = ok and h and debug and debug.getinfo and debug.getinfo(h)
    local src = info and info.source
    if type(src) == "string" then
      local _, _, add, file = string.find(src, "AddOns[\\/]([^\\/]+)[\\/](.-)$")
      if add then return add .. " " .. file .. ":" .. (info.linedefined or "?") end
      return src .. ":" .. (info.linedefined or "?")
    end
    return l
  end
  -- the n listeners that took the most time: "name 12.3% (4.1 ms/s), ..."
  function PF.StressTop(by, sum, n)
    local list = {}
    for k, ms in pairs(by or {}) do table.insert(list, { k, ms }) end
    if table.getn(list) == 0 then return nil end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local out, secs = {}, (sum or 0) / 1000
    for i = 1, math.min(n or 5, table.getn(list)) do
      local pct = (sum or 0) > 0 and list[i][2] / sum * 100 or 0
      table.insert(out, list[i][1] .. " " .. string.format("%.1f", pct) .. "%"
        .. (secs > 0 and (" (" .. string.format("%.1f", list[i][2] / secs) .. " ms/s)") or ""))
    end
    return table.concat(out, ", ")
  end
  function PF.StressBossName()
    local n = _G.UnitExists and _G.UnitExists("target") and not (_G.UnitIsPlayer and _G.UnitIsPlayer("target")) and (_G.UnitName("target"))
    return n or "Onyxia"
  end
  function PF.StressAddName() return PF.stressAdd or "Onyxian Whelp" end
  local function T(key, fallback) local v = rawget(_G, key) return type(v) == "string" and v or fallback end
  -- every frame that listens for each event, chat windows left out -> { event = { frames } }, frames counted
  function PF.StressListeners()
    local out, seen, n = {}, {}, 0
    local ef = rawget(_G, "EnumerateFrames")
    if type(ef) ~= "function" then return out, 0 end
    local f = ef()
    local guard = 0
    while f and guard < 200000 do
      guard = guard + 1
      local ok, has = pcall(function() return f.IsEventRegistered end)
      if ok and has and f.GetScript then
        local name = f.GetName and f:GetName()
        local chat = type(name) == "string" and (string.find(name, "^ChatFrame%d") or string.find(name, "^pfStress"))
        local okh, handler = pcall(f.GetScript, f, "OnEvent")
        if not chat and okh and handler then
          for _, e in ipairs(PF.STRESS_EVENTS_FED) do
            local okr, r = pcall(f.IsEventRegistered, f, e)
            if okr and r then
              out[e] = out[e] or {}
              table.insert(out[e], { f = f, h = handler, key = PF.StressFrameName(f) })
              if not seen[f] then seen[f] = true n = n + 1 end
            end
          end
        end
      end
      f = ef(f)
    end
    return out, n
  end
  -- hand one event to its listeners as the game would (this / event / arg1-4 set, put back after)
  local ARGS = { "this", "event", "arg1", "arg2", "arg3", "arg4" }
  function PF.StressSend(s, e, a1, a2, a3, a4)
    local list = s.listeners and s.listeners[e]
    s.lines = s.lines + 1
    if not list then return end
    local keep = {}
    for i, k in ipairs(ARGS) do keep[i] = rawget(_G, k) end
    _G.event, _G.arg1, _G.arg2, _G.arg3, _G.arg4 = e, a1, a2, a3, a4
    for _, l in ipairs(list) do
      _G.this = l.f
      local t0 = Ms()
      if not pcall(l.h) then s.errors = s.errors + 1 end
      -- (26 Nov 2026: the HUD put all of it on the driver) each listener's own share
      s.byFrame[l.key] = (s.byFrame[l.key] or 0) + (Ms() - t0)
    end
    for i, k in ipairs(ARGS) do _G[k] = keep[i] end
  end
  -- one random raid line
  function PF.StressLine(s)
    local names, me = PF.STRESS_NAMES, (_G.UnitName and (_G.UnitName("player"))) or "You"
    local who = names[math.random(1, table.getn(names))]
    local boss, add = PF.StressBossName(), PF.StressAddName()
    local mob = math.random() < .35 and boss or add
    local r = math.random()
    local nuke = PF.STRESS_NUKES[math.random(1, table.getn(PF.STRESS_NUKES))]
    local amt = math.random(250, 2400)
    local fmt = string.format
    if r < .10 then
      PF.StressSend(s, "CHAT_MSG_SPELL_SELF_DAMAGE", fmt(T("SPELLLOGSCHOOLSELFOTHER", "Your %s hits %s for %d %s damage."), nuke[1], mob, amt, nuke[2]))
    elseif r < .40 then
      local e = math.random() < .2 and "CHAT_MSG_SPELL_PARTY_DAMAGE" or "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE"
      local crit = math.random() < .25
      PF.StressSend(s, e, fmt(T(crit and "SPELLLOGCRITSCHOOLOTHEROTHER" or "SPELLLOGSCHOOLOTHEROTHER",
        crit and "%s's %s crits %s for %d %s damage." or "%s's %s hits %s for %d %s damage."), who, nuke[1], mob, crit and amt * 2 or amt, nuke[2]))
    elseif r < .55 then
      PF.StressSend(s, math.random() < .2 and "CHAT_MSG_COMBAT_PARTY_HITS" or "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS",
        fmt(T("COMBATHITOTHEROTHER", "%s hits %s for %d."), who, mob, math.random(300, 1400)))
    elseif r < .72 then
      local crit = math.random() < .2
      PF.StressSend(s, math.random() < .2 and "CHAT_MSG_SPELL_PARTY_BUFF" or "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
        fmt(T(crit and "HEALEDCRITOTHEROTHER" or "HEALEDOTHEROTHER", crit and "%s's %s critically heals %s for %d." or "%s's %s heals %s for %d."),
        who, PF.STRESS_HEALS[math.random(1, table.getn(PF.STRESS_HEALS))], names[math.random(1, table.getn(names))], math.random(400, 3200)))
    elseif r < .80 then
      local d = PF.STRESS_DEBUFFS[math.random(1, table.getn(PF.STRESS_DEBUFFS))]
      PF.StressSend(s, "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", fmt(T("AURAADDEDOTHERHARMFUL", "%s is afflicted by %s."), mob, d[1]))
    elseif r < .90 then
      local d = PF.STRESS_DEBUFFS[math.random(1, 6)]
      PF.StressSend(s, "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", fmt(T("PERIODICAURADAMAGEOTHEROTHER", "%s suffers %d %s damage from %s's %s."),
        mob, math.random(120, 600), d[2] or "Shadow", who, d[1]))
    elseif r < .96 then
      local tgt = names[math.random(1, table.getn(names))]
      PF.StressSend(s, "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE", fmt(T("SPELLLOGSCHOOLOTHEROTHER", "%s's %s hits %s for %d %s damage."),
        boss, math.random() < .5 and "Fire Nova" or "Flame Breath", tgt, math.random(600, 3500), "Fire"))
    else
      -- an add dies; a new one takes its place (new GUID on OctoDoTs)
      PF.StressSend(s, "CHAT_MSG_COMBAT_HOSTILE_DEATH", fmt(T("UNITDIESOTHER", "%s dies."), add))
      PF.StressChurn(math.random(2, PF.STRESS_MOBS))
      s.deaths = s.deaths + 1
    end
    -- SuperWoW-style casts on the pretend mobs (OctoDoTs and others follow these by GUID)
    if s.listeners and s.listeners.UNIT_CASTEVENT and math.random() < .3 then
      local g = PF.stressGuids[math.random(1, PF.STRESS_MOBS)]
      PF.StressSend(s, "UNIT_CASTEVENT", "0xF14000000000" .. math.random(10, 49), g, "CAST", 25295)
    end
  end
  function PF.StressFeed(s, dt)
    s.lineAcc = s.lineAcc + PF.STRESS_LINES * dt / 1000
    local n = 0
    while s.lineAcc >= 1 and n < 200 do
      s.lineAcc = s.lineAcc - 1
      n = n + 1
      PF.StressLine(s)
    end
    if s.lineAcc > 50 then s.lineAcc = 50 end
    -- (26 Nov 2026, user: "make sure octo rinse is in the test ... make it all run") the raid's units changing: debuffs
    -- going on and off, health and mana moving on raid1-40 - what OctoRinse, the raid frames, heal prediction and the
    -- other unit watchers do most of their work on. The Demo's raid answers for those units while it runs.
    s.unitAcc = (s.unitAcc or 0) + PF.STRESS_UNITS * dt / 1000
    n = 0
    while s.unitAcc >= 1 and n < 200 do
      s.unitAcc = s.unitAcc - 1
      n = n + 1
      local r, u = math.random(), "raid" .. math.random(1, 40)
      if r < .45 then PF.StressSend(s, "UNIT_AURA", u)
      elseif r < .85 then PF.StressSend(s, "UNIT_HEALTH", u)
      else PF.StressSend(s, "UNIT_MANA", u) end
    end
    if s.unitAcc > 50 then s.unitAcc = 50 end
  end
  PF.STRESS_UNITS = 600
  -- (26 Nov 2026, user: "emulate players and spells casting") the picture side of a raid, on a full-screen stage under
  -- the interface (BACKGROUND), nothing in the world.
  -- (26 Nov 2026, seen in game: bare race models drew white, a Ragnaros model a white box and spell model files
  -- black squares - only a real unit gets its skins, so every character is a copy of a unit) Then, user: "HIGH
  -- STRESS ... spells and adds whelps getting novad and aoe going off". So:
  --   raid     40 copies of you in your gear (DressUpModel), two rings, casting moves
  --   boss     a big copy of your target when you have one (any mob: its own skin), in the middle
  --   adds     30 small copies of your target (or of you), walking in, blown away by the boss's nova, back again
  --   AoE      the game's own spell textures (fire rings, runes, danger zones, glows, lightning) as additive
  --            pictures: Fire Nova rings from the boss, Flamestrikes / Blizzards / Consecrations / shadow runes on the
  --            ground, heal glows on players, bolts flying in - up to PF.STRESS_AOE at once
  --   fight    the Demo raid runs at 3x speed (more damage, heals, combat text, meter and frame updates)
  PF.STRESS_CAST = { 51, 52, 53, 54, 0 } -- ready / cast directed / cast omni sequences, then stand (unknown ids just stand)
  PF.STRESS_ADDS, PF.STRESS_AOE = 50, 250
  local SP = "Spells\\"
  -- texture, size, r, g, b, kind (ground | ring | glow | bolt)
  PF.STRESS_FX = {
    nova   = { SP .. "FireRing128", 1, 1, .45, .1, "ring" },
    fnova  = { SP .. "Ice_Rune_128", 1, .5, .85, 1, "ring2" },
    fs     = { SP .. "Fire_Rune_128", 170, 1, .5, .15, "ground" },
    fire   = { SP .. "DangerAreaFlame", 210, 1, .55, .2, "ground" },
    bliz   = { SP .. "Ice_Rune_128", 190, .45, .75, 1, "ground" },
    frost  = { SP .. "DangerAreaFrost", 200, .5, .8, 1, "ground" },
    cons   = { SP .. "Holy_Rune_128", 160, 1, .9, .4, "ground" },
    shadow = { SP .. "DemonRune6", 170, .7, .3, 1, "ground" },
    heal   = { SP .. "GENERICGLOW64", 90, .3, 1, .4, "glow" },
    holy   = { SP .. "GlowStar_Yellow", 80, 1, .95, .6, "glow" },
    puff   = { SP .. "FIRE1A", 110, 1, .6, .2, "glow" },
    bolt   = { SP .. "GENERICGLOW2_64_BLUE", 46, .6, .8, 1, "bolt" },
    fball  = { SP .. "FIRE1A", 50, 1, .6, .2, "bolt" },
    zap    = { SP .. "Lightning2", 120, .7, .8, 1, "glow" },
  }
  PF.STRESS_GROUND = { "fs", "fire", "bliz", "frost", "cons", "shadow" }
  local function Seq(m, id) if m.SetSequence then pcall(m.SetSequence, m, id) end end
  local function Unit(m, unit) if m.SetUnit then pcall(m.SetUnit, m, unit) end end
  local function Rnd(a) return (math.random() * 2 - 1) * a end
  function PF.StressStage(on)
    local st = PF.stage
    if not on then
      if st then
        st:Hide()
        for _, m in ipairs(st.models) do if m.ClearModel then pcall(m.ClearModel, m) end end
        for _, m in ipairs(st.adds) do if m.ClearModel then pcall(m.ClearModel, m) end end
        if st.boss.ClearModel then pcall(st.boss.ClearModel, st.boss) end
      end
      return 0
    end
    if not st then
      st = CreateFrame("Frame", "pfStressStage", UIParent)
      PF.stage = st
      st:SetFrameStrata("BACKGROUND")
      st:SetAllPoints(UIParent)
      st.models, st.adds, st.fx = {}, {}, {}
      st.boss = CreateFrame("PlayerModel", nil, st)
      st.boss:SetWidth(420)
      st.boss:SetHeight(420)
      for i = 1, 40 do
        local m = CreateFrame("DressUpModel", nil, st)
        m:SetWidth(130)
        m:SetHeight(170)
        table.insert(st.models, m)
      end
      for i = 1, PF.STRESS_ADDS do
        local m = CreateFrame("PlayerModel", nil, st)
        m:SetWidth(80)
        m:SetHeight(80)
        table.insert(st.adds, m)
      end
      -- the AoE pictures: on a frame above the characters
      st.fxLayer = CreateFrame("Frame", nil, st)
      st.fxLayer:SetAllPoints(st)
      st.fxLayer:SetFrameLevel(st:GetFrameLevel() + 6)
      for i = 1, PF.STRESS_AOE do
        local t = st.fxLayer:CreateTexture(nil, "ARTWORK")
        t:SetBlendMode("ADD")
        t:Hide()
        table.insert(st.fx, t)
      end
    end
    local w, h = UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768
    st.w, st.h = w, h
    -- the boss: your target, when there is one that is not a player
    local boss = _G.UnitExists and _G.UnitExists("target") and not (_G.UnitIsPlayer and _G.UnitIsPlayer("target"))
    st.hasBoss = boss and true or nil
    st.boss:ClearAllPoints()
    st.boss:SetPoint("CENTER", st, "CENTER", 0, 30)
    if boss then Unit(st.boss, "target") st.boss:Show() else st.boss:Hide() end
    for i, m in ipairs(st.models) do
      local k = i - 1
      local ring = k < 22 and 1 or 2
      local slot = ring == 1 and k or (k - 22)
      local count = ring == 1 and 22 or 18
      local ang = (slot / count) * 2 * math.pi
      local rx, ry = (ring == 1 and .30 or .44) * w, (ring == 1 and .28 or .40) * h
      m.x, m.y = math.cos(ang) * rx, math.sin(ang) * ry
      m:ClearAllPoints()
      m:SetPoint("CENTER", st, "CENTER", m.x, m.y)
      Unit(m, "player")
      if m.SetFacing then pcall(m.SetFacing, m, math.mod(ang + math.pi * 1.5, 2 * math.pi)) end
      m.castAt = Now() + math.random() * 2
      m:Show()
    end
    for _, m in ipairs(st.adds) do
      Unit(m, boss and "target" or "player")
      if not boss and m.SetModelScale then pcall(m.SetModelScale, m, .6) end
      PF.StressAddSpawn(m, Now())
      m:Show()
    end
    for _, t in ipairs(st.fx) do t.untilT = 0 t:Hide() end
    st.novaAt = Now() + 4
    st:Show()
    return 40 + PF.STRESS_ADDS + (boss and 1 or 0)
  end
  -- an add starts at the edge and walks to the boss
  function PF.StressAddSpawn(m, now)
    local st = PF.stage
    local a = math.random() * 2 * math.pi
    m.fx, m.fy = math.cos(a) * st.w * .55, math.sin(a) * st.h * .55
    m.tx, m.ty = math.cos(a) * st.w * .12, math.sin(a) * st.h * .12
    m.px, m.py = m.fx, m.fy
    m.born, m.walk, m.dead = now, 3 + math.random() * 3, nil
    m:SetAlpha(1)
  end
  -- one AoE picture: kind, centre x / y (from the screen's middle), how long, where a bolt flies to
  function PF.StressFx(key, x, y, life, x2, y2)
    local st = PF.stage
    local d = PF.STRESS_FX[key]
    if not (st and d) then return end
    for _, t in ipairs(st.fx) do
      if not t:IsShown() then
        t:SetTexture(d[1])
        t:SetVertexColor(d[3], d[4], d[5], 1)
        t.kind, t.size, t.x, t.y, t.x2, t.y2 = d[6], d[2], x, y, x2 or x, y2 or y
        t.born, t.untilT = Now(), Now() + (life or 1.5)
        t:Show()
        PF.StressFxDraw(t, t.born)
        return t
      end
    end
  end
  function PF.StressFxDraw(t, now)
    local st = PF.stage
    local life = t.untilT - t.born
    local p = life > 0 and (now - t.born) / life or 1
    if p > 1 then p = 1 end
    local x, y, size, a = t.x, t.y, t.size, 1
    if t.kind == "ring" then
      size = 80 + p * math.max(st.w, st.h) * 1.1      -- the nova grows out over the screen
      a = 1 - p
    elseif t.kind == "ring2" then
      size = 40 + p * 320                              -- a Frost Nova round a raider
      a = 1 - p
    elseif t.kind == "ground" then
      size = t.size * (.8 + .2 * math.sin(now * 6))   -- burning on the floor
      a = p < .15 and p / .15 or (1 - p) * 1.2
    elseif t.kind == "bolt" then
      x, y = t.x + (t.x2 - t.x) * p, t.y + (t.y2 - t.y) * p
    else
      size = t.size * (1 + p * .6)
      a = 1 - p
    end
    if a > 1 then a = 1 elseif a < 0 then a = 0 end
    t:ClearAllPoints()
    t:SetPoint("CENTER", st, "CENTER", x, y)
    t:SetWidth(size)
    t:SetHeight(size)
    t:SetAlpha(a)
  end
  -- every frame while the test runs
  function PF.StressStageTick(now)
    local st = PF.stage
    if not (st and st:IsShown()) then return end
    local bx, by = 0, 30
    -- the raid casts: bolts into the boss, ground AoE on the adds, heals on each other
    for _, m in ipairs(st.models) do
      if now >= (m.castAt or 0) then
        m.castAt = now + .8 + math.random() * 1.4
        Seq(m, PF.STRESS_CAST[math.random(1, table.getn(PF.STRESS_CAST))])
        local r = math.random()
        if r < .45 then
          PF.StressFx(math.random() < .5 and "bolt" or "fball", m.x, m.y, .7, bx + Rnd(60), by + Rnd(60))
        elseif r < .75 then
          local g = PF.STRESS_GROUND[math.random(1, table.getn(PF.STRESS_GROUND))]
          PF.StressFx(g, Rnd(.3 * st.w), Rnd(.3 * st.h), 3 + math.random() * 3)
        elseif r < .90 then
          local o = st.models[math.random(1, table.getn(st.models))]
          PF.StressFx(math.random() < .5 and "heal" or "holy", o.x, o.y + 30, 1)
        elseif r < .97 then
          PF.StressFx("zap", bx + Rnd(80), by + Rnd(80), .4)
        else
          -- a mage's Frost Nova: the adds near them freeze (blue) for 2 s
          PF.StressFx("fnova", m.x, m.y, .7)
          for _, a in ipairs(st.adds) do
            if not a.dead and a.px and math.abs(a.px - m.x) < 160 and math.abs(a.py - m.y) < 160 then a.frozen = now + 2 end
          end
        end
      end
    end
    -- adds walk in; the boss's Fire Nova every 6 s blows them all away
    for _, m in ipairs(st.adds) do
      if m.dead then
        if now >= m.dead then PF.StressAddSpawn(m, now) end
      elseif m.frozen and now < m.frozen then
        -- (held by a Frost Nova: the walk waits)
        m.born = m.born + (now - (m.lastT or now))
      else
        local p = (now - m.born) / m.walk
        if p > 1 then p = 1 end
        m.px, m.py = m.fx + (m.tx - m.fx) * p, m.fy + (m.ty - m.fy) * p
        m:ClearAllPoints()
        m:SetPoint("CENTER", st, "CENTER", m.px, m.py)
      end
      m.lastT = now
    end
    if now >= (st.novaAt or 0) then
      st.novaAt = now + 6
      PF.StressFx("nova", bx, by, 1.4)
      PF.StressFx("nova", bx, by, 1.8)
      for _, m in ipairs(st.adds) do
        if not m.dead then
          m.dead = now + 1 + math.random() * 2
          m:SetAlpha(.15)
          PF.StressFx("puff", m.px or 0, m.py or 0, .8)
        end
      end
    end
    for _, t in ipairs(st.fx) do
      if t:IsShown() then
        if now >= t.untilT then t:Hide() else PF.StressFxDraw(t, now) end
      end
    end
  end

  -- OctoDoTs' pass and paint timed while the test runs
  local function Wrap(t, key, rec)
    local f = t[key]
    if type(f) ~= "function" then return nil end
    t[key] = function(a, b, c)
      local s = Ms()
      local r1, r2 = f(a, b, c)
      rec.ms, rec.n = rec.ms + (Ms() - s), rec.n + 1
      return r1, r2
    end
    return f
  end
  function PF.Stress(seconds)
    if PF.stress then PF.StressStop("stopped by hand") return end
    -- "/pfstress 120 lite": no characters or spell effects on screen
    local lite = type(seconds) == "string" and string.find(seconds, "lite") and true or nil
    if type(seconds) == "string" then local _, _, n = string.find(seconds, "(%d+)") seconds = n end
    if _G.UnitAffectingCombat and _G.UnitAffectingCombat("player") then Say("the stress test waits until you are out of the fight.") return end
    seconds = math.max(10, math.min(600, tonumber(seconds) or 60))
    local S = { untilT = Now() + seconds, secs = seconds, warmUntil = Now() + 3, warmWorst = 0, frames = 0, sum = 0, worst = 0, over50 = 0, over100 = 0,
      secFrames = 0, secStart = Now(), lowest = nil, kb0 = gcinfo(), peak = gcinfo(), cleans = 0,
      scan = { ms = 0, n = 0 }, paint = { ms = 0, n = 0 }, rinse = { ms = 0, n = 0 }, evAcc = 0, byFrame = {} }
    PF.stress = S
    -- the Demo's raid fight, when the Demo is there
    local DM = pfUI.demo
    if DM and DM.Start and not DM.on then S.demo = DM.Start("raid") end
    -- (the fight at 3x: more hits, heals, combat text, meter and frame work every second)
    if S.demo and DM.speed then DM.speed = 3 end
    S.mobs = PF.StressMobs(true)
    S.lines, S.errors, S.deaths, S.lineAcc = 0, 0, 0, 0
    S.listeners, S.lframes = PF.StressListeners()
    S.models = not lite and PF.StressStage(true) or 0
    local D = pfUI.dots
    if D then
      S.origScan = Wrap(D, "Scan", S.scan)
      S.origPaint = Wrap(D, "Paint", S.paint)
    end
    -- OctoRinse: its rows up for the whole test, its scans timed
    local R = pfUI.rinse
    if R then
      if R.Test then pcall(R.Test, seconds) end
      S.origRinse = Wrap(R, "Scan", S.rinse)
    end
    local f = PF.stressFrame or CreateFrame("Frame", "pfStressTestDriver")
    PF.stressFrame = f
    local last = Ms()
    f:SetScript("OnUpdate", function()
      local s = PF.stress
      if not s then this:Hide() return end
      local now, ms = Now(), Ms()
      local dt = ms - last
      last = ms
      -- (26 Nov 2026, first run in game: "lowest second 1, worst frame 1217 ms" was the 3 s start - loading 70 models -
      -- not the fight) the start is noted on its own and left out of the numbers
      if now < s.warmUntil then
        if dt > s.warmWorst and dt < 30000 then s.warmWorst = dt end
        s.secFrames, s.secStart = 0, now
      elseif s.frames > 0 or dt < 1000 then
        s.frames, s.sum = s.frames + 1, s.sum + dt
        if dt > s.worst then s.worst = dt end
        if dt > 50 then s.over50 = s.over50 + 1 end
        if dt > 100 then s.over100 = s.over100 + 1 end
      end
      s.secFrames = s.secFrames + 1
      if now - s.secStart >= 1 then
        local fps = s.secFrames / (now - s.secStart)
        if not s.lowest or fps < s.lowest then s.lowest = fps end
        s.secFrames, s.secStart = 0, now
      end
      local kb = gcinfo()
      if kb > s.peak then s.peak = kb end
      if s.lastKb and kb < s.lastKb - 4096 then s.cleans = s.cleans + 1 end
      s.lastKb = kb
      -- the raid's aura changes on the pretend mobs, through OctoDoTs' own event script
      local ev = D and D.auraEvents and D.auraEvents:GetScript("OnEvent")
      if ev then
        s.evAcc = s.evAcc + PF.STRESS_EVENTS * math.max(dt, (now - (s.lastNow or now)) * 1000) / 1000
        if s.evAcc > 400 then s.evAcc = 400 end
        local keep = _G.arg1
        while s.evAcc >= 1 do
          s.evAcc = s.evAcc - 1
          _G.arg1 = PF.stressGuids[math.random(1, PF.STRESS_MOBS)]
          ev()
        end
        _G.arg1 = keep
      end
      -- the raid's combat log, to every add-on that listens
      -- (game time, not the frame clock: so a long frame sends its whole share)
      local gdt = (now - (s.lastNow or now)) * 1000
      s.lastNow = now
      if s.lframes > 0 then PF.StressFeed(s, gdt) end
      if s.models > 0 then PF.StressStageTick(now) end
      if now >= s.untilT then PF.StressStop() end
    end)
    f:Show()
    Say("stress test started (" .. seconds .. " s): " .. (S.demo and "the 40-player raid demo at 3x, " or "")
      .. PF.STRESS_LINES .. " combat log lines a second to " .. S.lframes .. " add-on frames"
      .. (S.lframes == 0 and " (needs ClassicAPI)" or "") .. ", " .. S.mobs .. " mobs on OctoDoTs (" .. PF.STRESS_EVENTS
      .. " aura changes a second, adds dying and coming back)"
      .. (S.models > 0 and (", " .. S.models .. " characters, adds and AoE on screen (target a mob first: it becomes the boss)") or "")
      .. ". /pfstress again stops it.")
  end
  function PF.StressStop(why)
    local s = PF.stress
    if not s then return end
    PF.stress = nil
    local D = pfUI.dots
    if D then
      if s.origScan then D.Scan = s.origScan end
      if s.origPaint then D.Paint = s.origPaint end
    end
    local R = pfUI.rinse
    if R and s.origRinse then R.Scan = s.origRinse end
    PF.StressMobs(false)
    PF.StressStage(false)
    local DM = pfUI.demo
    if s.demo and DM and DM.Stop then DM.Stop(true) end
    local avg = s.frames > 0 and s.sum / s.frames or 0
    local r = {
      why = why or "done", secs = s.secs, frames = s.frames, models = s.models,
      fps = avg > 0 and 1000 / avg or 0, lowest = s.lowest or 0, worst = s.worst, over50 = s.over50, over100 = s.over100,
      mb0 = s.kb0 / 1024, mb1 = gcinfo() / 1024, peak = s.peak / 1024, cleans = s.cleans,
      scanN = s.scan.n, scanMs = s.scan.n > 0 and s.scan.ms / s.scan.n or 0,
      paintN = s.paint.n, paintMs = s.paint.n > 0 and s.paint.ms / s.paint.n or 0,
      share = s.sum > 0 and (s.scan.ms + s.paint.ms) / s.sum * 100 or 0,
      rinseN = s.rinse.n, rinseMs = s.rinse.n > 0 and s.rinse.ms / s.rinse.n or 0,
      rinseShare = s.sum > 0 and s.rinse.ms / s.sum * 100 or 0,
      top = PF.StressTop(s.byFrame, s.sum, 5),
      lines = s.lines, lframes = s.lframes, errors = s.errors, deaths = s.deaths,
      warm = s.warmWorst,
    }
    PF.stressLast = r
    for _, l in ipairs(PF.StressLines(r)) do DEFAULT_CHAT_FRAME:AddMessage(l) end
  end
  function PF.StressLines(r)
    local function F(x, d) return string.format("%." .. (d or 0) .. "f", x or 0) end
    local good = r.lowest >= 30 and r.over100 <= 3
    return {
      "|cff33ccffpfUI Octo|r stress test (" .. r.why .. ", " .. F(r.secs) .. " s" .. ((r.models or 0) > 0 and (", " .. r.models .. " characters on screen") or "") .. "): " .. (good and "|cff55ff55smooth|r" or "|cffff5555stutters|r"),
      "  FPS: |cffffffff" .. F(r.fps) .. "|r on average, lowest second |cffffffff" .. F(r.lowest) .. "|r; worst frame |cffffffff"
        .. F(r.worst) .. " ms|r, " .. r.over50 .. " frames over 50 ms, " .. r.over100 .. " over 100 ms"
        .. ((r.warm or 0) > 0 and ("; the start (loading everything, left out) " .. F(r.warm) .. " ms") or ""),
      "  Lua memory: " .. F(r.mb0) .. " -> " .. F(r.mb1) .. " MB (peak " .. F(r.peak) .. "), " .. r.cleans .. " clean-ups",
      "  OctoDoTs: " .. r.scanN .. " passes at " .. F(r.scanMs, 2) .. " ms, " .. r.paintN .. " paints at " .. F(r.paintMs, 2)
        .. " ms = " .. F(r.share, 1) .. "% of the frame time",
      "  OctoRinse: " .. (r.rinseN or 0) .. " scans at " .. F(r.rinseMs, 2) .. " ms = " .. F(r.rinseShare, 1) .. "% of the frame time",
      "  Busiest with the raid traffic: " .. (r.top or "(nothing timed)"),
      "  Combat log fed: " .. (r.lines or 0) .. " lines to " .. (r.lframes or 0) .. " add-on frames, " .. (r.deaths or 0)
        .. " adds died and came back" .. ((r.errors or 0) > 0 and (", |cffff5555" .. r.errors .. " add-on errors|r") or ""),
    }
  end
  _G.SLASH_PFSTRESS1 = "/pfstress"
  _G.SlashCmdList.PFSTRESS = function(msg) PF.Stress(msg) end

  -- /pfperf [on|off|reset|clean]
  _G.SLASH_PFPERF1 = "/pfperf"
  _G.SlashCmdList.PFPERF = function(msg)
    msg = string.lower(msg or "")
    if msg == "on" then PF.SetProfiling(true) return end
    if msg == "off" then PF.SetProfiling(false) return end
    if msg == "reset" then PF.Reset() Say("numbers reset.") return end
    if msg == "clean" then PF.Clean("by hand") Say("memory cleaned: " .. (PF.last and PF.last.freed or 0) .. " KB freed.") return end
    if not PF.CanMeasure() then Say("measuring needs ClassicAPI.") return end
    if not PF.profiling then Say("measuring is off - /pfperf on (reloads), play a while, then /pfperf.") return end
    for _, l in ipairs(PF.Lines(PF.Measure(), 8)) do DEFAULT_CHAT_FRAME:AddMessage(l) end
  end
end)
