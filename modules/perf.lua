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
  function PF.Hold()
    if not On("gc") or not PF.CanGC() then return end
    local kb, th = gcinfo()
    local want = kb + Num("gcextra", 150) * 1024
    if not th or want > th then collectgarbage(want) end
    PF.held = true
  end
  function PF.Clean(why)
    if not PF.CanGC() then return end
    local before = gcinfo()
    local t0 = Now()
    collectgarbage()
    PF.held = false
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
      if not PF.since then PF.since = Now() end
      if On("gcload") then cleanAt, PF.why = Now() + 1, "after a loading screen" end
      fxAt = Now() + 1
      Wake()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      fxAt = Now() + 1
      Wake()
    end
  end)
  function PF.Watch(on, frame) PF.watching, PF.watchFrame = on, frame if on then Wake() end end

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
