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
    e.t0, e.seen, e.from, e.docked = at - t, seen, from, nil
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
    if not (ok and tonumber(x) and tonumber(y)) then return end
    -- (15 Nov 2026, user's /transports probe at the Orgrimmar tower gave
    -- -4597, 1307 = the tower's y, x) this client's order is learnt: TR.Ride
    -- flips TR.swap when only the other order lies on a route
    if TR.swap then return tonumber(y), tonumber(x) end
    return tonumber(x), tonumber(y)
  end
  TR.swap = pfUI_cache and pfUI_cache.transportswap or nil
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
        -- whichever order lies on a route
        if not (TR.Match(nil, x, y) or TR.StopAt(x, y)) then x, y = a, b end
        TR.Seen(oid, x, y, now, clock)
      end
    end
  end
  -- a transport seen at x, y: once it is seen moving, fix its route
  -- riding one (15 Nov 2026; user on the Undercity zeppelin, nothing picked up:
  -- the object finder does not see transports on this client). You on a
  -- route's line moving along it faster than any mount (15+ yd/s, 2 s running,
  -- not on a taxi) = you are on that transport: that fixes it, and after 8 s
  -- its speed is measured.
  TR.ride = {}
  function TR.Ride(now, clock)
    local x, y = Pos()
    local R = TR.ride
    if not x or (UnitOnTaxi and UnitOnTaxi("player")) then TR.ride = {} return end
    local r, t, len = TR.Match(nil, x, y)
    if not r then
      r, t, len = TR.Match(nil, y, x)
      if not r then TR.ride = {} return end
      -- only the other order lies on a route: this client gives y, x
      TR.swap = not TR.swap
      pfUI_cache = pfUI_cache or {}
      pfUI_cache.transportswap = TR.swap
      x, y = y, x
    end
    if R.id == r.id and R.len and clock > R.clock then
      local sp = (len - R.len) / (clock - R.clock)
      if sp > 15 and sp < 80 then
        R.streak = (R.streak or 0) + (clock - R.clock)
        R.start = R.start or R.clock
        R.startLen = R.startLen or R.len
        if R.streak >= 8 then
          local m = (len - R.startLen) / (clock - R.start)
          if m > 15 and m < 80 and math.abs(m - r.speed) > .3 then
            local s = Store()
            s[r.id] = s[r.id] or {}
            s[r.id].speed = m
            r = TR.Build(r.id, m)
            r, t, len = TR.Match(nil, x, y)
            if not r then TR.ride = {} return end
            R.start, R.startLen = clock, len
          end
        end
        if R.streak >= 2 and TR.Fix(r, t, now, nil, 0) then
          TR.dirty = true
          if not R.told or clock - R.told > 120 then R.told = clock TR.Tell(r.id) end
        end
      elseif math.abs(sp) > 1 then
        R.streak, R.start, R.startLen = 0, nil, nil
      end
    else
      R.streak, R.start, R.startLen = 0, nil, nil
    end
    R.id, R.len, R.clock = r.id, len, clock
  end

  -- the dock stop nearest a point (within 50 yd): route, stop
  function TR.StopAt(x, y)
    local br, bs, bd
    for _, r in pairs(TR.routes) do
      for _, s in ipairs(r.stops) do
        local d = (s.x - x) * (s.x - x) + (s.y - y) * (s.y - y)
        if d < 2500 and (not bd or d < bd) then br, bs, bd = r, s, d end
      end
    end
    return br, bs
  end
  -- a transport standing still at a dock (15 Nov 2026; user saw two
  -- zeppelins at the Orgrimmar tower and none on the map: only moving ones
  -- were used). Unless the map already has it at that dock, put it in the
  -- middle of its wait there; the moment it leaves makes it exact.
  function TR.SeenDocked(x, y, now)
    local r, s = TR.StopAt(x, y)
    if not r then return end
    local t = TR.Now(r, now)
    local _, _, _, _, stop = TR.At(r, t)
    if stop == s then return end
    if TR.Fix(r, (s.t1 + s.t2) / 2, now, nil, 0) then
      Store()[r.id].docked = true
      TR.dirty = true
    end
  end
  function TR.Seen(oid, x, y, now, clock)
    local w = TR.watch[oid]
    if not w or clock - w.clock > 6 then
      TR.watch[oid] = { x = x, y = y, clock = clock }
      return
    end
    local moved = (x - w.x) * (x - w.x) + (y - w.y) * (y - w.y)
    if moved < 1 then
      w.clock = clock
      TR.SeenDocked(x, y, now)
      return
    end
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
  -- "S^route^loop seconds now^age of the sighting^speed (no "|": the server refuses it)"
  function TR.Message(id, now)
    local r, e = TR.routes[id], Store()[id]
    if not r or not e or not e.t0 then return end
    now = now or time()
    return "S^" .. id .. "^" .. string.format("%.1f", math.mod(now - e.t0, r.period))
      .. "^" .. math.floor(now - (e.seen or now)) .. "^" .. string.format("%.2f", r.speed)
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
    local _, _, city, since, gap = string.find(msg, "^T%^(%a+)%^(%d+)%^([%d%.]+)$")
    if city then
      since, gap = tonumber(since), tonumber(gap)
      local e = TR.TRAM and TR.TRAM[city] and TR.Tram()[city]
      if not TR.TRAM or not TR.TRAM[city] or from == UnitName("player") or since > 6 * 3600 or gap < 20 or gap > 160 then return end
      if e and e.dep and e.dep >= now - since - 1 then return end
      TR.TramDeparted(city, now - since, from, gap)
      return
    end
    local _, _, id, t, age, sp = string.find(msg, "^S%^(%d+)%^([%d%.]+)%^(%d+)%^([%d%.]+)$")
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
      for city in pairs(TR.TRAM or {}) do TR.TellTram(city) end
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
    -- a dark disc, a ring in the route's colour, the white picture on top:
    -- reads on any map colour (the first tinted pictures vanished on Durotar)
    local IMG = "Interface\\AddOns\\pfUI\\img\\transports\\"
    b.badge = b:CreateTexture(nil, "BACKGROUND")
    b.badge:SetTexture(IMG .. "badge")
    b.badge:SetAllPoints(b)
    b.badge:SetVertexColor(.05, .05, .07, .9)
    b.ring = b:CreateTexture(nil, "BORDER")
    b.ring:SetTexture(IMG .. "ring")
    b.ring:SetAllPoints(b)
    b.tex = b:CreateTexture(nil, "OVERLAY")
    b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
    b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
    -- the colour goes on the ring; the picture stays white
    b.Paint = function(self, c) self.ring:SetVertexColor(c[1], c[2], c[3]) self.tex:SetVertexColor(1, 1, 1) end
    b:SetScript("OnEnter", function()
      local r = this.route or (this.tramCity and TR.TRAMROUTE)
      if not r then return end
      local tip = _G.WorldMapTooltip or GameTooltip
      tip:SetOwner(this, "ANCHOR_RIGHT")
      local lines = this.tramCity and TR.TramLines(this.tramCity) or TR.Lines(r)
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
    -- bigger on a zone map; still clear on a whole continent
    local size = a and (a[1] == "Kalimdor" or a[1] == "Azeroth") and 28 or 34
    if a then
      for _, r in pairs(TR.routes) do
        local t, e = TR.Now(r, now)
        local map, x, y, moving, stop, dir = TR.At(r, t)
        local u, v = TR.MapSpot(a, map, x, y)
        if u then
          i = i + 1
          local b = Pin(i)
          b.route, b.tramCity = r, nil
          b:ClearAllPoints()
          b:SetPoint("CENTER", layer, "TOPLEFT", u * w, -v * h)
          b:SetWidth(size) b:SetHeight(size)
          b.tex:SetTexture("Interface\\AddOns\\pfUI\\img\\transports\\" .. r.kind)
          -- the pictures face left; a route heading east (world y falling) flips them
          if dir and dir < 0 then b.tex:SetTexCoord(1, 0, 0, 1) else b.tex:SetTexCoord(0, 1, 0, 1) end
          b:Paint(r.color)
          b:SetAlpha(e and 1 or .7)
          b:Show()
        end
      end
      -- the Deeprun Tram's door in each city
      for city, d in pairs(TR.TRAM) do
        if a[1] == d.map then
          local u, v = TR.TramSpot(city)
          i = i + 1
          local b = Pin(i)
          b.route, b.tramCity = nil, city
          b:ClearAllPoints()
          b:SetPoint("CENTER", layer, "TOPLEFT", u * w, -v * h)
          b:SetWidth(size) b:SetHeight(size)
          b.tex:SetTexture("Interface\\AddOns\\pfUI\\img\\transports\\tram")
          b.tex:SetTexCoord(0, 1, 0, 1)
          b:Paint(A)
          b:SetAlpha(TR.TramNext(city) and 1 or .7)
          b:Show()
        end
      end
    end
    for k = i + 1, table.getn(TR.pins) do TR.pins[k]:Hide() end
  end

  -- ------------------------------------------------------ Deeprun Tram
  -- The tram runs in its own instance (no world map). Its cars (objects
  -- 176080-176085, TransportAnimation.dbc) take 143.3 s for a whole loop and
  -- wait 13 s at each end. Inside, ClassicAPI shows the cars: one near you
  -- that starts moving = a departure from your platform (kept per city, the
  -- gap between departures learnt, shared as "T^city^seconds since^gap").
  -- Your platform = the city you came in from while you stay near where you
  -- came in, else the other one. The map door spot is learnt from where you
  -- stood just before going in (UnitPosition), else a guess.
  TR.TRAMROUTE = { color = A }
  TR.TRAMCARS = { 176080, 176081, 176082, 176083, 176084, 176085 }
  TR.TRAMLOOP, TR.TRAMWAIT = 143.3, 13
  TR.TRAM = {
    Stormwind = { map = "Stormwind", zone = "Stormwind City", u = .694, v = .31, other = "Ironforge" },
    Ironforge = { map = "Ironforge", zone = "Ironforge", u = .766, v = .512, other = "Stormwind" },
  }
  function TR.Tram()
    local s = Store()
    s.tram = s.tram or {}
    return s.tram
  end
  function TR.TramSpot(city)
    local d, e = TR.TRAM[city], TR.Tram()[city]
    if e and e.dx and areaByName[d.map] then
      local u, v = TR.MapSpot(areaByName[d.map], areaByName[d.map][2], e.dx, e.dy)
      if u then return u, v end
      u, v = TR.MapSpot(areaByName[d.map], areaByName[d.map][2], e.dy, e.dx)
      if u then return u, v end
    end
    return d.u, d.v
  end
  -- seconds until the next car leaves `city`, or nil when never timed
  function TR.TramNext(city, now)
    local e = TR.Tram()[city]
    if not e or not e.dep then return end
    now = now or time()
    local gap = e.gap or TR.TRAMLOOP
    local n = math.ceil((now - e.dep) / gap)
    if n < 0 then n = 0 end
    return e.dep + n * gap - now, gap, e
  end
  function TR.TramDeparted(city, now, from, gap)
    local e = TR.Tram()[city] or {}
    TR.Tram()[city] = e
    if e.dep and not from then
      local d = now - e.dep
      if d > 20 and d < TR.TRAMLOOP + 10 then e.gap = d end
    end
    if gap then e.gap = gap end
    e.dep, e.from = now, from
    TR.dirty = true
  end
  function TR.TramLines(city, now)
    now = now or time()
    local lines = { "Deeprun Tram to " .. TR.TRAM[city].other }
    local wait, gap, e = TR.TramNext(city, now)
    if not wait then
      table.insert(lines, "|cffff9933Not timed yet: ride it once with ClassicAPI, or a guild mate does.|r")
      return lines
    end
    local still = gap - wait
    if still < TR.TRAMWAIT and still >= 0 then
      table.insert(lines, "A car is at the platform (" .. Clock(TR.TRAMWAIT - still) .. " left)")
    end
    table.insert(lines, "Next car leaves in " .. Clock(wait))
    local ago = now - e.dep
    table.insert(lines, "|cff999999A car every " .. Clock(gap) .. "; timed " .. (ago < 120 and "just now" or ago < 7200
      and (math.floor(ago / 60) .. " min ago") or (math.floor(ago / 3600) .. " h ago")) .. (e.from and (" by " .. e.from) or "") .. "|r")
    return lines
  end
  -- which city's platform you are on inside the tram
  function TR.TramPlatform()
    local x, y = Pos()
    local inn = TR.tramIn
    if not inn then return end
    if x and inn.x and (x - inn.x) * (x - inn.x) + (y - inn.y) * (y - inn.y) > 150 * 150 then
      return TR.TRAM[inn.city] and TR.TRAM[inn.city].other
    end
    return inn.city
  end
  TR.cars = {}
  function TR.InTram()
    local z = GetRealZoneText and GetRealZoneText()
    return z == "Deeprun Tram" or (TR.tramIn and TR.tramIn.zone == z)
  end
  -- every .5 s: remember the city spot, watch the cars inside
  function TR.TramTick(now, clock)
    local z = GetRealZoneText and GetRealZoneText() or ""
    local x, y = Pos()
    for city, d in pairs(TR.TRAM) do
      if z == d.zone and x then TR.lastCity = { city = city, x = x, y = y } end
    end
    if not TR.InTram() then
      TR.tramIn = nil
      if TR.tramText then TR.tramText:Hide() end
      return
    end
    if not TR.tramIn then
      local c = TR.lastCity
      TR.tramIn = { city = c and c.city or "Ironforge", zone = z, x = x, y = y }
      if c then
        local e = TR.Tram()[c.city] or {}
        TR.Tram()[c.city] = e
        e.dx, e.dy = c.x, c.y
      end
    end
    local city = TR.TramPlatform()
    local find = Finder()
    local here, coming
    if find and x then
      for _, oid in ipairs(TR.TRAMCARS) do
        local ok, a, b = pcall(find, oid)
        a, b = tonumber(a), tonumber(b)
        if ok and a and b then
          local cx, cy = b, a
          if (x - a) * (x - a) + (y - b) * (y - b) < (x - cx) * (x - cx) + (y - cy) * (y - cy) then cx, cy = a, b end
          local dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
          local w = TR.cars[oid]
          if w and clock - w.clock < 3 then
            local sp = (w.dist - dist) / (clock - w.clock)
            local moving = math.abs(dist - w.dist) > .3
            if dist < 40 and not moving then here = true end
            if dist < 45 and moving and w.still and city then TR.TramDeparted(city, now) TR.TellTram(city) end
            if moving and sp > 3 and (not coming or dist / sp < coming) then coming = dist / sp end
            w.still = not moving
          end
          TR.cars[oid] = { dist = dist, clock = clock, still = TR.cars[oid] and TR.cars[oid].still }
        end
      end
    end
    if not TR.tramText then
      local t = UIParent:CreateFontString("pfTransportTram", "OVERLAY", "GameFontNormalLarge")
      t:SetPoint("TOP", UIParent, "TOP", 0, -140)
      TR.tramText = t
    end
    local text
    if here then text = "Tram: a car is here"
    elseif coming then text = "Tram: next car here in " .. Clock(coming)
    elseif city then
      local wait = TR.TramNext(city, now)
      text = wait and ("Tram to " .. TR.TRAM[city].other .. ": leaves in about " .. Clock(wait)) or nil
    end
    if text then TR.tramText:SetText(text) TR.tramText:Show() else TR.tramText:Hide() end
  end
  function TR.TellTram(city)
    local wait, gap, e = TR.TramNext(city)
    if not wait or e.from or table.getn(out) >= 40 then return end
    table.insert(out, "T^" .. city .. "^" .. math.floor(time() - e.dep) .. "^" .. string.format("%.1f", gap))
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
      if TR.tramText then TR.tramText:Hide() end
      return
    end
    if clock >= lookAt then
      lookAt = clock + .5
      if not TR.InTram() then TR.Look(time(), clock) TR.Ride(time(), clock) end
      TR.TramTick(time(), clock)
    end
    if WorldMapButton and WorldMapFrame and WorldMapFrame:IsShown() then
      if not layer then
        layer = CreateFrame("Frame", "pfTransportPins", WorldMapButton)
        layer:SetAllPoints(WorldMapButton)
        layer:SetFrameLevel(WorldMapButton:GetFrameLevel() + 12)
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
    elseif msg == "probe" then
      -- which transport objects the client sees now, and where
      local find, px, py = Finder(), Pos()
      if not find then out2:AddMessage("|cff33ffccpfUI|r probe needs ClassicAPI.") return end
      out2:AddMessage("|cff33ffccpfUI|r you at " .. tostring(px) .. ", " .. tostring(py))
      for _, oid in ipairs(TR.OBJECTS) do
        local ok, a, b, c = pcall(find, oid)
        if ok and a then
          local r1, s1 = TR.StopAt(tonumber(b) or 0, tonumber(a) or 0)
          local r2, s2 = TR.StopAt(tonumber(a) or 0, tonumber(b) or 0)
          local s = s1 or s2
          out2:AddMessage("  " .. oid .. ": " .. tostring(a) .. ", " .. tostring(b) .. ", " .. tostring(c)
            .. (s and ("  at " .. s.dock .. " (" .. table.concat((r1 or r2).docks, " - ") .. ")") or ""))
        end
      end
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
