pfUI:RegisterModule("flight", "vanilla", function ()
  -- pfUI Octo :: flight timer (15 Nov 2026; user, with a screenshot of another client's bar:
  -- "the forever flight timers also very nice ... yes build it all"). A line from where you
  -- took off to where you land, a tick for every flight point on the way with its name, a
  -- "You" marker moving along it and the time left. Written fresh from the screenshot.
  --
  -- The route is read when you click a destination (TakeTaxiNode is wrapped):
  --   ClassicAPI  C_TaxiMap.GetTaxiRoute(slot) = the node chain; GetTaxiPaths + GetTaxiPathWaypoints
  --               = each leg's real path, so the length is known (32 yd/s) before the first flight,
  --               and where you are is read off the path from your own position (UnitPosition).
  --   plain 1.12  the taxi map's own route lines (GetNumRoutes / TaxiGetDestX,Y matched to the
  --               nodes' places) for the stops; the time is a guess from the map distance until
  --               the route has been flown once.
  -- Every flight is timed and kept (pfUI_cache.flighttimes["From>To"], all characters), which
  -- beats any estimate; times are shared with guild and group over the addon channel (pfFT).
  -- A flight in the air survives a /reload (pfUI_cache.flightnow, wall clock).
  --
  -- NOT possible: landing early at a stop on the way. The 1.12 client has no call for it (the
  -- request only exists in much later game versions) and neither ClassicAPI, SuperWoW nor
  -- nampower adds one; it would need the server to offer it.
  local FL = { stops = {} }
  pfUI.flight = FL
  local function S() return C.flight end
  local function On(key) return S()[key] == "1" end
  local function Num(key, d) return tonumber(S()[key]) or d end
  local SPEED = 32
  FL.SPEED = SPEED

  local function Times()
    pfUI_cache.flighttimes = pfUI_cache.flighttimes or {}
    return pfUI_cache.flighttimes
  end
  function FL.Key(names) return names[1] .. ">" .. names[table.getn(names)] end
  function FL.Clock(sec)
    if not sec then return "" end
    sec = math.max(0, math.floor(sec + .5))
    return math.floor(sec / 60) .. ":" .. string.format("%02d", math.mod(sec, 60))
  end
  -- "Crossroads, The Barrens" -> "Crossroads"
  function FL.Short(name)
    if not On("short") or type(name) ~= "string" then return name end
    local _, _, first = string.find(name, "^([^,]+),")
    return first or name
  end

  -- ---------------------------------------------------------------- the route (ClassicAPI)

  local function Taxi() return rawget(_G, "C_TaxiMap") end
  function FL.HasPaths()
    local t = Taxi()
    return type(t) == "table" and type(t.GetTaxiRoute) == "function" and type(t.GetTaxiPaths) == "function"
      and type(t.GetTaxiPathWaypoints) == "function" and type(t.GetTaxiNodesForMap) == "function"
  end
  -- node id -> name
  function FL.Nodes()
    if FL.nodes then return FL.nodes end
    local out = {}
    local ok, list = pcall(Taxi().GetTaxiNodesForMap)
    if ok and type(list) == "table" then
      for _, n in ipairs(list) do
        if n.nodeID and n.name then out[n.nodeID] = n.name end
      end
    end
    FL.nodes = out
    return out
  end
  -- "from>to" (node ids) -> path id
  function FL.Paths()
    if FL.paths then return FL.paths end
    local out = {}
    local ok, list = pcall(Taxi().GetTaxiPaths)
    if ok and type(list) == "table" then
      for _, p in ipairs(list) do
        if p.pathID and p.fromNodeID and p.toNodeID then out[p.fromNodeID .. ">" .. p.toNodeID] = p.pathID end
      end
    end
    FL.paths = out
    return out
  end
  -- a plan from a chain of node ids: names, the whole path as points with the length so far, where each stop is
  function FL.PlanFromRoute(route)
    if type(route) ~= "table" or table.getn(route) < 2 then return nil end
    local nodes, paths = FL.Nodes(), FL.Paths()
    local plan = { names = {}, fracs = {}, pts = {}, exact = true }
    local length = 0
    local marks = { 0 }
    for i, id in ipairs(route) do
      plan.names[i] = nodes[id] or ("Flight point " .. tostring(id))
      if i > 1 then
        local pid = paths[route[i - 1] .. ">" .. id]
        local ok, wp = false, nil
        if pid then ok, wp = pcall(Taxi().GetTaxiPathWaypoints, pid) end
        if not ok or type(wp) ~= "table" or table.getn(wp) < 2 then return nil end
        for _, w in ipairs(wp) do
          local last = plan.pts[table.getn(plan.pts)]
          local x, y, z = tonumber(w.x), tonumber(w.y), tonumber(w.z) or 0
          if not x or not y then return nil end
          if last then
            local dx, dy, dz = x - last[1], y - last[2], z - last[3]
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            -- (a leg starts where the one before ended: a jump of a few yards, not flown)
            if d < 4000 then length = length + d end
          end
          table.insert(plan.pts, { x, y, z, length })
        end
        marks[i] = length
      end
    end
    if length <= 0 then return nil end
    plan.length = length
    for i = 1, table.getn(route) do plan.fracs[i] = marks[i] / length end
    -- (a chain is a little shorter than its legs: the corner at each stop is cut; FL.Cut = learnt share)
    local hops = table.getn(route) - 1
    plan.cut = hops > 1 and FL.Cut() or 1
    plan.est = length / SPEED * plan.cut
    return plan
  end
  function FL.Cut()
    local c = tonumber(pfUI_cache.flightcut)
    if c and c > .7 and c <= 1 then return c end
    return .97
  end

  -- ---------------------------------------------------------------- the route (plain 1.12)

  function FL.PlanFromMap(slot)
    if not (NumTaxiNodes and TaxiNodeName and TaxiNodeGetType) then return nil end
    local src
    local spots = {}
    for i = 1, NumTaxiNodes() do
      if TaxiNodeGetType(i) == "CURRENT" then src = i end
      if TaxiNodePosition then
        local x, y = TaxiNodePosition(i)
        spots[i] = { x, y }
      end
    end
    local dest = TaxiNodeName(slot)
    if not src or not dest then return nil end
    local plan = { names = { TaxiNodeName(src) }, fracs = { 0 } }
    local marks, length = { 0 }, 0
    local hops = GetNumRoutes and GetNumRoutes(slot) or 0
    if hops and hops > 0 and hops < 20 and TaxiGetDestX and TaxiGetSrcX then
      for r = 1, hops do
        local sx, sy, dx, dy = TaxiGetSrcX(slot, r), TaxiGetSrcY(slot, r), TaxiGetDestX(slot, r), TaxiGetDestY(slot, r)
        length = length + math.sqrt((dx - sx) * (dx - sx) + (dy - sy) * (dy - sy))
        local name
        for i, p in pairs(spots) do
          if math.abs(p[1] - dx) < .012 and math.abs(p[2] - dy) < .012 then name = TaxiNodeName(i) end
        end
        table.insert(plan.names, (r == hops) and dest or (name or "?"))
        table.insert(marks, length)
      end
    else
      if spots[src] and spots[slot] then
        local dx, dy = spots[slot][1] - spots[src][1], spots[slot][2] - spots[src][2]
        length = math.sqrt(dx * dx + dy * dy)
      end
      table.insert(plan.names, dest)
      table.insert(marks, length)
    end
    for i = 1, table.getn(marks) do plan.fracs[i] = (length > 0) and (marks[i] / length) or ((i - 1) / math.max(1, table.getn(marks) - 1)) end
    plan.maplen = length
    -- (seconds per map length, learnt from flights flown)
    local rate = tonumber(pfUI_cache.flightrate)
    if rate and length > 0 then plan.est = length * rate end
    return plan
  end

  -- the plan for a taxi map slot: the best the client can give, with the time when it is known
  function FL.Plan(slot)
    local plan
    if FL.HasPaths() then
      local ok, route = pcall(Taxi().GetTaxiRoute, slot)
      if ok then plan = FL.PlanFromRoute(route) end
    end
    if not plan then
      local ok, p = pcall(FL.PlanFromMap, slot)
      plan = ok and p or nil
    end
    if not plan then return nil end
    plan.key = FL.Key(plan.names)
    plan.learned = tonumber(Times()[plan.key])
    plan.total = plan.learned or plan.est
    return plan
  end

  -- ---------------------------------------------------------------- where you are on the path

  local function Nearest(pts, x, y, from, to)
    local best, at, idx = nil, 0, from
    for i = from, to do
      local a, b = pts[i], pts[i + 1]
      local vx, vy = b[1] - a[1], b[2] - a[2]
      local l2 = vx * vx + vy * vy
      local t = 0
      if l2 > 0 then t = math.max(0, math.min(1, ((x - a[1]) * vx + (y - a[2]) * vy) / l2)) end
      local px, py = a[1] + vx * t, a[2] + vy * t
      local d = (x - px) * (x - px) + (y - py) * (y - py)
      if not best or d < best then best, at, idx = d, a[4] + (b[4] - a[4]) * t, i end
    end
    return best, at, idx
  end
  -- yards flown along the plan's path for a world position (never goes backwards)
  function FL.Along(plan, x, y)
    local pts = plan.pts
    local n = pts and table.getn(pts) or 0
    if n < 2 then return nil end
    if plan.swap == nil then
      -- (which of the two numbers is which: the order that lies on the path)
      local d1 = Nearest(pts, x, y, 1, n - 1)
      local d2 = Nearest(pts, y, x, 1, n - 1)
      plan.swap = d2 < d1
    end
    if plan.swap then x, y = y, x end
    local from = math.max(1, (plan.idx or 1) - 1)
    local d, at, idx = Nearest(pts, x, y, from, math.min(n - 1, from + 14))
    if d > 250 * 250 then d, at, idx = Nearest(pts, x, y, 1, n - 1) end
    if d > 600 * 600 then return nil end
    plan.idx = idx
    if at < (plan.at or 0) then at = plan.at end
    plan.at = at
    return at
  end

  -- progress 0..1 (nil = unknown), seconds left (nil = unknown), seconds flown
  function FL.Progress(f, now)
    local plan = f.plan
    local flown = now - f.start
    local prog, left
    if plan.pts and rawget(_G, "UnitPosition") then
      local ok, x, y = pcall(_G.UnitPosition, "player")
      x, y = tonumber(x), tonumber(y)
      if ok and x and y then
        local at = FL.Along(plan, x, y)
        if at then
          prog = at / plan.length
          left = (plan.length - at) / SPEED * (plan.cut or 1)
          -- (a time flown before is the better clock once it is close)
          if plan.learned then left = math.max(0, plan.learned - flown) end
        end
      end
    end
    if not prog and plan.total and plan.total > 0 then
      prog = math.min(1, flown / plan.total)
      left = math.max(0, plan.total - flown)
    end
    return prog, left, flown
  end

  -- ---------------------------------------------------------------- taking off and landing

  -- the plan for the slot about to be flown (read while the flight map is still open)
  function FL.Capture(slot)
    if not On("enable") then return end
    local ok, plan = pcall(FL.Plan, slot)
    if ok and plan then FL.pending, FL.pendingAt = plan, GetTime() end
  end
  local take = _G.TakeTaxiNode
  if type(take) == "function" and not FL.wrapped then
    FL.wrapped = true
    _G.TakeTaxiNode = function(slot)
      FL.Capture(slot)
      return take(slot)
    end
  end
  function FL.Start(plan, now, flown)
    FL.now = { plan = plan, start = now - (flown or 0), partial = flown and true or nil }
    pfUI_cache.flightnow = { names = plan.names, fracs = plan.fracs, total = plan.total, key = plan.key,
      at = (time and time() or 0) - (flown or 0) }
  end
  function FL.Land(now)
    local f = FL.now
    FL.now, pfUI_cache.flightnow = nil, nil
    if not f then return end
    local plan = f.plan
    local dur = now - f.start
    -- (a flight picked up after a /reload has no path any more, but its start is the wall clock's: still timed)
    if dur < 8 or not plan.key or plan.unknown then return end
    if plan.total and (dur < plan.total * .5 or dur > plan.total * 1.6) then return end
    Times()[plan.key] = math.floor(dur * 10 + .5) / 10
    if plan.exact and plan.length and table.getn(plan.names) > 2 then
      local cut = dur / (plan.length / SPEED)
      if cut > .7 and cut <= 1 then pfUI_cache.flightcut = (FL.Cut() * 3 + cut) / 4 end
    elseif plan.maplen and plan.maplen > 0 then
      local rate = dur / plan.maplen
      local had = tonumber(pfUI_cache.flightrate)
      pfUI_cache.flightrate = had and ((had * 3 + rate) / 4) or rate
    end
    FL.Tell(plan.key, Times()[plan.key])
    return dur
  end
  -- on a flight with nothing known (reloaded in the air): what was kept, else a bare timer
  function FL.Resume(now)
    local k = pfUI_cache.flightnow
    local wall = time and time() or 0
    if type(k) == "table" and type(k.names) == "table" and k.at and wall - k.at >= 0 and wall - k.at < ((k.total or 900) + 180) then
      local plan = { names = k.names, fracs = k.fracs or { 0, 1 }, total = k.total, key = k.key, learned = k.total }
      FL.now = { plan = plan, start = now - (wall - k.at), partial = true }
    else
      FL.now = { plan = { names = { "In flight", "" }, fracs = { 0, 1 }, unknown = true }, start = now, partial = true }
    end
  end
  function FL.Tick(now)
    local flying = UnitOnTaxi and UnitOnTaxi("player") and true or false
    if FL.pending then
      if flying then FL.Start(FL.pending, now) FL.pending = nil
      elseif now - (FL.pendingAt or 0) > 12 then FL.pending = nil end
    end
    if flying and not FL.now and On("enable") then FL.Resume(now) end
    if not flying and FL.now and not FL.pending then FL.Land(now) end
  end

  -- ---------------------------------------------------------------- times shared (pfFT)
  local PREFIX = "pfFT"
  function FL.Tell(key, secs)
    if not On("share") or type(SendAddonMessage) ~= "function" or not secs then return end
    local msg = key .. "^" .. secs
    if string.len(msg) > 240 then return end
    if IsInGuild and IsInGuild() then SendAddonMessage(PREFIX, msg, "GUILD") end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then SendAddonMessage(PREFIX, msg, "RAID")
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then SendAddonMessage(PREFIX, msg, "PARTY") end
  end
  -- another player's time for a route: kept when you have none of your own
  function FL.Receive(msg, from)
    if not On("share") or type(msg) ~= "string" or from == UnitName("player") then return false end
    local _, _, key, secs = string.find(msg, "^(.+)%^([%d%.]+)$")
    secs = tonumber(secs)
    if not key or not secs or secs < 8 or secs > 3600 or string.len(key) > 200 or not string.find(key, ">", 1, true) then return false end
    if Times()[key] then return false end
    Times()[key] = secs
    FL.got = (FL.got or 0) + 1
    return true
  end
  function FL.Count()
    local n = 0
    for _ in pairs(Times()) do n = n + 1 end
    return n
  end

  -- ---------------------------------------------------------------- the bar

  local WHITE = "Interface\\Buttons\\WHITE8X8"
  -- (15 Nov 2026, user on the first version: "could look better") round flight-point marks as on the flight
  -- map, a dark edge under the line, a glow at the tip of the flown part and round the flyer, the
  -- destination's name in its mark's colour, a bigger time
  local NODE = "Interface\\TaxiFrame\\UI-Taxi-Icon-White"
  local function Col(key, r, g, b, a)
    local _, _, cr, cg, cb, ca = string.find(S()[key] or "", "([%d%.]+),([%d%.]+),([%d%.]+),?([%d%.]*)")
    return tonumber(cr) or r, tonumber(cg) or g, tonumber(cb) or b, tonumber(ca) or a or 1
  end
  FL.Col = Col
  local function Text(f, size)
    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(pfUI.font_default, size, "OUTLINE")
    return t
  end
  -- the bar (on screen, or in the options preview)
  function FL.NewBar(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetTexture(WHITE)
    f.done = f:CreateTexture(nil, "OVERLAY")
    f.done:SetTexture(WHITE)
    f.endL = f:CreateTexture(nil, "OVERLAY")
    f.endL:SetTexture(NODE)
    f.endR = f:CreateTexture(nil, "OVERLAY")
    f.endR:SetTexture(NODE)
    f.you = f:CreateTexture(nil, "OVERLAY")
    f.you:SetTexture(WHITE)
    f.youText = Text(f, 12)
    f.youText:SetText("You")
    f.flyer = f:CreateTexture(nil, "OVERLAY")
    f.flyer:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-White")
    f.time = Text(f, 12)
    f.from = Text(f, 12)
    f.to = Text(f, 12)
    f.pic = f:CreateTexture(nil, "ARTWORK")
    f.pic:SetTexCoord(.07, .93, .07, .93)
    f.picEdge = f:CreateTexture(nil, "BACKGROUND")
    f.picEdge:SetTexture(0, 0, 0, 1)
    f.outline = f:CreateTexture(nil, "BACKGROUND")
    f.outline:SetTexture(0, 0, 0, .85)
    f.spark = f:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    f.spark:SetBlendMode("ADD")
    f.flyglow = f:CreateTexture(nil, "ARTWORK")
    f.flyglow:SetTexture("Interface\\AddOns\\pfUI\\img\\plates\\cp-glow")
    f.flyglow:SetBlendMode("ADD")
    f.panel = f:CreateTexture(nil, "BACKGROUND")
    f.panel:SetTexture(0, 0, 0, .45)
    f.ticks = {}
    return f
  end
  local function Tick(f, i)
    local t = f.ticks[i]
    if t then return t end
    t = { mark = f:CreateTexture(nil, "OVERLAY"), text = Text(f, 12) }
    t.mark:SetTexture(NODE)
    f.ticks[i] = t
    return t
  end
  -- view = { names, fracs, prog (0..1 or nil), left (s or nil), guess (the time is an estimate) }
  function FL.Paint(f, view)
    local w = Num("width", 420)
    local size = Num("textsize", 12)
    local thick = Num("thick", 2)
    local pic = On("picture") and Num("picsize", 30) or 0
    local lr, lg, lb, la = Col("linecolor", 1, 1, 1, 1)
    local er, eg, eb, ea = Col("endcolor", .86, .6, .42, 1)
    local tr, tg, tb = Col("textcolor", 1, 1, 1, 1)
    local dr, dg, db, da = Col("donecolor", .35, .8, 1, 1)
    local node = thick + 12
    local timeW = On("showtime") and 50 or 0
    f:SetWidth(timeW + w + (pic > 0 and (pic + 12) or 0))
    f:SetHeight(math.max(pic, 2 * size + 22))
    local x0 = timeW
    f.line:ClearAllPoints()
    f.line:SetPoint("LEFT", f, "LEFT", x0, 0)
    f.line:SetWidth(w)
    f.line:SetHeight(thick)
    f.line:SetVertexColor(lr, lg, lb, la)
    f.outline:ClearAllPoints()
    f.outline:SetPoint("LEFT", f, "LEFT", x0 - 1, 0)
    f.outline:SetWidth(w + 2)
    f.outline:SetHeight(thick + 2)
    f.panel:ClearAllPoints()
    f.panel:SetPoint("TOPLEFT", f, "TOPLEFT", -8, 8)
    f.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 8, -8)
    if On("panel") then f.panel:Show() else f.panel:Hide() end
    local prog = view.prog
    local px = x0 + w * math.max(0, math.min(1, prog or 0))
    if prog and prog > 0 then
      f.done:ClearAllPoints()
      f.done:SetPoint("LEFT", f, "LEFT", x0, 0)
      f.done:SetWidth(math.max(1, px - x0))
      f.done:SetHeight(thick)
      f.done:SetVertexColor(dr, dg, db, da)
      f.done:Show()
      f.spark:ClearAllPoints()
      f.spark:SetPoint("CENTER", f, "LEFT", px, 0)
      f.spark:SetWidth(22)
      f.spark:SetHeight(thick * 8 + 14)
      f.spark:SetVertexColor(dr, dg, db, .9)
      f.spark:Show()
    else
      f.done:Hide() f.spark:Hide()
    end
    for _, e in ipairs({ { f.endL, x0, dr, dg, db }, { f.endR, x0 + w, er, eg, eb } }) do
      e[1]:ClearAllPoints()
      e[1]:SetPoint("CENTER", f, "LEFT", e[2], 0)
      e[1]:SetWidth(node + 2)
      e[1]:SetHeight(node + 2)
      e[1]:SetVertexColor(e[3], e[4], e[5], 1)
    end
    for _, t in ipairs({ f.time, f.from, f.to, f.youText }) do
      t:SetFont(pfUI.font_default, size, "OUTLINE")
      t:SetTextColor(tr, tg, tb)
    end
    local names = view.names
    local n = table.getn(names)
    f.from:ClearAllPoints()
    f.from:SetPoint("BOTTOMLEFT", f, "LEFT", x0, 7)
    f.from:SetText(FL.Short(names[1]) or "")
    f.to:ClearAllPoints()
    f.to:SetPoint("BOTTOMRIGHT", f, "LEFT", x0 + w, 7)
    f.to:SetText(FL.Short(names[n]) or "")
    f.to:SetTextColor(math.min(1, er + .12), math.min(1, eg + .12), math.min(1, eb + .12))
    f.time:SetFont(pfUI.font_default, size + 3, "OUTLINE")
    f.time:ClearAllPoints()
    f.time:SetPoint("RIGHT", f, "LEFT", x0 - 12, 0)
    if On("showtime") then
      f.time:SetText(view.left and ((view.guess and "~" or "") .. FL.Clock(view.left)) or (view.flown and FL.Clock(view.flown) or ""))
    else
      f.time:SetText("")
    end
    -- the stops between: a tick each, names under the line (two rows when they would touch)
    local shown = 0
    if On("stops") then
      local lastX, row = -999, 0
      for i = 2, n - 1 do
        shown = shown + 1
        local t = Tick(f, shown)
        local x = x0 + w * (view.fracs[i] or (i - 1) / (n - 1))
        t.mark:ClearAllPoints()
        t.mark:SetPoint("CENTER", f, "LEFT", x, 0)
        t.mark:SetWidth(node)
        t.mark:SetHeight(node)
        local passed = prog and (view.fracs[i] or 0) <= prog
        if passed then t.mark:SetVertexColor(dr, dg, db, da) else t.mark:SetVertexColor(er, eg, eb, ea) end
        t.mark:Show()
        t.text:SetFont(pfUI.font_default, size, "OUTLINE")
        t.text:SetText(FL.Short(names[i]) or "")
        local tw = t.text:GetStringWidth() or 60
        if x - tw / 2 < lastX + 8 then row = 1 - row else row = 0 end
        t.text:ClearAllPoints()
        t.text:SetPoint("TOP", f, "LEFT", x, -7 - row * (size + 2))
        if passed then t.text:SetTextColor(tr * .6, tg * .6, tb * .6) else t.text:SetTextColor(tr, tg, tb) end
        t.text:Show()
        lastX = x + tw / 2
      end
    end
    for i = shown + 1, table.getn(f.ticks) do f.ticks[i].mark:Hide() f.ticks[i].text:Hide() end
    -- you
    if prog then
      f.you:ClearAllPoints()
      f.you:SetPoint("CENTER", f, "LEFT", px, 0)
      f.you:SetWidth(2)
      f.you:SetHeight(thick + 14)
      f.you:SetVertexColor(lr, lg, lb, 1)
      f.you:Show()
      f.flyer:ClearAllPoints()
      f.flyer:SetPoint("CENTER", f, "LEFT", px, 0)
      f.flyer:SetWidth(Num("flyersize", 16))
      f.flyer:SetHeight(Num("flyersize", 16))
      f.flyer:SetVertexColor(dr, dg, db, 1)
      f.flyglow:ClearAllPoints()
      f.flyglow:SetPoint("CENTER", f, "LEFT", px, 0)
      local gs = Num("flyersize", 16) * (2.1 + .35 * math.sin(GetTime() * 4))
      f.flyglow:SetWidth(gs)
      f.flyglow:SetHeight(gs)
      f.flyglow:SetVertexColor(dr, dg, db, .8)
      if On("flyer") then f.flyglow:Show() else f.flyglow:Hide() end
      if On("flyer") then f.flyer:Show() else f.flyer:Hide() end
      f.youText:ClearAllPoints()
      f.youText:SetPoint("BOTTOM", f, "LEFT", px, 7 + size + 2)
      -- (seen in game 15 Nov: "You" stacked on top of an end's name while near it: it waits until clear)
      local fw, tw = f.from:GetStringWidth() or 0, f.to:GetStringWidth() or 0
      local clear = px > x0 + fw + 16 and px < x0 + w - tw - 16
      if On("you") and clear then f.youText:Show() else f.youText:Hide() end
    else
      f.you:Hide() f.flyer:Hide() f.youText:Hide() f.flyglow:Hide()
    end
    if pic > 0 then
      f.pic:ClearAllPoints()
      f.pic:SetPoint("LEFT", f, "LEFT", x0 + w + 12, 0)
      f.pic:SetWidth(pic)
      f.pic:SetHeight(pic)
      local path = S().pictex
      f.pic:SetTexture((path and path ~= "") and path or "Interface\\Icons\\INV_Feather_01")
      f.picEdge:ClearAllPoints()
      f.picEdge:SetPoint("TOPLEFT", f.pic, "TOPLEFT", -1, 1)
      f.picEdge:SetPoint("BOTTOMRIGHT", f.pic, "BOTTOMRIGHT", 1, -1)
      f.pic:Show() f.picEdge:Show()
    else
      f.pic:Hide() f.picEdge:Hide()
    end
  end
  -- a made-up flight for layout mode and the options preview
  function FL.Sample(now)
    local total = 95
    local flown = math.mod(now, total)
    return { names = { "Orgrimmar, Durotar", "Crossroads, The Barrens", "Ratchet, The Barrens" }, fracs = { 0, .58, 1 },
      prog = flown / total, left = total - flown }
  end
  function FL.View(now)
    local f = FL.now
    if not f then return nil end
    local prog, left, flown = FL.Progress(f, now)
    return { names = f.plan.names, fracs = f.plan.fracs, prog = prog, left = left, flown = flown,
      guess = not f.plan.learned and not f.plan.exact }
  end

  local bar = FL.NewBar(UIParent)
  FL.bar = bar
  bar:SetFrameStrata("MEDIUM")
  bar:SetPoint("TOP", UIParent, "TOP", 0, -150)
  bar:SetWidth(500)
  bar:SetHeight(46)
  bar:Hide()
  -- (a named frame for layout mode)
  local holder = CreateFrame("Frame", "pfFlightBar", UIParent)
  holder:SetPoint("TOP", UIParent, "TOP", 0, -150)
  holder:SetWidth(500)
  holder:SetHeight(46)
  bar:SetParent(holder)
  bar:ClearAllPoints()
  bar:SetPoint("CENTER", holder, "CENTER", 0, 0)
  if UpdateMovable then UpdateMovable(holder) end
  FL.holder = holder

  function FL.Update(now)
    local layout = pfUI.unlock and pfUI.unlock:IsShown()
    local view = On("enable") and FL.View(now) or nil
    if not view and layout then view = FL.Sample(now) end
    if not view then
      if bar:IsShown() then bar:Hide() end
      return
    end
    FL.Paint(bar, view)
    holder:SetWidth(bar:GetWidth())
    holder:SetHeight(bar:GetHeight())
    bar:SetAlpha(Num("alpha", 1))
    if not bar:IsShown() then bar:Show() end
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("CHAT_MSG_ADDON")
  ev:SetScript("OnEvent", function() if arg1 == PREFIX then FL.Receive(arg2, arg4) end end)
  ev:SetScript("OnUpdate", function()
    local now = GetTime()
    if (this.next or 0) > now then return end
    this.next = now + ((FL.now or FL.pending) and .05 or .25)
    FL.Tick(now)
    FL.Update(now)
  end)

  -- the taxi map: how long to each flight point, in its tooltip
  local enter = rawget(_G, "TaxiNodeOnButtonEnter")
  if type(enter) == "function" then
    _G.TaxiNodeOnButtonEnter = function(button)
      enter(button)
      if not On("enable") or not On("tooltip") then return end
      local b = button or _G.this
      local slot = b and b.GetID and b:GetID()
      if not slot then return end
      local ok, plan = pcall(FL.Plan, slot)
      if ok and plan and plan.total then
        local hops = table.getn(plan.names) - 2
        GameTooltip:AddLine("Flight time: " .. ((plan.learned or plan.exact) and "" or "about ") .. FL.Clock(plan.total)
          .. (hops > 0 and ("  (" .. hops .. (hops == 1 and " stop" or " stops") .. " on the way)") or ""), .4, .85, 1)
        GameTooltip:Show()
      end
    end
  end

  _G.SLASH_PFFLIGHT1 = "/flight"
  SlashCmdList["PFFLIGHT"] = function()
    if pfUI.gui and pfUI.octoui and pfUI.octoui.Options and pfUI.octoui.Options.Open then
      if not pfUI.gui:IsShown() then pfUI.gui:Show() end
      pfUI.octoui.Options:Open("flight")
    end
  end
end)
