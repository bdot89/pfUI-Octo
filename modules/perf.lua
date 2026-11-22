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
