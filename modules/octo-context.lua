pfUI:RegisterModule("octo-context", "vanilla", function ()
  -- pfUI Octo :: where you are, and the minimap hiding there by itself.
  -- (user, 24 Oct 2026: "if you enter a BG map can be turned off
  -- automatically, same for raids ... all the stuff on map should hide with
  -- it", and UI layouts that switch as you enter a battleground)
  --
  -- pfUI.context.Zone(): "bg", "arena", "raid", "dungeon" or "world";
  -- pfUI.context.listeners[name] = function(zone, old) runs when it changes
  -- (zone change, battleground status, group change), checked again every 2 s.
  local X = { listeners = {} }
  pfUI.context = X

  local function InBattleground()
    if not GetBattlefieldStatus then return false end
    for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
      if GetBattlefieldStatus(i) == "active" then return true end
    end
    return false
  end

  -- This server's arenas have an active battlefield and IsInInstance kind "pvp", never "arena" (92 logged
  -- matches, Chronicle ZONE_INFO), so only the zone name tells them from a battleground. On the way in the name
  -- is still the old zone for about half a second: that reads "bg" until a zone event or the 2 s poll asks again.
  X.ARENAS = { ["Blood Ring"] = true, ["Lordaeron Arena"] = true, ["Sunstrider Court"] = true }

  function X.Zone()
    local inside, kind
    if IsInInstance then inside, kind = IsInInstance() end
    local active = InBattleground()
    if kind == "arena" then return "arena" end
    if (active or kind == "pvp") and X.ARENAS[GetRealZoneText() or ""] then return "arena" end
    if active then return "bg" end
    if inside then
      if kind == "pvp" then return "bg" end
      if kind == "raid" then return "raid" end
      if kind == "party" then return "dungeon" end
      -- (a client that gives no kind: a raid group means a raid)
      return (GetNumRaidMembers and GetNumRaidMembers() > 0) and "raid" or "dungeon"
    end
    return "world"
  end
  X.NAMES = { bg = "Battleground", arena = "Arena", raid = "Raid", dungeon = "Dungeon", world = "Open world" }

  local function Check()
    local z = X.Zone()
    if z == X.zone then return end
    local old = X.zone
    X.zone = z
    for _, fn in pairs(X.listeners) do pcall(fn, z, old) end
  end
  X.Check = Check

  local ev = CreateFrame("Frame")
  X.ev = ev
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UPDATE_BATTLEFIELD_STATUS",
                       "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", Check)
  ev:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < 2 then return end
    this.t = 0
    Check()
  end)

  -- ---------------------------------------------------------------- the minimap hides itself

  -- C.mapauto[zone] = "1": the minimap and everything on it hide there
  if type(C.mapauto) ~= "table" then C.mapauto = {} end
  local map = pfUI.minimap

  -- the parts that do not sit inside the map frame (minimap-style's list)
  local function Outside()
    local out = {}
    for _, p in ipairs(map and map.PARTS or {}) do
      local f = p.get and p.get()
      if f and f.GetParent and f:GetParent() ~= map and f ~= map then table.insert(out, f) end
    end
    if pfUI.addonbuttons then table.insert(out, pfUI.addonbuttons) end
    return out
  end

  local function Apply()
    if not map then return end
    local hide = C.mapauto[X.zone or "world"] == "1"
    if hide then
      if map:IsShown() then map:Hide() end
      for _, f in ipairs(Outside()) do
        f:SetAlpha(0)
        if f.EnableMouse then f:EnableMouse(false) end
      end
      X.mapHidden = true
    elseif X.mapHidden then
      X.mapHidden = nil
      map:Show()
      for _, f in ipairs(Outside()) do
        f:SetAlpha(1)
        if f.EnableMouse then f:EnableMouse(true) end
      end
      -- (the map's own look puts hover / hidden buttons back as set)
      if map.ApplyStyle then pcall(map.ApplyStyle) end
    end
  end
  X.ApplyMap = Apply
  X.listeners.minimap = function(z, old)
    if C.mapauto[z] == "1" and C.mapauto.tell ~= "0" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: minimap hidden in " .. string.lower(X.NAMES[z] or z)
        .. " - Minimap options, \"Hide by itself\", to change it.")
    end
    Apply()
  end
  -- (something showing the map or a button again while it should be hidden)
  local keep = CreateFrame("Frame")
  keep:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < 1 then return end
    this.t = 0
    if X.mapHidden or (C.mapauto[X.zone or "world"] == "1") then Apply() end
  end)

  -- the Minimap page's card (minimap-options.lua calls this)
  function X.MapCard(p, W)
    W.Card(p, "Hide by itself", { tip = "The minimap and everything on it (zone name, clock, buttons, the bar "
      .. "under it) hide while you are in these places, and come back when you leave." })
    for _, z in ipairs({ "bg", "arena", "raid", "dungeon" }) do
      local zone = z
      W.Check(p, "In " .. string.lower(X.NAMES[zone]) .. "s", nil, function() return C.mapauto[zone] == "1" end,
        function(v) C.mapauto[zone] = v and "1" or "0" Apply() end)
    end
    W.Check(p, "Say so in chat", nil, function() return C.mapauto.tell ~= "0" end,
      function(v) C.mapauto.tell = v and "1" or "0" end)
  end

  -- (16 Nov 2026; user's screenshot of the small zone map popping up in
  -- Orgrimmar: "stop it ever happenign") The game's battle map
  -- (Blizzard_BattlefieldMinimap) opens by itself whenever its saved
  -- SHOW_BATTLEFIELD_MINIMAP is "1" and the server shows any world-state bar
  -- (WorldStateFrame_ToggleMinimap, patch-4). C.appearance.worldmap.nobattlemap
  -- = "1" keeps it shut: the saved flag stays "0" and any showing is undone.
  function X.BattleMapOff()
    return C.appearance.worldmap.nobattlemap == "1"
  end
  function X.ShutBattleMap()
    if not X.BattleMapOff() then return end
    _G.SHOW_BATTLEFIELD_MINIMAP = "0"
    local m = _G.BattlefieldMinimap
    if m and m:IsShown() then m:Hide() end
  end
  HookAddonOrVariable("Blizzard_BattlefieldMinimap", function()
    if not _G.BattlefieldMinimap then return end
    HookScript(_G.BattlefieldMinimap, "OnShow", function() X.ShutBattleMap() end)
    X.ShutBattleMap()
  end)
  local bm = CreateFrame("Frame")
  bm:RegisterEvent("PLAYER_ENTERING_WORLD")
  bm:RegisterEvent("UPDATE_WORLD_STATES")
  bm:SetScript("OnEvent", function() X.ShutBattleMap() end)
end)
