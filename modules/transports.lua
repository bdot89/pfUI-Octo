pfUI:RegisterModule("transports", "vanilla", function ()
  -- pfUI Octo :: boats and zeppelins on the world map (15 Nov 2026; user:
  -- "live locations on our world map ... boats trams and zepplins").
  -- The client tells add-ons nothing about transports, so this works them out:
  --   routes    the game's own paths (transports-data.lua: TaxiPathNode.dbc),
  --             a stop of `delay` seconds at each dock, a map change = a jump
  --   speed     TR.SPEED yards a second until one is watched moving, then
  --             its own measured speed (kept per route)
  --   sync      ClassicAPI ClosestGameObjectPosition on the transport objects
  --             (TR.OBJECTS): one seen moving fixes where its route's loop
  --             starts. Sightings go to guild / group (prefix pfOctoTR), so one
  --             player at a dock puts everyone in step.
  -- Never seen: drawn faded and called a guess. Saved in pfUI_cache.transports
  -- (time() based, per PC). Switch: C.appearance.worldmap.transports.
  -- Trams (Deeprun Tram) run inside an instance with no world map: left out.
  local TR = {}
  pfUI.transports = TR
  local TRD = pfUI.transportData
  if not TRD then return end

  TR.SPEED = 30
  TR.PREFIX = "pfOctoTR"
  TR.OBJECTS = { 20808, 164871, 175080, 176495, 176231, 176244, 176310, 177233,
    176364, 181646, 190549, 190550, 190551, 190552, 190553, 190554 }
  local H, A, N = { 1, .35, .3 }, { .35, .6, 1 }, { 1, .82, .3 }
  -- route id = { kind, colour, dock names in the order the route reaches them }
  TR.INFO = {
    [72] = { "ship", N, { "Ratchet", "Booty Bay" } },
    [110] = { "zeppelin", H, { "Grom'gol", "Orgrimmar" } },
    [116] = { "ship", A, { "Menethil Harbor", "Theramore" } },
    [117] = { "ship", A, { "Rut'theran Village", "Auberdine" } },
    [118] = { "ship", A, { "Menethil Harbor", "Auberdine" } },
    [120] = { "zeppelin", H, { "Grom'gol", "Undercity" } },
    [121] = { "zeppelin", H, { "Orgrimmar", "Undercity" } },
    [122] = { "ship", A, { "Feathermoon Stronghold", "The Forgotten Coast", "Feathermoon Stronghold" } },
    [294] = { "ship", A, { "Stormwind Harbor", "Auberdine" } },
    [295] = { "zeppelin", H, { "Thunder Bluff", "Orgrimmar" } },
    [296] = { "ship", H, { "Sparkwater Port", "Revantusk Village" } },
    [297] = { "zeppelin", H, { "Kargath", "Orgrimmar" } },
    [323] = { "ship", N },
    [348] = { "ship", N },
  }
  local function Store()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.transports = pfUI_cache.transports or {}
    return pfUI_cache.transports
  end
  function TR.On()
    local w = C.appearance and C.appearance.worldmap
    return not w or w.transports ~= "0"
  end

  -- the area of the world a point lies in (smallest map box), for names
  local function Pretty(s)
    s = string.gsub(s, "(%l)(%u)", "%1 %2")
    return s
  end
  function TR.AreaAt(map, x, y)
    local best, size
    for _, a in ipairs(TRD.areas) do
      if a[2] == map and a[3] ~= a[4] and y <= a[3] and y >= a[4] and x <= a[5] and x >= a[6]
        and a[1] ~= "Kalimdor" and a[1] ~= "Azeroth" then
        local s = (a[3] - a[4]) * (a[5] - a[6])
        if not size or s < size then best, size = a[1], s end
      end
    end
    return best and Pretty(best) or "?"
  end

  -- routes: legs of { map, x1, y1, x2, y2, t1, t2 } and stops { t1, t2, dock }
  TR.routes = {}
  function TR.Build(id, speed)
    local p = TRD.paths[id]
    local info = TR.INFO[id] or { "ship", N }
    local n = math.floor(table.getn(p) / 6)
    local r = { id = id, legs = {}, stops = {}, docks = {}, kind = info[1], color = info[2] }
    speed = speed or TR.SPEED
    local t, len = 0, 0
    for i = 1, n do
      local b = (i - 1) * 6
      local m, x, y, fl, dl = p[b + 1], p[b + 2], p[b + 3], p[b + 5], p[b + 6]
      if fl == 2 and dl > 0 then
        local d = table.getn(r.stops) + 1
        local name = info[3] and info[3][d] or TR.AreaAt(m, x, y)
        table.insert(r.stops, { t1 = t, t2 = t + dl, dock = name, map = m, x = x, y = y })
        table.insert(r.docks, name)
        t = t + dl
      end
      local nb = (math.mod(i, n)) * 6
      local m2, x2, y2 = p[nb + 1], p[nb + 2], p[nb + 3]
      if m2 == m then
        local dist = math.sqrt((x2 - x) * (x2 - x) + (y2 - y) * (y2 - y))
        local dt = dist / speed
        table.insert(r.legs, { m, x, y, x2, y2, t, t + dt, len, len + dist })
        t, len = t + dt, len + dist
      end
    end
    r.period, r.length, r.speed = t, len, speed
    TR.routes[id] = r
    return r
  end
  function TR.BuildAll()
    local s = Store()
    for id in pairs(TRD.paths) do TR.Build(id, s[id] and s[id].speed) end
  end

  -- where a route is t seconds into its loop: map, x, y, moving, stop, dir
  function TR.At(r, t)
    t = math.mod(t, r.period)
    if t < 0 then t = t + r.period end
    for _, s in ipairs(r.stops) do
      if t >= s.t1 and t < s.t2 then return s.map, s.x, s.y, false, s end
    end
    for _, l in ipairs(r.legs) do
      if t >= l[6] and t < l[7] then
        local f = (t - l[6]) / math.max(l[7] - l[6], .001)
        return l[1], l[2] + (l[4] - l[2]) * f, l[3] + (l[5] - l[3]) * f, true, nil, l[5] - l[3]
      end
    end
    local l = r.legs[1]
    return l[1], l[2], l[3], false
  end
  -- the next stop after loop time t: stop, seconds until it
  function TR.Next(r, t)
    t = math.mod(t, r.period)
    if t < 0 then t = t + r.period end
    local best, wait
    for _, s in ipairs(r.stops) do
      local w = s.t1 - t
      if w <= 0 then w = w + r.period end
      if not wait or w < wait then best, wait = s, w end
    end
    return best, wait
  end
  -- the loop time on route r nearest to a seen point (within 40 yd), or nil
  function TR.Match(map, x, y)
    local bestR, bestT, bestD, bestLen
    for _, r in pairs(TR.routes) do
      for _, l in ipairs(r.legs) do
        if l[1] == map or map == nil then
          local vx, vy = l[4] - l[2], l[5] - l[3]
          local f = ((x - l[2]) * vx + (y - l[3]) * vy) / (vx * vx + vy * vy + .001)
          if f < 0 then f = 0 elseif f > 1 then f = 1 end
          local dx, dy = l[2] + vx * f - x, l[3] + vy * f - y
          local d = dx * dx + dy * dy
          if d < 1600 and (not bestD or d < bestD) then
            bestR, bestT, bestD, bestLen = r, l[6] + (l[7] - l[6]) * f, d, l[8] + (l[9] - l[8]) * f
          end
        end
      end
    end
    return bestR, bestT, bestLen
  end

  -- loop time now for a route: seconds, known (seen) or a guess
  function TR.Now(r, now)
    local s = Store()[r.id]
    now = now or time()
    if s and s.t0 then return now - s.t0, s end
    return now, nil
  end

  -- a sighting: route r was at loop time t at time() `at`
  function TR.Fix(r, t, at, from, age)
    local s = Store()
    s[r.id] = s[r.id] or {}
    local e = s[r.id]
    local seen = at - (age or 0)
    if e.seen and e.seen > seen + 1 then return false end
    e.t0, e.seen, e.from = at - t, seen, from
    return true
  end

  -- ------------------------------------------------------ watching in game
  local function Finder()
    if type(_G.ClosestGameObjectPosition) == "function" then return _G.ClosestGameObjectPosition end
    local c = _G.C_GameObjectInfo
    if type(c) == "table" and type(c.ClosestGameObjectPosition) == "function" then return c.ClosestGameObjectPosition end
  end
  local function Pos()
    if type(_G.UnitPosition) ~= "function" then return end
    local ok, x, y = pcall(_G.UnitPosition, "player")
    if ok and tonumber(x) and tonumber(y) then return tonumber(x), tonumber(y) end
  end
  TR.watch = {}
  -- one look at every transport object near you
  function TR.Look(now, clock)
    local find = Finder()
    if not find then return end
    local px, py = Pos()
    for _, oid in ipairs(TR.OBJECTS) do
      local ok, a, b = pcall(find, oid)
      a, b = tonumber(a), tonumber(b)
      if ok and a and b and (a ~= 0 or b ~= 0) then
        -- the call gives y, x (gather.lua); take whichever order lies nearer you
        local x, y = b, a
        if px and (px - a) * (px - a) + (py - b) * (py - b) < (px - x) * (px - x) + (py - y) * (py - y) then x, y = a, b end
        TR.Seen(oid, x, y, now, clock)
      end
    end
  end
  -- a transport seen at x, y: once it is seen moving, fix its route
  function TR.Seen(oid, x, y, now, clock)
    local w = TR.watch[oid]
    if not w or clock - w.clock > 6 then
      TR.watch[oid] = { x = x, y = y, clock = clock }
      return
    end
    local moved = (x - w.x) * (x - w.x) + (y - w.y) * (y - w.y)
    if moved < 1 then w.clock = clock return end
    local r, t, len = TR.Match(nil, x, y)
    if not r then return end
    -- speed from a watch of 8 s or more on the same route, no stop between
    if w.route == r.id and w.len and clock - w.start >= 8 then
      local sp = (len - w.len) / (clock - w.start)
      if sp > 5 and sp < 80 and math.abs(sp - r.speed) > .3 then
        local s = Store()
        s[r.id] = s[r.id] or {}
        s[r.id].speed = sp
        r = TR.Build(r.id, sp)
        r, t = TR.Match(nil, x, y)
        if not r then return end
      end
    elseif w.route ~= r.id or not w.len or len < w.len then
      w.route, w.len, w.start = r.id, len, clock
    end
    w.x, w.y, w.clock = x, y, clock
    if TR.Fix(r, t, now, nil, 0) then
      TR.dirty = true
      if not w.told or clock - w.told > 120 then
        w.told = clock
        TR.Tell(r.id)
      end
    end
  end

  -- ------------------------------------------------------ sharing
  local out, sendAt = {}, 0
  local function Channels()
    local list = {}
    if IsInGuild and IsInGuild() then table.insert(list, "GUILD") end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then table.insert(list, "RAID")
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then table.insert(list, "PARTY") end
    return list
  end
  -- "S|route|loop seconds now|age of the sighting|speed"
  function TR.Message(id, now)
    local r, e = TR.routes[id], Store()[id]
    if not r or not e or not e.t0 then return end
    now = now or time()
    return "S|" .. id .. "|" .. string.format("%.1f", math.mod(now - e.t0, r.period))
      .. "|" .. math.floor(now - (e.seen or now)) .. "|" .. string.format("%.2f", r.speed)
  end
  function TR.Tell(id)
    local m = TR.Message(id)
    if m and table.getn(out) < 40 then table.insert(out, m) end
  end
  function TR.Receive(msg, from, now)
    if not msg or not TR.On() then return end
    now = now or time()
    if msg == "Q" then
      if from == UnitName("player") then return end
      -- tell what we saw in the last 6 hours, after a short wait
      TR.replyAt = GetTime() + 2 + math.random() * 4
      return
    end
    local _, _, id, t, age, sp = string.find(msg, "^S|(%d+)|([%d%.]+)|(%d+)|([%d%.]+)$")
    id, t, age, sp = tonumber(id), tonumber(t), tonumber(age), tonumber(sp)
    if not id or not TR.routes[id] or age > 6 * 3600 or sp < 5 or sp > 80 then return end
    if from == UnitName("player") then return end
    local r = TR.routes[id]
    if math.abs(sp - r.speed) > .3 then
      local e = Store()[id]
      if not e or not e.speed then
        Store()[id] = e or {}
        Store()[id].speed = sp
        r = TR.Build(id, sp)
      end
    end
    if TR.Fix(r, t, now, from, age) then TR.dirty = true end
  end
  function TR.ShareTick(clock)
    if TR.replyAt and clock >= TR.replyAt then
      TR.replyAt = nil
      local now = time()
      for id, e in pairs(Store()) do
        if e.seen and now - e.seen < 6 * 3600 and not e.from then TR.Tell(id) end
      end
    end
    if out[1] and clock >= sendAt and type(SendAddonMessage) == "function" then
      sendAt = clock + 1
      local m = table.remove(out, 1)
      for _, chan in ipairs(Channels()) do pcall(SendAddonMessage, TR.PREFIX, m, chan) end
    end
  end

  -- ------------------------------------------------------ the world map
  local areaByName = {}
  for _, a in ipairs(TRD.areas) do
    if a[3] ~= a[4] and not areaByName[a[1]] then areaByName[a[1]] = a end
  end
  function TR.ShownArea()
    local name = GetMapInfo and GetMapInfo()
    if (not name or name == "") and GetCurrentMapZone and GetCurrentMapZone() == 0 then
      local c = GetCurrentMapContinent and GetCurrentMapContinent()
      name = c == 1 and "Kalimdor" or c == 2 and "Azeroth" or nil
    end
    return name and areaByName[name]
  end
  -- 0..1 spot on the shown map for a world point, or nil
  function TR.MapSpot(a, map, x, y)
    if not a or a[2] ~= map then return end
    local u = (a[3] - y) / (a[3] - a[4])
    local v = (a[5] - x) / (a[5] - a[6])
    if u < 0 or u > 1 or v < 0 or v > 1 then return end
    return u, v
  end
  local function Clock(s)
    s = math.max(0, math.floor(s + .5))
    return math.floor(s / 60) .. ":" .. string.format("%02d", math.mod(s, 60))
  end
  -- tooltip lines for a route right now
  function TR.Lines(r, now)
    now = now or time()
    local t, e = TR.Now(r, now)
    local _, _, _, moving, stop = TR.At(r, t)
    local lines = { table.concat(r.docks, " - ") }
    if stop then
      local left = stop.t2 - math.mod(t, r.period)
      if left < 0 then left = left + r.period end
      table.insert(lines, "At " .. stop.dock .. ", leaves in " .. Clock(left))
    else
      local nx, wait = TR.Next(r, t)
      if nx then table.insert(lines, "Next: " .. nx.dock .. " in " .. Clock(wait)) end
    end
    if e and e.seen then
      local ago = now - e.seen
      local when = ago < 120 and "just now" or ago < 7200 and (math.floor(ago / 60) .. " min ago") or (math.floor(ago / 3600) .. " h ago")
      table.insert(lines, "|cff999999Seen " .. when .. (e.from and (" by " .. e.from) or "") .. "|r")
    else
      table.insert(lines, "|cffff9933A guess: nobody has seen it yet.|r")
    end
    table.insert(lines, "|cff999999One trip round: " .. Clock(r.period) .. "|r")
    return lines
  end

  TR.pins = {}
  local layer
  local function Pin(i)
    if TR.pins[i] then return TR.pins[i] end
    local b = CreateFrame("Button", nil, layer)
    b:SetWidth(22) b:SetHeight(22)
    b.tex = b:CreateTexture(nil, "OVERLAY")
    b.tex:SetAllPoints(b)
    b:SetScript("OnEnter", function()
      local r = this.route
      if not r then return end
      local tip = _G.WorldMapTooltip or GameTooltip
      tip:SetOwner(this, "ANCHOR_RIGHT")
      local lines = TR.Lines(r)
      tip:AddLine(lines[1], r.color[1], r.color[2], r.color[3])
      for k = 2, table.getn(lines) do tip:AddLine(lines[k], 1, 1, 1) end
      tip:Show()
    end)
    b:SetScript("OnLeave", function() (_G.WorldMapTooltip or GameTooltip):Hide() end)
    TR.pins[i] = b
    return b
  end
  function TR.Draw()
    if not layer then return end
    local a = TR.On() and TR.ShownArea()
    local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
    local now, i = time(), 0
    if a then
      for _, r in pairs(TR.routes) do
        local t, e = TR.Now(r, now)
        local map, x, y, moving, stop, dir = TR.At(r, t)
        local u, v = TR.MapSpot(a, map, x, y)
        if u then
          i = i + 1
          local b = Pin(i)
          b.route = r
          b:ClearAllPoints()
          b:SetPoint("CENTER", layer, "TOPLEFT", u * w, -v * h)
          b.tex:SetTexture("Interface\\AddOns\\pfUI\\img\\transports\\" .. r.kind)
          -- the pictures face left; a route heading east (world y falling) flips them
          if dir and dir < 0 then b.tex:SetTexCoord(1, 0, 0, 1) else b.tex:SetTexCoord(0, 1, 0, 1) end
          b.tex:SetVertexColor(r.color[1], r.color[2], r.color[3])
          b:SetAlpha(e and 1 or .45)
          b:Show()
        end
      end
    end
    for k = i + 1, table.getn(TR.pins) do TR.pins[k]:Hide() end
  end

  TR.BuildAll()
  local f = CreateFrame("Frame", "pfTransports", UIParent)
  local lookAt, drawAt = 0, 0
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      if arg1 == TR.PREFIX then TR.Receive(arg2, arg4) end
    elseif not TR.asked then
      TR.asked = true
      table.insert(out, "Q")
    end
  end)
  f:SetScript("OnUpdate", function()
    local clock = GetTime()
    TR.ShareTick(clock)
    if not TR.On() then
      if layer and layer:IsShown() then layer:Hide() end
      return
    end
    if clock >= lookAt then
      lookAt = clock + 1
      TR.Look(time(), clock)
    end
    if WorldMapButton and WorldMapFrame and WorldMapFrame:IsShown() then
      if not layer then
        layer = CreateFrame("Frame", "pfTransportPins", WorldMapButton)
        layer:SetAllPoints(WorldMapButton)
        layer:SetFrameLevel(WorldMapButton:GetFrameLevel() + 3)
      end
      if not layer:IsShown() then layer:Show() end
      if clock >= drawAt or TR.dirty then
        drawAt, TR.dirty = clock + .2, nil
        TR.Draw()
      end
    end
  end)

  _G.SLASH_PFTRANSPORTS1 = "/transports"
  _G.SlashCmdList["PFTRANSPORTS"] = function(msg)
    local out2 = DEFAULT_CHAT_FRAME
    if (msg == "off" or msg == "on") and C.appearance.worldmap then
      C.appearance.worldmap.transports = msg == "on" and "1" or "0"
      out2:AddMessage("|cff33ffccpfUI|r boats and zeppelins on the map: " .. msg)
      return
    elseif msg == "forget" then
      pfUI_cache.transports = {}
      TR.BuildAll()
      out2:AddMessage("|cff33ffccpfUI|r transport sightings forgotten.")
      return
    end
    out2:AddMessage("|cff33ffccpfUI|r transports (/transports on | off | forget):"
      .. (Finder() and "" or " |cffff9933ClassicAPI missing: they can only be guessed or shared.|r"))
    for id, r in pairs(TR.routes) do
      local lines = TR.Lines(r)
      out2:AddMessage("  " .. lines[1] .. ": " .. (lines[2] or "") .. "  " .. (lines[3] or ""))
    end
  end
end)
