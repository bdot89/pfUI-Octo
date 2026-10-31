pfUI:RegisterModule("gear-events", "vanilla", function ()
  -- pfUI Octo :: gear sets, phase 3 - automatic swaps (24 Oct 2026; ItemRack's
  -- "events", written fresh). Each event can wear a set while it lasts and put
  -- back what was worn before when it ends: mounted, swimming, stealthed,
  -- each stance / form, resting (city or inn), battleground, dungeon, raid,
  -- flight path, combat. The first one on the list that is happening wins.
  -- Swaps go through GR's queue, so armour waits for combat to end, and
  -- everything waits while dead or casting (gear.lua, GR.Blocked).
  --
  -- Uses ClassicAPI / SuperWoW where they help (user's standing wish):
  -- IsMounted, IsSwimming, IsStealthed. Without them: mounted = a buff whose
  -- tooltip says "Increases speed"; stealthed = the Stealth / Prowl form;
  -- swimming is not offered.
  local GR = pfUI.gear
  if not GR then return end
  local GE = { state = {} }
  GR.events = GE

  if type(C.gear.events) ~= "table" then C.gear.events = {} end
  local function Cfg(key)
    local e = C.gear.events[key]
    if type(e) ~= "table" then e = { on = "0", set = "", back = "1" } C.gear.events[key] = e end
    return e
  end
  GE.Cfg = Cfg

  local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r gear: " .. msg) end

  -- ---------------------------------------------------------------- what is happening

  local scan
  local function BuffSays(text)
    if not GetPlayerBuff then return false end
    if not scan then
      scan = CreateFrame("GameTooltip", "pfGearEventScan", nil, "GameTooltipTemplate")
    end
    for i = 0, 31 do
      local id = GetPlayerBuff(i, "HELPFUL")
      if not id or id < 0 then break end
      scan:SetOwner(WorldFrame, "ANCHOR_NONE")
      scan:ClearLines()
      scan:SetPlayerBuff(id)
      for l = 2, 4 do
        local fs = getglobal("pfGearEventScanTextLeft" .. l)
        local t = fs and fs:GetText()
        if t and string.find(t, text, 1, true) then scan:Hide() return true end
      end
    end
    if scan then scan:Hide() end
    return false
  end

  local function Mounted()
    if IsMounted then
      local ok, m = pcall(IsMounted)
      if ok then return m and true or false end
    end
    return BuffSays("Increases speed")
  end

  local function ActiveForm()
    local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i = 1, n do
      local _, name, active = GetShapeshiftFormInfo(i)
      if active then return i, name end
    end
  end

  local function Stealthed()
    if IsStealthed then
      local ok, s = pcall(IsStealthed)
      if ok then return s and true or false end
    end
    local _, name = ActiveForm()
    return name == "Stealth" or name == "Prowl"
  end

  local function InBattleground()
    if not GetBattlefieldStatus then return false end
    for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
      local status = GetBattlefieldStatus(i)
      if status == "active" then return true end
    end
    return false
  end

  local function Instance(kind)
    if not IsInInstance then return false end
    local inside, itype = IsInInstance()
    if not inside or InBattleground() then return false end
    if itype == "raid" or itype == "party" then return itype == kind end
    -- (a client that gives no type: a raid group means a raid)
    local raid = GetNumRaidMembers and GetNumRaidMembers() > 0
    return (kind == "raid") == (raid and true or false)
  end

  -- the events, in the order they win; form events are added per character
  GE.LIST = {
    { key = "mount", label = "Mounted", test = Mounted },
    { key = "taxi", label = "On a flight path",
      test = function() return UnitOnTaxi and UnitOnTaxi("player") and true or false end },
    { key = "swim", label = "Swimming", needs = function() return IsSwimming ~= nil end,
      test = function() local ok, s = pcall(IsSwimming) return ok and s and true or false end },
    { key = "stealth", label = "Stealthed", test = Stealthed },
    { key = "bg", label = "In a battleground", test = InBattleground },
    { key = "raid", label = "In a raid", test = function() return Instance("raid") end },
    { key = "dungeon", label = "In a dungeon", test = function() return Instance("party") end },
    { key = "rest", label = "Resting (city or inn)",
      test = function() return IsResting and IsResting() and true or false end },
    { key = "combat", label = "In combat (weapons swap at once, armour after)",
      test = function() return UnitAffectingCombat("player") and true or false end },
  }

  -- this character's stances / forms as events (Battle Stance, Bear Form...)
  function GE.Forms()
    local out = {}
    local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i = 1, n do
      local tex, name = GetShapeshiftFormInfo(i)
      if name then
        local idx = i
        table.insert(out, { key = "form:" .. name, label = name, tex = tex, form = true,
          test = function() local a = ActiveForm() return a == idx end })
      end
    end
    return out
  end

  -- every event this character can have, in order: forms right after stealth
  function GE.All()
    local out = {}
    for _, e in ipairs(GE.LIST) do
      if not e.needs or e.needs() then table.insert(out, e) end
      if e.key == "stealth" then
        for _, f in ipairs(GE.Forms()) do table.insert(out, f) end
      end
    end
    return out
  end

  -- the event that should be worn now: { key, set } or nil
  function GE.Want()
    if C.gear.autoswap == "0" then return nil end
    for _, e in ipairs(GE.All()) do
      local c = C.gear.events[e.key]
      if type(c) == "table" and c.on == "1" and c.set ~= "" and C.gear.sets[c.set] then
        local ok, yes = pcall(e.test)
        if ok and yes then return e, c end
      end
    end
  end

  -- ---------------------------------------------------------------- swapping

  -- what to put back: the gear worn before the first event's set went on,
  -- widened to the slots of every event set worn since
  local function Remember(set)
    local st = GE.state
    st.base = st.base or {}
    local now = GR.Snapshot(set.slots)
    for k, v in pairs(now) do
      if st.base[k] == nil then st.base[k] = v end
    end
  end

  function GE.Check()
    local st = GE.state
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    local e, c = GE.Want()
    local key = e and e.key
    if key == st.active then return end
    if e then
      local set = C.gear.sets[c.set]
      if not st.active then st.before = C.gear.current end
      if c.back == "1" then Remember(set) end
      st.active, st.back = key, (c.back == "1") or st.back
      if not GR.IsEquipped(c.set) then
        if C.gear.autotell ~= "0" then Say(e.label .. ": wearing " .. c.set .. ".") end
        GR.Equip(c.set)
      end
    else
      -- the event ended: what was worn before, if it asked for that
      local was = st.active
      st.active = nil
      if st.back and st.base and next(st.base) then
        if C.gear.autotell ~= "0" then Say("back to what you wore before.") end
        GR.Wear(st.before or "Before", st.base)
        C.gear.current = st.before
      end
      st.base, st.back, st.before = nil, nil, nil
      GE.last = was
    end
  end

  local ticker = CreateFrame("Frame")
  ticker:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < .5 then return end
    this.t = 0
    if next(C.gear.events) then GE.Check() end
  end)
  -- (a change of form, zone or combat is looked at at once, not half a second later)
  for _, ev in ipairs({ "UPDATE_SHAPESHIFT_FORMS", "PLAYER_AURAS_CHANGED", "ZONE_CHANGED_NEW_AREA",
                        "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                        "UPDATE_BATTLEFIELD_STATUS", "PLAYER_UNGHOST", "PLAYER_ALIVE" }) do
    pcall(ticker.RegisterEvent, ticker, ev)
  end
  ticker:SetScript("OnEvent", function() if next(C.gear.events) then GE.Check() end end)

  -- ---------------------------------------------------------------- options page

  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end

  local function G() return C.gear end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key, GR.Changed) end

  local function SetList()
    local out = { { key = "", label = "- no set -" } }
    for _, n in ipairs(GR.Sets()) do table.insert(out, { key = n, label = n }) end
    return out
  end

  local function Build(p)
    W.Heading(p, "Automatic swaps", {
      on = { function() return C.gear.autoswap ~= "0" end, function(v) C.gear.autoswap = v and "1" or "0" end,
        "Every automatic swap on or off." },
      about = "Wear a set while something is happening - riding, swimming, in a stance or form, in a city, a "
        .. "battleground or a raid - and put back what you wore when it ends. The first one in the list that is "
        .. "happening wins. Armour waits for combat to end (weapons swap at once); everything waits while you are "
        .. "dead or casting." })
    -- (31 Oct 2026, user: menus "overwhelming": the events in four tabs)
    local GROUP = { mount = "travel", taxi = "travel", swim = "travel", stealth = "forms", bg = "places", raid = "places",
      dungeon = "places", rest = "places", combat = "combat" }
    local tabs = { travel = {}, forms = {}, places = {}, combat = { "Waiting" } }
    for _, e in ipairs(GE.All()) do table.insert(tabs[GROUP[e.key] or "forms"], e.label) end
    O.CardTabs(p, {
      { "travel", "Travel", "Ability_Mount_RidingHorse", tabs.travel },
      { "forms", "Stances and forms", "Ability_Warrior_DefensiveStance", tabs.forms },
      { "places", "Places", "INV_Misc_Map_01", tabs.places },
      { "combat", "Combat and waiting", "INV_Sword_04", tabs.combat },
    })
    W.Card(p, "Waiting", { tip = "When gear cannot change yet, the swap waits and goes on by itself." })
    Chk(p, "Wait while dead", "Swaps asked for while dead go on when you are alive again (off: they are refused).", "waitdead")
    Chk(p, "Wait while casting", "Swaps wait for your cast or channel to end, so they never cut it short.", "waitcast")
    Chk(p, "Weapons swap in combat", "1.12 lets weapons change in combat; armour always waits.", "combatweapons")
    Chk(p, "Say when a swap waits", nil, "tellwait")
    Chk(p, "Say each automatic swap", nil, "autotell")
    local list = GE.All()
    for _, e in ipairs(list) do
      local key, label = e.key, e.label
      W.Card(p, label, { folded = (Cfg(key).on ~= "1"),
        on = { function() return Cfg(key).on == "1" end, function(v) Cfg(key).on = v and "1" or "0" end,
          "Wear a set while: " .. label .. "." } })
      W.Dropdown(p, "Wear", "The set worn while this lasts.", SetList,
        function() return Cfg(key).set end, function(v) Cfg(key).set = v end)
      W.Check(p, "Put back after", "When it ends, wear again what you wore before.",
        function() return Cfg(key).back == "1" end, function(v) Cfg(key).back = v and "1" or "0" end)
    end
    if table.getn(GE.Forms()) == 0 then
      W.Note(p, "Stances and forms show up here on characters that have them.")
    end
    O.TabFilter(p)
  end
  O:AddPage("Gear", "gearevents", "Automatic swaps", Build)

  -- /gear events: what is happening and what would be worn
  local slash = SlashCmdList.PFGEAR
  SlashCmdList.PFGEAR = function(msg)
    if string.lower(msg or "") == "events" then
      for _, e in ipairs(GE.All()) do
        local ok, yes = pcall(e.test)
        local c = C.gear.events[e.key]
        DEFAULT_CHAT_FRAME:AddMessage("  " .. e.label .. ": " .. (ok and (yes and "|cff55ff55yes|r" or "no") or "?")
          .. ((type(c) == "table" and c.on == "1") and (" -> " .. (c.set ~= "" and c.set or "no set")) or ""))
      end
      return
    end
    slash(msg)
  end
end)
