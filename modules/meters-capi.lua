pfUI:RegisterModule("meters-capi", "vanilla", function ()
  -- pfUI Octo :: ClassicAPI's damage meter as a source for our meter windows (18 Nov 2026; user: ClassicAPI "has
  -- updated ... apparently it has new damage meters", then "Yes, build it"). ClassicAPI 1.22 (brues-code) counts the
  -- group's damage, healing, interrupts, dispels, damage taken, deaths and damage to enemies inside the DLL and gives
  -- them to addons through C_DamageMeter (docs/API.md "DamageMeter"), one session per fight, a boss fight always its
  -- own session named after the boss. With it, the windows showing the current fight or Overall take those totals
  -- straight from the DLL: no Lua adding up of the raid's numbers for what they show, and the DLL's DAMAGE_METER_*
  -- events redraw them only when something changed. Everything else stays ours: earlier fights, the breakdown,
  -- buff uptime, threat, resources, and every display ClassicAPI does not count. The rows keep our own actor, so a
  -- click still opens our breakdown.
  --
  -- The DLL counts nothing while the per-character cvar damageMeterEnabled is 0; we switch it on. That also loads
  -- ClassicAPI's own meter window (ClassicAPI_DamageMeter, frame DamageMeter): it is set Hidden unless you want it
  -- too (C.meters.capiwindow). Its visibility is its own saved setting, changed through the window's mixin.
  -- Without ClassicAPI 1.22, or with C.meters.capi = "0", nothing here runs.
  local M = pfUI.meters
  if not M or not M.Rows then return end
  local CA = {}
  M.capi = CA

  -- defaults (kept here: no other file to touch)
  -- (18 Nov 2026: OFF until you switch it on. Switching ClassicAPI's meter on (cvar damageMeterEnabled) loads its own
  -- meter window and textures, and on the user's PC the game then crashed while loading (ERROR #132 in d3d9.dll's
  -- texture copy, called from ClassicAPI). 1.1.66 switched it on for everyone: put back to off once.)
  if C.meters.capireset ~= "1" then
    C.meters.capireset = "1"
    C.meters.capi = "0"
  end
  if C.meters.capi == nil then C.meters.capi = "0" end
  if C.meters.capiwindow == nil then C.meters.capiwindow = "0" end

  function CA.Available()
    local dm, enum = _G.C_DamageMeter, _G.Enum
    if not (dm and dm.GetCombatSessionFromType and enum and enum.DamageMeterType and enum.DamageMeterSessionType) then return end
    if dm.IsDamageMeterAvailable then
      local ok, yes = pcall(dm.IsDamageMeterAvailable)
      if ok and not yes then return end
    end
    return true
  end
  function CA.On()
    return C.meters.capi == "1" and CA.Available() and CA.enabled and true or nil
  end

  -- our display -> ClassicAPI's Enum.DamageMeterType name
  CA.TYPES = { damage = "DamageDone", dps = "Dps", heal = "HealingDone", hps = "Hps", interrupts = "Interrupts",
               dispels = "Dispels", taken = "DamageTaken", deaths = "Deaths", enemytaken = "EnemyDamageTaken" }
  -- our segment -> ClassicAPI's session type (earlier fights are ours: the two cut fights differently)
  CA.SESSIONS = { current = "Current", overall = "Overall" }

  local function Session(segkey, modekey)
    local enum = _G.Enum
    local tname, sname = CA.TYPES[modekey], CA.SESSIONS[segkey or ""]
    if not tname or not sname then return end
    local t, s = enum.DamageMeterType[tname], enum.DamageMeterSessionType[sname]
    if t == nil or s == nil then return end
    local ok, session = pcall(_G.C_DamageMeter.GetCombatSessionFromType, s, t)
    if ok and type(session) == "table" then return session end
  end
  CA.Session = Session

  -- the rows a window shows, from the DLL (nil = use ours)
  local Num = function(v) return M.Num and M.Num(v) or tostring(math.floor(v + .5)) end
  function CA.Rows(modekey, segkey)
    if not CA.On() then return end
    -- the test fight / test bars show our made-up numbers
    if M.testOn or (M.testUntil or 0) > GetTime() then return end
    local session = Session(segkey, modekey or "damage")
    if not session then return end
    local seg = M.Segment(segkey)
    local rows = {}
    for _, src in ipairs(session.combatSources or {}) do
      local v = tonumber(src.totalAmount) or 0
      local name = src.name
      if name and v > 0 then
        local isFoe = modekey == "enemytaken"
        local r = { name = name, value = v, class = (src.classFilename ~= "" and src.classFilename) or nil, capi = src }
        if seg then
          if isFoe then
            local f = seg.foes and seg.foes[name]
            if f then r.foe, r.tlist = f, f.from end
          else
            r.actor = seg.actors and seg.actors[name]
          end
        end
        if modekey == "damage" or modekey == "heal" then r.extra = Num(tonumber(src.amountPerSecond) or 0)
        elseif modekey == "dps" or modekey == "hps" then
          -- per second shown big, the total small (as ours)
          r.value = tonumber(src.amountPerSecond) or 0
          r.extra = Num(v)
        end
        if r.value > 0 then table.insert(rows, r) end
      end
    end
    table.sort(rows, function(x, y) return x.value > y.value end)
    local mode
    for _, m in ipairs(M.MODES or {}) do if m.key == modekey then mode = m end end
    local total = 0
    for _, r in ipairs(rows) do total = total + r.value end
    for _, r in ipairs(rows) do
      r.max = rows[1].value
      r.text = (mode and mode.text) and mode.text(r.value) or Num(r.value)
      r.pct = total > 0 and r.value / total * 100 or 0
    end
    return rows
  end

  -- every window asks M.Rows: the DLL answers first where it counts that display
  local ownRows = M.Rows
  M.OwnRows = ownRows
  M.Rows = function(modekey, segkey)
    local r = CA.Rows(modekey, segkey)
    if r then return r end
    return ownRows(modekey, segkey)
  end

  -- one source's spells from the DLL: { { spellID, name, total, perSecond, overkill } } (for the tooltip / check)
  function CA.Spells(segkey, modekey, src)
    if not (CA.On() and src) then return end
    local enum = _G.Enum
    local t, s = enum.DamageMeterType[CA.TYPES[modekey] or ""], enum.DamageMeterSessionType[CA.SESSIONS[segkey or ""] or ""]
    if t == nil or s == nil then return end
    local ok, one = pcall(_G.C_DamageMeter.GetCombatSessionSourceFromType, s, t, src.sourceGUID, src.sourceCreatureID)
    if not ok or type(one) ~= "table" then return end
    local out = {}
    for _, sp in ipairs(one.combatSpells or {}) do
      local name = sp.spellID and _G.SpellInfo and _G.SpellInfo(sp.spellID)
      if not name and sp.spellID and _G.GetSpellInfo then name = _G.GetSpellInfo(sp.spellID) end
      table.insert(out, { id = sp.spellID, name = name or ("Spell " .. tostring(sp.spellID)), total = sp.totalAmount or 0,
                          ps = sp.amountPerSecond or 0, overkill = sp.overkillAmount or 0, creature = sp.creatureName })
    end
    return out
  end

  -- ---------------------------------------------------------------- the cvar and ClassicAPI's own window

  function CA.CVar()
    local get = _G.GetCVar
    local ok, v = pcall(get, "damageMeterEnabled")
    return ok and v or nil
  end
  -- ClassicAPI's window shows when its meter is the one picked at the top (C.meters.mode = "capi") or when asked for
  -- beside ours (C.meters.capiwindow); else Hidden. Its own "When it shows" choice is kept while it is in use.
  function CA.WindowWanted() return C.meters.mode == "capi" or C.meters.capiwindow == "1" end
  function CA.ApplyWindow()
    local dm, enum = _G.DamageMeter, _G.Enum
    if not (dm and dm.OnSystemSettingChange and enum and enum.DamageMeterVisibility and _G.DamageMeterSystemSetting) then return end
    local key = _G.DamageMeterSystemSetting.Visibility
    local cur = dm.GetSettingValue and dm:GetSettingValue(key)
    local want
    if CA.WindowWanted() then
      if cur == enum.DamageMeterVisibility.Hidden then want = tonumber(C.meters.capivis) or enum.DamageMeterVisibility.Always end
    else
      if cur ~= enum.DamageMeterVisibility.Hidden then
        C.meters.capivis = tostring(cur or enum.DamageMeterVisibility.Always)
        want = enum.DamageMeterVisibility.Hidden
      end
    end
    if want ~= nil then pcall(dm.OnSystemSettingChange, dm, key, want) end
    if dm.UpdateShownState then pcall(dm.UpdateShownState, dm) end
  end
  -- counting is needed for our numbers (C.meters.capi) or for its own window
  local function Counting() return C.meters.capi == "1" or C.meters.mode == "capi" end
  function CA.Apply()
    CA.enabled = nil
    if not CA.Available() then return end
    if Counting() then
      if CA.CVar() ~= "1" then
        pcall(_G.SetCVar, "damageMeterEnabled", "1")
        C.meters.capicvar = "1"
      end
      CA.enabled = CA.CVar() == "1" and C.meters.capi == "1"
      CA.Load()
      CA.ApplyWindow()
    elseif C.meters.capicvar == "1" or C.meters.capireset == "1" and C.meters.capicvar == nil and CA.CVar() == "1" then
      -- switched off: ClassicAPI's meter goes off again if we were the ones who switched it on
      -- (1.1.66 switched it on without marking it: the first time after that, off as well)
      pcall(_G.SetCVar, "damageMeterEnabled", "0")
      C.meters.capicvar = "0"
    end
    -- its window follows the choice whichever way (shown for "ClassicAPI", hidden otherwise)
    CA.ApplyWindow()
    M.Changed()
  end

  -- its window's addon (load on demand: the client loads it when the cvar goes on; asked here too)
  function CA.Load()
    if _G.DamageMeter then return true end
    local load = (_G.C_AddOns and _G.C_AddOns.LoadAddOn) or _G.LoadAddOn
    if load then pcall(load, "ClassicAPI_DamageMeter") end
    return _G.DamageMeter and true or nil
  end
  function CA.CVarGet(name)
    local ok, v = pcall(_G.GetCVar, name)
    return ok and v or nil
  end
  function CA.CVarSet(name, v) pcall(_G.SetCVar, name, v) end
  -- one of its window settings (DamageMeterSystemSetting key, e.g. "BarHeight"); nil when it is not loaded
  function CA.Get(key)
    local dm, set = _G.DamageMeter, _G.DamageMeterSystemSetting
    if not (dm and dm.GetSettingValue and set and set[key]) then return end
    local ok, v = pcall(dm.GetSettingValue, dm, set[key])
    if ok then return v end
  end
  function CA.Set(key, v)
    if v == nil or not CA.Load() then return end
    local dm, set = _G.DamageMeter, _G.DamageMeterSystemSetting
    if not (dm.OnSystemSettingChange and set and set[key]) then return end
    pcall(dm.OnSystemSettingChange, dm, set[key], v)
    if key == "Visibility" then
      local enum = _G.Enum
      if enum and enum.DamageMeterVisibility and v ~= enum.DamageMeterVisibility.Hidden then C.meters.capivis = tostring(v) end
      if dm.UpdateShownState then pcall(dm.UpdateShownState, dm) end
    end
  end
  function CA.Unlock()
    if not CA.Load() then return end
    local dm = _G.DamageMeter
    local w = dm.GetPrimarySessionWindow and dm:GetPrimarySessionWindow()
    if not (w and dm.SetSessionWindowLocked) then return end
    CA.unlocked = not CA.unlocked
    pcall(dm.SetSessionWindowLocked, dm, w, not CA.unlocked)
  end
  function CA.NewWindow()
    if not CA.Load() then return end
    local dm = _G.DamageMeter
    if dm.CanShowNewSecondarySessionWindow and not dm:CanShowNewSecondarySessionWindow() then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo meters|r: ClassicAPI's meter has as many windows as it allows.")
      return
    end
    if dm.ShowNewSecondarySessionWindow then pcall(dm.ShowNewSecondarySessionWindow, dm) end
  end
  function CA.ResetAll()
    if M.Reset then M.Reset() end
    if _G.C_DamageMeter and _G.C_DamageMeter.ResetAllCombatSessions then pcall(_G.C_DamageMeter.ResetAllCombatSessions) end
  end

  -- ---------------------------------------------------------------- pfUI Octo / ClassicAPI / Blizzard at the top
  -- (18 Nov 2026) the Meters section's strip: "ClassicAPI" = our windows away (as "Blizzard" does: the game has no
  -- meter), ClassicAPI's window shown, its counting on, and the Windows page becomes its page. "pfUI Octo" or
  -- "Blizzard" turn it off again. The choice is kept (C.meters.mode).
  function CA.Rebuild()
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Rebuild then pcall(O.Rebuild, O, "mtwindows") end
  end
  function CA.Pick(on)
    local BZ = pfUI.blizz
    if on then
      C.meters.mode = "capi"
      if BZ and BZ.Set then BZ.Set("meters", "blizz") end
    else
      C.meters.mode = "octo"
    end
    CA.Apply()
    CA.Rebuild()
  end
  local BZ = pfUI.blizz
  if BZ and BZ.S and BZ.S.meters then
    BZ.S.meters.third = {
      label = "ClassicAPI",
      tip = "ClassicAPI's own meter window (ClassicAPI 1.22 and newer) instead of ours. Its settings take the Windows page.",
      shown = function() return CA.Available() end,
      on = function() return C.meters.mode == "capi" end,
      pick = function() CA.Pick(true) end,
      off = function() CA.Pick(false) end,
    }
  end

  -- ---------------------------------------------------------------- telling people once
  -- (18 Nov 2026, user: "Make people who download the new version be told this is an option") one chat line per
  -- character the first time they log in with ClassicAPI 1.22, pointing at the strip; a click on it opens the page.
  function CA.Tell()
    if C.meters.capitold == "1" or not CA.Available() then return end
    C.meters.capitold = "1"
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: your ClassicAPI has its own damage meter now. Pick |cffffd24dpfUI Octo|r, "
      .. "|cffffd24dClassicAPI|r or |cffffd24dBlizzard|r at the top of |cffffd24d/pfui > Meters|r, or keep ours and let it feed "
      .. "our windows (Meters > Data).")
  end

  -- our Reset clears the DLL's sessions too, so Overall means the same in both
  local ownReset = M.Reset
  M.Reset = function()
    ownReset()
    if CA.On() and _G.C_DamageMeter.ResetAllCombatSessions then pcall(_G.C_DamageMeter.ResetAllCombatSessions) end
  end

  -- the status line on the Data page
  function CA.Status()
    if not _G.C_DamageMeter then return "|cff8a8f99ClassicAPI 1.22 or newer is not installed - the meters count it all themselves.|r" end
    if C.meters.capi ~= "1" then return "|cffffd24dSwitched off - the meters count it all themselves.|r" end
    if not CA.enabled then return "|cffff6060ClassicAPI's meter is off (cvar damageMeterEnabled) - could not switch it on.|r" end
    local s = Session("current", "damage")
    local n = s and s.combatSources and table.getn(s.combatSources) or 0
    return "|cff40d977In use|r: current fight and Overall come from ClassicAPI (" .. n .. " in the current fight)."
  end

  -- /pfmeter check: our totals against the DLL's for the current fight
  function CA.Check(segkey)
    segkey = segkey or "current"
    local out = {}
    if not CA.On() then
      table.insert(out, "ClassicAPI's meter is not in use: " .. string.gsub(CA.Status(), "|c%x%x%x%x%x%x%x%x", ""))
      return out
    end
    for _, mk in ipairs({ "damage", "heal", "taken", "interrupts", "dispels", "deaths" }) do
      local dll, own = 0, 0
      local s = Session(segkey, mk)
      for _, src in ipairs(s and s.combatSources or {}) do dll = dll + (tonumber(src.totalAmount) or 0) end
      for _, r in ipairs(ownRows(mk, segkey)) do own = own + (r.value or 0) end
      local diff = dll > 0 and math.floor((own - dll) / dll * 1000 + .5) / 10 or 0
      table.insert(out, string.format("%s: ours %s, ClassicAPI %s (%s%s%%)", mk, Num(own), Num(dll), diff >= 0 and "+" or "", diff))
    end
    return out
  end
  _G.SLASH_PFMETERCHECK1 = "/pfmetercheck"
  _G.SlashCmdList["PFMETERCHECK"] = function(msg)
    local seg = (msg == "overall") and "overall" or "current"
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo meters|r: " .. seg .. " - ours vs ClassicAPI")
    for _, l in ipairs(CA.Check(seg)) do DEFAULT_CHAT_FRAME:AddMessage("  " .. l) end
  end

  -- ---------------------------------------------------------------- events

  local f = CreateFrame("Frame", "pfMeterCapi", UIParent)
  CA.frame = f
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("ADDON_LOADED")
  if _G.C_EventUtils and _G.C_EventUtils.IsEventValid then
    for _, e in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET" }) do
      local ok, valid = pcall(_G.C_EventUtils.IsEventValid, e)
      if ok and valid then f:RegisterEvent(e) end
    end
  end
  f:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      CA.Apply()
      CA.Tell()
    elseif event == "ADDON_LOADED" then
      if arg1 == "ClassicAPI_DamageMeter" then CA.ApplyWindow() end
    elseif CA.On() then
      -- DAMAGE_METER_*: the windows redraw on their next tick
      M.Changed()
    end
  end)
end)
