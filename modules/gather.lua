pfUI:RegisterModule("gather", "vanilla", function ()
  -- pfUI Octo :: gathering finder (9 Nov 2026; Bread: "using the range finder
  -- for mobs for gathering which displayed what it was that was close to you,
  -- it'd just need a filter/rule function for priority ... saves having to
  -- look at the mini-map while doing routes to see if a node has spawned").
  -- ClassicAPI's ClosestGameObjectPosition(gameObjectID) gives the nearest
  -- object of one kind the client knows about (only what is in view range,
  -- which is what we want). This asks it for every herb and ore node you can
  -- gather, 2 times a second, and shows the nearest few in a small box:
  -- icon, name, yards and an arrow (ClassicAPI GetPlayerFacing).
  --   nodes     GF.NODES: name, profession, skill, game object IDs
  --   rules     per node Off / Show / Priority (C.gather.nodes keeps only the
  --             changes, "Name=state;"); priority nodes sort first and can
  --             ping when one comes into sight; "only what I can gather"
  --             reads your Herbalism / Mining skill
  --   axes      positions are compared in whatever order the client gives
  --             them: a node 1000s of yards off with x / y swapped close by
  --             means the two calls disagree, so they are swapped; the arrow
  --             learns which way is north from your own walking
  -- Without ClassicAPI the module does nothing (the page says why).
  -- Settings: C.gather; page "Gathering" (Quality of Life); /gather.
  local GF = {}
  pfUI.gather = GF
  local function G() return C.gather end
  local function On(key) return G()[key] == "1" end
  local function Num(key, d) return tonumber(G()[key]) or d end

  local HERB, ORE = "Herbalism", "Mining"
  GF.PROF = {
    [HERB] = { icon = "Interface\\Icons\\INV_Misc_Flower_02", color = { .35, .85, .35 } },
    [ORE] = { icon = "Interface\\Icons\\Trade_Mining", color = { .85, .7, .45 } },
  }
  -- { name, profession, skill, { game object IDs } }
  GF.NODES = {
    -- (9 Nov 2026) Kalimdor's starting zones use a second ID for the first
    -- herbs (user: Earthroot "20 yd when its next to me" in Durotar)
    { "Peacebloom", HERB, 1, { 1618, 3724 } },
    { "Silverleaf", HERB, 1, { 1617, 3725 } },
    { "Earthroot", HERB, 15, { 1619, 3726 } },
    { "Mageroyal", HERB, 50, { 1620, 3727 } },
    { "Briarthorn", HERB, 70, { 1621, 3729 } },
    { "Stranglekelp", HERB, 85, { 2045 } },
    { "Bruiseweed", HERB, 100, { 1622, 3730 } },
    { "Wild Steelbloom", HERB, 115, { 1623 } },
    { "Grave Moss", HERB, 120, { 1628 } },
    { "Kingsblood", HERB, 125, { 1624 } },
    { "Liferoot", HERB, 150, { 2041 } },
    { "Fadeleaf", HERB, 160, { 2042 } },
    { "Goldthorn", HERB, 170, { 2046 } },
    { "Khadgar's Whisker", HERB, 185, { 2043 } },
    { "Wintersbite", HERB, 195, { 2044 } },
    { "Firebloom", HERB, 205, { 2866 } },
    { "Purple Lotus", HERB, 210, { 142140 } },
    { "Arthas' Tears", HERB, 220, { 142141 } },
    { "Sungrass", HERB, 230, { 142142 } },
    { "Blindweed", HERB, 235, { 142143 } },
    { "Ghost Mushroom", HERB, 245, { 142144 } },
    { "Gromsblood", HERB, 250, { 142145 } },
    { "Golden Sansam", HERB, 260, { 176583 } },
    { "Dreamfoil", HERB, 270, { 176584 } },
    { "Mountain Silversage", HERB, 280, { 176586 } },
    { "Plaguebloom", HERB, 285, { 176587 } },
    { "Icecap", HERB, 290, { 176588 } },
    { "Black Lotus", HERB, 300, { 176589 } },
    { "Copper Vein", ORE, 1, { 1731, 2055, 3763, 103713 } },
    { "Tin Vein", ORE, 65, { 1732, 3764, 103711 } },
    { "Incendicite Mineral Vein", ORE, 65, { 1610 } },
    { "Silver Vein", ORE, 75, { 1733, 105569 } },
    { "Ooze Covered Silver Vein", ORE, 75, { 73940 } },
    { "Lesser Bloodstone Deposit", ORE, 75, { 2653 } },
    { "Iron Deposit", ORE, 125, { 1735 } },
    { "Indurium Mineral Vein", ORE, 150, { 19903 } },
    { "Gold Vein", ORE, 155, { 1734, 150080, 181109 } },
    { "Ooze Covered Gold Vein", ORE, 155, { 73941 } },
    { "Mithril Deposit", ORE, 175, { 2040, 150079, 176645 } },
    { "Ooze Covered Mithril Deposit", ORE, 175, { 123310 } },
    { "Truesilver Deposit", ORE, 230, { 2047, 150081, 181108 } },
    { "Ooze Covered Truesilver Deposit", ORE, 230, { 123309 } },
    { "Dark Iron Deposit", ORE, 230, { 165658 } },
    { "Small Thorium Vein", ORE, 245, { 324, 150082, 176643 } },
    { "Ooze Covered Thorium Vein", ORE, 245, { 123848 } },
    { "Hakkari Thorium Vein", ORE, 250, { 180215 } },
    { "Rich Thorium Vein", ORE, 275, { 175404 } },
    { "Ooze Covered Rich Thorium Vein", ORE, 275, { 177388 } },
    { "Small Obsidian Chunk", ORE, 305, { 181068 } },
    { "Large Obsidian Chunk", ORE, 305, { 181069 } },
  }
  GF.BYNAME = {}
  for i = 1, table.getn(GF.NODES) do GF.BYNAME[GF.NODES[i][1]] = GF.NODES[i] end

  -- (9 Nov 2026, user: "look at the pf database addon ... this should show
  -- all new nodes in octowow for all profs") pfQuest's database, with its
  -- Turtle / OctoWoW add-on merged in, lists every herb, mine, fishing pool
  -- and chest object by ID with the skill it needs. When it is loaded its
  -- lists are added to the ones above (names from its own object names).
  local FISH, CHEST = "Fishing", "Chests"
  GF.FISH, GF.CHEST, GF.HERB, GF.ORE = FISH, CHEST, HERB, ORE
  GF.PROF[FISH] = { icon = "Interface\\Icons\\Trade_Fishing", color = { .45, .75, 1 } }
  GF.PROF[CHEST] = { icon = "Interface\\Icons\\INV_Box_01", color = { 1, .82, .4 } }
  GF.SWITCH = { [HERB] = "herbs", [ORE] = "ore", [FISH] = "fish", [CHEST] = "chests" }
  GF.DBLISTS = { herbs = HERB, mines = ORE, fish = FISH, chests = CHEST }
  function GF.LoadDB()
    if GF.dbLoaded then return GF.dbLoaded end
    local db = _G.pfDB
    local meta = type(db) == "table" and db.meta
    local objs = type(db) == "table" and db.objects
    if type(meta) ~= "table" or type(objs) ~= "table" then return false end
    local names = objs.loc or objs.enUS or {}
    local more = objs["enUS-turtle"]
    local added = 0
    for list, prof in pairs(GF.DBLISTS) do
      local t = meta[list]
      if type(t) == "table" then
        for key, skill in pairs(t) do
          local id = tonumber(key)
          if id then id = math.abs(id) end
          local name = id and (names[id] or (more and more[id]))
          if type(name) == "table" then name = name[1] end
          if type(name) == "string" and name ~= "" then
            skill = tonumber(skill) or 0
            local n = GF.BYNAME[name]
            if not n then
              n = { name, prof, skill, {} }
              table.insert(GF.NODES, n)
              GF.BYNAME[name] = n
            end
            if skill < n[3] then n[3] = skill end
            local have
            for j = 1, table.getn(n[4]) do if n[4][j] == id then have = true end end
            if not have then table.insert(n[4], id) added = added + 1 end
          end
        end
      end
    end
    table.sort(GF.NODES, function(a, b)
      if a[2] ~= b[2] then return a[2] < b[2] end
      if a[3] ~= b[3] then return a[3] < b[3] end
      return a[1] < b[1]
    end)
    GF.dbLoaded = added > 0 and added or true
    GF.wantKey = nil
    return GF.dbLoaded
  end
  GF.DEFAULTS = { ["Black Lotus"] = "prio" }
  GF.STATES = { { key = "off", label = "Off" }, { key = "show", label = "Show" }, { key = "prio", label = "Priority" } }

  -- ---------------------------------------------------------- the rules
  local parsedFrom, parsed
  local function Rules()
    local s = G().nodes or ""
    if s ~= parsedFrom then
      parsed = {}
      for name, state in string.gfind(s, "([^=;]+)=(%a+);?") do parsed[name] = state end
      parsedFrom = s
    end
    return parsed
  end
  function GF.State(name)
    return Rules()[name] or GF.DEFAULTS[name] or "show"
  end
  function GF.SetState(name, state)
    local r = Rules()
    if state == (GF.DEFAULTS[name] or "show") then state = nil end
    local out = ""
    local keys = {}
    for k in pairs(r) do if k ~= name then table.insert(keys, k) end end
    table.sort(keys)
    for i = 1, table.getn(keys) do out = out .. keys[i] .. "=" .. r[keys[i]] .. ";" end
    if state then out = out .. name .. "=" .. state .. ";" end
    G().nodes = out
  end
  -- extra IDs typed by the user: "12345=Name, 67890" (a name is optional)
  local extraFrom, extra
  function GF.Extra()
    local s = G().extra or ""
    if s ~= extraFrom then
      extra = {}
      for part in string.gfind(s, "[^,]+") do
        local _, _, id, name = string.find(part, "^%s*(%d+)%s*=?%s*(.-)%s*$")
        id = tonumber(id)
        if id then table.insert(extra, { id = id, name = name ~= "" and name or nil }) end
      end
      extraFrom = s
    end
    return extra
  end

  -- IDs learned from your mouse: hovering a node whose ID the list does not
  -- have saves it (C.gather.learned "id=Name;"), so a zone's own copies of a
  -- node are found after you have pointed at one once
  local learnedFrom, learned
  function GF.Learned()
    local s = G().learned or ""
    if s ~= learnedFrom then
      learned = {}
      for id, name in string.gfind(s, "(%d+)=([^;]+);") do
        learned[name] = learned[name] or {}
        table.insert(learned[name], tonumber(id))
      end
      learnedFrom = s
    end
    return learned
  end
  function GF.Known(id)
    for i = 1, table.getn(GF.NODES) do
      local ids = GF.NODES[i][4]
      for j = 1, table.getn(ids) do if ids[j] == id then return true end end
    end
    for _, ids in pairs(GF.Learned()) do
      for j = 1, table.getn(ids) do if ids[j] == id then return true end end
    end
    return false
  end
  -- an object's ID from what GameTooltip:GetGameObject() gives: a number,
  -- or a GUID string (0x + 4 high + 6 entry + 6 counter hex digits)
  function GF.IdFrom(v)
    if type(v) == "number" then
      if v > 0 and v < 16777216 and math.floor(v) == v then return v end
    elseif type(v) == "string" then
      local h = string.gsub(v, "^0[xX]", "")
      if string.len(h) == 16 and string.find(h, "^%x+$") then
        local e = tonumber(string.sub(h, 5, 10), 16)
        if e and e > 0 then return e end
      elseif string.find(h, "^%d+$") then
        return GF.IdFrom(tonumber(h))
      end
    end
  end
  function GF.Teach(name, a, b, c)
    if not GF.BYNAME[name] then return nil end
    local id = GF.IdFrom(a) or GF.IdFrom(b) or GF.IdFrom(c)
    if not id or GF.Known(id) then return nil end
    G().learned = (G().learned or "") .. id .. "=" .. name .. ";"
    return id
  end
  local lastTip
  local function WatchTooltip()
    local tt = _G.GameTooltip
    if not tt or not tt:IsShown() or type(tt.GetGameObject) ~= "function" then lastTip = nil return end
    local line = _G.GameTooltipTextLeft1 and _G.GameTooltipTextLeft1:GetText()
    if not line or line == lastTip then return end
    lastTip = line
    if not GF.BYNAME[line] then return end
    local ok, a, b, c = pcall(tt.GetGameObject, tt)
    if ok then GF.Teach(line, a, b, c) end
  end

  -- your skill in a profession, nil when you don't have it
  local skillAt, skills = -10, {}
  function GF.Skill(prof, now)
    now = now or GetTime()
    if now - skillAt > 10 and type(_G.GetNumSkillLines) == "function" then
      skillAt, skills = now, {}
      for i = 1, (tonumber(_G.GetNumSkillLines()) or 0) do
        local name, header, _, rank = _G.GetSkillLineInfo(i)
        if name and not header then skills[name] = tonumber(rank) or 0 end
      end
    end
    return skills[prof]
  end
  function GF.ResetSkills() skillAt = -10 GF.wantKey = nil end
  GF.BATCH = 80

  -- the list asked for: { node, id, name } entries passing the rules
  function GF.Wanted(now)
    local list = {}
    local mine = On("skill")
    for i = 1, table.getn(GF.NODES) do
      local n = GF.NODES[i]
      local state = GF.State(n[1])
      local prof = n[2]
      local ok = state ~= "off" and GF.SWITCH[prof] and On(GF.SWITCH[prof])
      if ok and mine and prof ~= CHEST then
        local s = GF.Skill(prof, now)
        ok = s and s >= n[3]
      end
      if ok then
        for j = 1, table.getn(n[4]) do table.insert(list, { id = n[4][j], name = n[1], prof = prof, prio = state == "prio" }) end
        local more = GF.Learned()[n[1]]
        if more then
          for j = 1, table.getn(more) do table.insert(list, { id = more[j], name = n[1], prof = prof, prio = state == "prio" }) end
        end
      end
    end
    local ex = GF.Extra()
    for i = 1, table.getn(ex) do
      table.insert(list, { id = ex[i].id, name = ex[i].name or GF.ObjectName(ex[i].id) or ("Object " .. ex[i].id), extra = true })
    end
    return list
  end
  -- the same list, made again only when a setting or your skills change
  -- (or every 10 s): with pfQuest's lists it is hundreds of entries
  function GF.WantedCached(now)
    local g = G()
    local key = (g.nodes or "") .. "|" .. (g.extra or "") .. "|" .. (g.learned or "") .. "|" .. (g.skill or "")
      .. (g.herbs or "") .. (g.ore or "") .. (g.fish or "") .. (g.chests or "")
    if key ~= GF.wantKey or not GF.wantList or now - (GF.wantAt or 0) > 10 then
      local changed = key ~= GF.wantKey
      GF.wantKey, GF.wantAt = key, now
      local old = GF.wantList
      GF.wantList = GF.Wanted(now)
      -- a different list starts the batches over
      if changed or not old or table.getn(old) ~= table.getn(GF.wantList) then GF.cursor, GF.cache = 1, {} end
    end
    return GF.wantList
  end

  -- ---------------------------------------------------------- the client
  local function Finder()
    if type(_G.ClosestGameObjectPosition) == "function" then return _G.ClosestGameObjectPosition end
    local c = _G.C_GameObjectInfo
    if type(c) == "table" and type(c.ClosestGameObjectPosition) == "function" then return c.ClosestGameObjectPosition end
  end
  function GF.Available() return Finder() and type(_G.UnitPosition) == "function" and true or false end
  function GF.ObjectName(id)
    local c = _G.C_GameObjectInfo
    local fn = type(c) == "table" and c.GetGameObjectInfoByID
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, id)
    if not ok then return nil end
    if type(a) == "string" then return a end
    if type(a) == "table" then return a.name or a.Name end
  end
  local function Pos()
    local ok, x, y, z = pcall(_G.UnitPosition, "player")
    x, y = tonumber(x), tonumber(y)
    if ok and x and y then return x, y, tonumber(z) or 0 end
  end
  function GF.Facing()
    if type(_G.GetPlayerFacing) ~= "function" then return nil end
    local ok, f = pcall(_G.GetPlayerFacing)
    return ok and tonumber(f) or nil
  end
  -- GF.swap: the node calls give x / y the other way round from UnitPosition
  -- (nil: not known yet). Decided by the first node seen: whichever order
  -- puts it in view range.
  GF.swap = nil
  local RANGE = 250
  function GF.Locate(id, px, py, pz)
    local ok, a, b, c = pcall(Finder(), id)
    a, b = tonumber(a), tonumber(b)
    if not ok or not a or not b then return nil end
    -- (9 Nov 2026, /gather probe in game) the answer is y, x, distance - the
    -- third number is NOT the node's height (used as one, a node at your feet
    -- showed 13 yd). Distances are on the map, flat: nodes sit on the ground.
    GF.lastDistance = tonumber(c)
    if GF.swap == nil then
      local d1 = (a - px) * (a - px) + (b - py) * (b - py)
      local d2 = (b - px) * (b - px) + (a - py) * (a - py)
      if d1 <= RANGE * RANGE then GF.swap = false
      elseif d2 <= RANGE * RANGE then GF.swap = true end
    end
    if GF.swap then a, b = b, a end
    local dx, dy = a - px, b - py
    local d = math.sqrt(dx * dx + dy * dy)
    if d > RANGE then return nil end
    return d, dx, dy, a, b
  end

  -- which way is north: the four ways a client can lay out x / y; your own
  -- forward walking votes for the one that matches GetPlayerFacing
  GF.AXES = {
    function(dx, dy) return math.atan2(dy, dx) end,
    function(dx, dy) return math.atan2(dx, dy) end,
    function(dx, dy) return math.atan2(-dy, dx) end,
    function(dx, dy) return math.atan2(-dx, dy) end,
  }
  GF.votes = { 0, 0, 0, 0 }
  GF.axis = 1
  local function Wrap(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
  end
  GF.Wrap = Wrap
  local lastX, lastY
  function GF.Learn(x, y, facing)
    if not x or not facing then return end
    if not lastX then lastX, lastY = x, y return end
    local dx, dy = x - lastX, y - lastY
    if dx * dx + dy * dy < 4 then return end
    lastX, lastY = x, y
    if dx * dx + dy * dy > 400 then return end -- a port, not a step
    for i = 1, 4 do
      if math.abs(Wrap(GF.AXES[i](dx, dy) - facing)) < .35 then GF.votes[i] = GF.votes[i] + 1 end
    end
    local best = GF.axis
    for i = 1, 4 do if GF.votes[i] > GF.votes[best] + 2 then best = i end end
    GF.axis = best
  end
  -- the arrow's turn (radians, counterclockwise; 0 = straight ahead)
  function GF.Turn(dx, dy, facing)
    if not facing then return nil end
    return Wrap(GF.AXES[GF.axis](dx, dy) - facing)
  end

  -- ---------------------------------------------------------- one look
  GF.found, GF.seen = {}, {}
  function GF.Scan(now)
    local found = {}
    if not GF.Available() then GF.found = found return found end
    local px, py, pz = Pos()
    if not px then GF.found = found return found end
    local facing = GF.Facing()
    GF.Learn(px, py, facing)
    local best = {}
    local list = GF.WantedCached(now)
    local n = table.getn(list)
    -- a batch of the list each look (GF.BATCH calls), the rest remembered
    -- from earlier looks: pfQuest's lists hold hundreds of IDs
    GF.cache = GF.cache or {}
    local cache = GF.cache
    local cursor = GF.cursor or 1
    for _ = 1, math.min(n, GF.BATCH) do
      if cursor > n then cursor = 1 end
      local _, _, _, nx, ny = GF.Locate(list[cursor].id, px, py, pz)
      cache[cursor] = nx and { nx, ny } or false
      cursor = cursor + 1
    end
    GF.cursor = cursor
    for i = 1, n do
      local c = cache[i]
      if c then
        local w = list[i]
        local dx, dy = c[1] - px, c[2] - py
        local d = math.sqrt(dx * dx + dy * dy)
        local cur = best[w.name]
        if d <= RANGE and (not cur or d < cur.dist) then
          best[w.name] = { name = w.name, prof = w.prof, prio = w.prio, extra = w.extra, dist = d, turn = GF.Turn(dx, dy, facing),
            x = c[1], y = c[2] }
        end
      end
    end
    for _, e in pairs(best) do table.insert(found, e) end
    table.sort(found, function(a, b)
      if a.prio ~= b.prio then return a.prio and true or false end
      return a.dist < b.dist
    end)
    -- a priority node that was not in sight last look
    local seen = {}
    for i = 1, table.getn(found) do
      local e = found[i]
      seen[e.name] = true
      if e.prio and not GF.seen[e.name] then GF.Alert(e) end
    end
    GF.seen = seen
    GF.found = found
    -- (kept for the world map: "nodes remembered" below)
    if GF.RecordFound then GF.RecordFound(px, py) end
    return found
  end

  function GF.Alert(e)
    GF.lastAlert = e.name
    if not On("alert") then return end
    if On("sound") and type(_G.PlaySoundFile) == "function" then _G.PlaySoundFile("Sound\\Interface\\MapPing.wav") end
    if On("chat") and DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo:|r |cffffd100" .. e.name .. "|r in sight, " .. math.floor(e.dist + .5) .. " yd")
    end
    if GF.frame then GF.frame.flash = GetTime() + 1.5 end
  end

  -- ---------------------------------------------------------- the box
  local ROWH = 18
  local function Rotate(tex, a)
    local s, c = math.sin(a), math.cos(a)
    local h = .3536
    tex:SetTexCoord(.5 + h * (s - c), .5 - h * (s + c), .5 - h * (c + s), .5 + h * (c - s),
      .5 + h * (c + s), .5 - h * (c - s), .5 + h * (c - s), .5 + h * (s + c))
  end
  GF.Rotate = Rotate

  local function Make()
    local f = CreateFrame("Frame", "pfGatherFinder", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetWidth(Num("width", 190))
    f:SetHeight(ROWH + 6)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    CreateBackdrop(f, nil, true)
    f.rows = {}
    for i = 1, 5 do
      local r = CreateFrame("Frame", nil, f)
      r:SetHeight(ROWH)
      r:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3 - (i - 1) * ROWH)
      r:SetPoint("RIGHT", f, "RIGHT", -3, 0)
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetWidth(ROWH - 2) r.icon:SetHeight(ROWH - 2)
      r.icon:SetPoint("LEFT", r, "LEFT", 1, 0)
      r.icon:SetTexCoord(.08, .92, .08, .92)
      r.arrow = r:CreateTexture(nil, "OVERLAY")
      r.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
      r.arrow:SetWidth(ROWH + 4) r.arrow:SetHeight(ROWH + 4)
      r.arrow:SetPoint("RIGHT", r, "RIGHT", 2, 0)
      r.dist = r:CreateFontString(nil, "OVERLAY")
      r.dist:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      r.dist:SetPoint("RIGHT", r.arrow, "LEFT", 0, 0)
      r.dist:SetJustifyH("RIGHT")
      r.name = r:CreateFontString(nil, "OVERLAY")
      r.name:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
      r.name:SetPoint("RIGHT", r.dist, "LEFT", -4, 0)
      r.name:SetJustifyH("LEFT")
      r:Hide()
      f.rows[i] = r
    end
    f.empty = f:CreateFontString(nil, "OVERLAY")
    f.empty:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    f.empty:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.empty:SetTextColor(.6, .6, .6)
    f:Hide()
    UpdateMovable(f)
    GF.frame = f
    return f
  end

  function GF.Draw()
    local f = GF.frame or Make()
    local found = GF.found
    local n = math.min(table.getn(found), Num("rows", 3), 5)
    f:SetWidth(Num("width", 190))
    if n == 0 and On("hideempty") and not GF.preview then f:Hide() return end
    for i = 1, 5 do
      local r, e = f.rows[i], found[i]
      if i <= n and e then
        local p = GF.PROF[e.prof]
        r.icon:SetTexture(p and p.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local col = p and p.color or { .8, .8, .8 }
        r.name:SetText(e.name)
        if e.prio then r.name:SetTextColor(1, .82, 0) else r.name:SetTextColor(col[1], col[2], col[3]) end
        r.yd = math.floor(e.dist + .5)
        r.dist:SetText(r.yd .. " yd")
        if e.turn then Rotate(r.arrow, e.turn) r.arrow:Show() else r.arrow:Hide() end
        r:Show()
      else
        r:Hide()
      end
    end
    if n == 0 then f.empty:SetText("No nodes in sight") f.empty:Show() else f.empty:Hide() end
    f:SetHeight(math.max(n, 1) * ROWH + 6)
    f:Show()
  end

  -- (9 Nov 2026, user: "the arrows should move smoothly not in jumps") the
  -- nodes are looked for a few times a second, but their distance and arrow
  -- follow your position and facing every frame
  function GF.Follow()
    local f = GF.frame
    if not f or not f:IsShown() or GF.preview then return end
    local px, py, pz = Pos()
    if not px then return end
    local facing = GF.Facing()
    for i = 1, 5 do
      local r, e = f.rows[i], GF.found[i]
      if r:IsShown() and e and e.x then
        local dx, dy = e.x - px, e.y - py
        e.dist = math.sqrt(dx * dx + dy * dy)
        e.turn = GF.Turn(dx, dy, facing)
        -- (new text only when the yards change: a string a frame per row was garbage)
        local yd = math.floor(e.dist + .5)
        if r.yd ~= yd then r.yd = yd r.dist:SetText(yd .. " yd") end
        if e.turn then Rotate(r.arrow, e.turn) r.arrow:Show() else r.arrow:Hide() end
      end
    end
  end

  -- a made-up list for the options page
  function GF.Preview(on)
    GF.preview = on
    if on then
      GF.found = {
        { name = "Black Lotus", prof = HERB, prio = true, dist = 84, turn = .6 },
        { name = "Mithril Deposit", prof = ORE, dist = 31, turn = -1.2 },
        { name = "Sungrass", prof = HERB, dist = 57, turn = 2.5 },
      }
    end
    GF.Draw()
  end

  -- ---------------------------------------------------------- driving it
  local driver = CreateFrame("Frame", "pfGatherDriver", UIParent)
  local nextAt = 0
  function GF.Tick(now)
    if not On("enable") then
      if GF.frame and not GF.preview then GF.frame:Hide() end
      -- (the box is off but nodes are still remembered for the map: a look a second)
      if On("record") and not GF.preview and GF.Available() and now >= nextAt then
        nextAt = now + 1
        if not ((_G.UnitOnTaxi and _G.UnitOnTaxi("player")) or (_G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost("player"))) then GF.Scan(now) end
      end
      return
    end
    if now < nextAt then return end
    nextAt = now + 1 / math.max(.5, math.min(5, Num("rate", 2)))
    if (_G.UnitOnTaxi and _G.UnitOnTaxi("player")) or (_G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost("player")) then
      GF.found = {}
    elseif not GF.preview then
      GF.Scan(now)
    end
    GF.Draw()
  end
  driver:SetScript("OnUpdate", function()
    if not On("enable") and not GF.preview then
      if GF.frame and GF.frame:IsShown() then GF.frame:Hide() end
      if On("record") then GF.Tick(GetTime()) end
      return
    end
    GF.Tick(GetTime())
    GF.Follow()
    WatchTooltip()
  end)
  driver:RegisterEvent("SKILL_LINES_CHANGED")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:SetScript("OnEvent", function()
    GF.ResetSkills()
    if event == "PLAYER_ENTERING_WORLD" then GF.swap = nil GF.cache = {} GF.LoadDB() end
  end)

  -- ---------------------------------------------------------------- nodes remembered
  -- (14 Nov 2026; Khijazi: Herbs & Flowers shows nothing in Moonwhisper Coast - the quest database has
  -- no herb spawns for the new zones; user: "record nodes".) Every node the finder sees is kept with its
  -- place in the world (pfUI_cache.gathernodes[zone], for every character) and drawn on the world map.
  --   zone   continent:zone of the map while it is shut (then it is the zone you are in)
  --   fit    where a world position is on that zone's map: learnt from your own position, which the
  --          game gives both ways (UnitPosition and GetPlayerMapPosition). Each map axis follows one
  --          world axis in a straight line; a few samples 20 yd apart across 40 yd of each axis give
  --          it. Until then nodes are kept all the same and show once the zone is known.
  --   pins   a small flower / pick / fish on the world map; hover = the node's name
  local SAME, STEP, SPREAD = 6, 20, 40
  local function Store()
    pfUI_cache.gathernodes = pfUI_cache.gathernodes or {}
    return pfUI_cache.gathernodes
  end
  function GF.ZoneKey()
    if WorldMapFrame and WorldMapFrame:IsShown() then return nil end
    local c, z = GetCurrentMapContinent and GetCurrentMapContinent(), GetCurrentMapZone and GetCurrentMapZone()
    if not c or not z or c <= 0 or z <= 0 then return nil end
    return c .. ":" .. z
  end
  local function Zone(key)
    local s = Store()
    s[key] = s[key] or { nodes = {}, samples = {} }
    return s[key]
  end

  -- a straight line m = a * w + c through pairs { w, m }: a, c, worst miss, spread of w
  local function Line(list, wi, mi)
    local n = table.getn(list)
    local sw, sm, lo, hi = 0, 0, nil, nil
    for i = 1, n do
      local w, m = list[i][wi], list[i][mi]
      sw, sm = sw + w, sm + m
      if not lo or w < lo then lo = w end
      if not hi or w > hi then hi = w end
    end
    local mw, mm = sw / n, sm / n
    local cov, var = 0, 0
    for i = 1, n do
      local dw = list[i][wi] - mw
      cov = cov + dw * (list[i][mi] - mm)
      var = var + dw * dw
    end
    if var <= 0 then return nil end
    local a = cov / var
    local c = mm - a * mw
    local miss = 0
    for i = 1, n do miss = math.max(miss, math.abs(a * list[i][wi] + c - list[i][mi])) end
    return a, c, miss, (hi - lo)
  end
  -- the zone's fit from its samples { wx, wy, mx, my }: which world axis each map axis follows
  function GF.Fit(samples)
    if table.getn(samples) < 4 then return nil end
    local best, fits = nil, 0
    for _, try in ipairs({ { 1, 2 }, { 2, 1 } }) do
      local ax, cx, mx, sx = Line(samples, try[1], 3)
      local ay, cy, my, sy = Line(samples, try[2], 4)
      if ax and ay and sx >= SPREAD and sy >= SPREAD then
        local miss = math.max(mx, my)
        if miss < .004 then fits = fits + 1 end
        if miss < .004 and (not best or miss < best.miss) then
          best = { xi = try[1], yi = try[2], ax = ax, cx = cx, ay = ay, cy = cy, miss = miss }
        end
      end
    end
    -- (walked in one straight line both ways round fit: not known yet, until you turn)
    if fits > 1 then return nil end
    return best
  end
  function GF.ToMap(fit, wx, wy)
    local w = { wx, wy }
    return fit.ax * w[fit.xi] + fit.cx, fit.ay * w[fit.yi] + fit.cy
  end

  -- your own position, both ways, for the zone's fit
  function GF.Sample(key, px, py)
    local z = Zone(key)
    if z.fit and table.getn(z.samples) >= 12 then return end
    local mx, my = GetPlayerMapPosition("player")
    if not mx or not my or (mx == 0 and my == 0) then return end
    for _, s in ipairs(z.samples) do
      local dx, dy = s[1] - px, s[2] - py
      if dx * dx + dy * dy < STEP * STEP then return end
    end
    table.insert(z.samples, { px, py, mx, my })
    if table.getn(z.samples) > 40 then table.remove(z.samples, 1) end
    z.fit = GF.Fit(z.samples) or z.fit
  end

  -- a node seen at a world position: new, or one already kept
  function GF.Remember(key, name, prof, wx, wy, from)
    local z = Zone(key)
    for _, n in ipairs(z.nodes) do
      if n[1] == name then
        local dx, dy = n[3] - wx, n[4] - wy
        if dx * dx + dy * dy < SAME * SAME then return false end
      end
    end
    table.insert(z.nodes, { name, prof, wx, wy, from })
    GF.pinsDirty = true
    if not from and GF.Tell then GF.Tell(key, name, prof, wx, wy) end
    return true
  end
  function GF.RecordFound(px, py)
    if not On("record") then return end
    local key = GF.ZoneKey()
    if not key then return end
    GF.Sample(key, px, py)
    for _, e in ipairs(GF.found or {}) do
      if e.x and e.y and not e.fake then GF.Remember(key, e.name, e.prof, e.x, e.y) end
    end
  end
  function GF.Count()
    local zones, nodes = 0, 0
    for _, z in pairs(Store()) do
      if table.getn(z.nodes) > 0 then zones = zones + 1 nodes = nodes + table.getn(z.nodes) end
    end
    return nodes, zones
  end
  function GF.Forget(all)
    if all then pfUI_cache.gathernodes = {} else
      local key = GF.ZoneKey()
      if key then Store()[key] = nil end
    end
    GF.pinsDirty = true
  end

  -- the pins on the world map (the zone it is showing)
  local PINICON = { [HERB] = "Interface\\Icons\\INV_Misc_Flower_02", [ORE] = "Interface\\Icons\\Trade_Mining" }
  local pinHost = WorldMapButton and CreateFrame("Frame", "pfGatherPins", WorldMapButton)
  GF.pins = {}
  local function Pin(i)
    local p = GF.pins[i]
    if p then return p end
    p = CreateFrame("Button", nil, pinHost)
    p:SetFrameLevel((pinHost:GetFrameLevel() or 1) + 3)
    p.tex = p:CreateTexture(nil, "OVERLAY")
    p.tex:SetAllPoints(p)
    p.tex:SetTexCoord(.08, .92, .08, .92)
    p:SetScript("OnEnter", function()
      WorldMapTooltip:SetOwner(this, "ANCHOR_RIGHT")
      WorldMapTooltip:AddLine(this.name)
      WorldMapTooltip:AddLine(this.from and ("Seen here by " .. this.from) or "Seen here by pfUI's gathering finder", .7, .7, .7)
      WorldMapTooltip:AddLine("Hide these: the Marks button at the map's bottom left", .45, .7, 1)
      WorldMapTooltip:Show()
    end)
    p:SetScript("OnLeave", function() WorldMapTooltip:Hide() end)
    GF.pins[i] = p
    return p
  end
  function GF.DrawPins()
    if not pinHost then return 0 end
    local shown = 0
    local c, z = GetCurrentMapContinent(), GetCurrentMapZone()
    local zone = (On("mappins") and c and z and z > 0) and Store()[c .. ":" .. z] or nil
    if zone and zone.fit then
      local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
      local size = Num("pinsize", 12)
      for _, n in ipairs(zone.nodes) do
        local mx, my = GF.ToMap(zone.fit, n[3], n[4])
        if mx > 0 and mx < 1 and my > 0 and my < 1 and shown < 400 and GF.PinKind(n[2]) then
          shown = shown + 1
          local p = Pin(shown)
          p.name, p.from = n[1], n[5]
          p.tex:SetTexture(PINICON[n[2]] or (GF.PROF[n[2]] and GF.PROF[n[2]].icon) or "Interface\\Icons\\INV_Misc_Bag_10")
          p:SetWidth(size)
          p:SetHeight(size)
          p:ClearAllPoints()
          p:SetPoint("CENTER", WorldMapButton, "TOPLEFT", mx * w, -my * h)
          p:Show()
        end
      end
    end
    for i = shown + 1, table.getn(GF.pins) do GF.pins[i]:Hide() end
    return shown
  end
  if pinHost then
    pinHost:SetAllPoints(WorldMapButton)
    pinHost:RegisterEvent("WORLD_MAP_UPDATE")
    pinHost:SetScript("OnEvent", function() GF.pinsDirty = true end)
    pinHost:SetScript("OnShow", function() GF.pinsDirty = true end)
    pinHost:SetScript("OnUpdate", function()
      if not GF.pinsDirty then return end
      GF.pinsDirty = nil
      GF.DrawPins()
    end)
  end
  -- the map shows the zone you are in whenever it is shut (for the zone key and your map position)
  local zoneWatch = CreateFrame("Frame")
  zoneWatch:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  zoneWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
  zoneWatch:SetScript("OnEvent", function()
    if On("record") and SetMapToCurrentZone and not (WorldMapFrame and WorldMapFrame:IsShown()) then SetMapToCurrentZone() end
    GF.askAt = GetTime() + 8
  end)

  -- ---------------------------------------------------------------- nodes shared
  -- (15 Nov 2026; user: "share nodes" - no database has Moonwhisper's herbs, so one player's walk
  -- should fill the map for the others.) Over the addon channel (guild, and raid or party), prefix pfGN:
  --   N|locale|zone|name|prof|wx|wy            a node just found
  --   Q|locale|zone|count|fit                  entering a zone: how many I have, 1 = I can place them
  --   D|locale|zone|name~prof~wx~wy;...        an answer in parts, from one who has more (after 1-4 s,
  --                                            dropped when someone else answers first)
  --   F|locale|zone|xi|yi|ax|cx|ay|cy          the zone's fit, for one who has none yet
  -- World positions are the same for everyone; zone numbers follow the client's language, so another
  -- language is ignored. Everything received is checked (numbers, lengths, how many).
  local PREFIX, GAP, ZONEMAX, ASKEVERY = "pfGN", .35, 1500, 600
  local out, sendAt, replies = {}, 0, {}
  GF.asked, GF.got = {}, 0
  local function Split(text, sep)
    local list = {}
    for part in string.gfind(text .. sep, "(.-)" .. sep) do table.insert(list, part) end
    return list
  end
  local function Channels()
    local list = {}
    if IsInGuild and IsInGuild() then table.insert(list, "GUILD") end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then table.insert(list, "RAID")
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then table.insert(list, "PARTY") end
    return list
  end
  local function Sharing() return On("record") and On("share") and type(SendAddonMessage) == "function" end
  local function Queue(msg)
    if table.getn(out) < 400 then table.insert(out, msg) end
  end
  local function Locale() return GetLocale and GetLocale() or "enUS" end
  local function NodeText(n) return n[1] .. "~" .. n[2] .. "~" .. string.format("%.0f", n[3]) .. "~" .. string.format("%.0f", n[4]) end
  function GF.Tell(key, name, prof, wx, wy)
    if not Sharing() then return end
    Queue("N^" .. Locale() .. "^" .. key .. "^" .. NodeText({ name, prof, wx, wy }))
  end
  function GF.Ask(force)
    if not Sharing() then return false end
    local key = GF.ZoneKey()
    if not key then return false end
    local now = GetTime()
    if not force and GF.asked[key] and now - GF.asked[key] < ASKEVERY then return true end
    GF.asked[key] = now
    local z = Store()[key]
    Queue("Q^" .. Locale() .. "^" .. key .. "^" .. (z and table.getn(z.nodes) or 0) .. "^" .. ((z and z.fit) and 1 or 0))
    return true
  end
  -- a zone's nodes (and fit) as messages
  function GF.Pack(key, withFit)
    local z = Store()[key]
    local list = {}
    if not z then return list end
    local f = z.fit
    if withFit and f then
      table.insert(list, "F^" .. Locale() .. "^" .. key .. "^" .. f.xi .. "^" .. f.yi .. "^" .. f.ax .. "^" .. f.cx .. "^" .. f.ay .. "^" .. f.cy)
    end
    local head = "D^" .. Locale() .. "^" .. key .. "^"
    local line = head
    for i = 1, math.min(table.getn(z.nodes), 600) do
      local t = NodeText(z.nodes[i])
      if string.len(line) + string.len(t) + 1 > 240 and line ~= head then
        table.insert(list, line)
        line = head
      end
      line = line .. (line == head and "" or ";") .. t
    end
    if line ~= head then table.insert(list, line) end
    return list
  end
  local function GoodNode(key, text, from)
    local p = Split(text, "~")
    local name, prof, wx, wy = p[1], p[2], tonumber(p[3]), tonumber(p[4])
    if not name or string.len(name) < 1 or string.len(name) > 48 or (string.find(name, "|", 1, true) or string.find(name, "^", 1, true)) then return false end
    if not (GF.PROF[prof] or prof == FISH or prof == CHEST) then return false end
    if not wx or not wy or math.abs(wx) > 20000 or math.abs(wy) > 20000 then return false end
    local z = Store()[key]
    if z and table.getn(z.nodes) >= ZONEMAX then return false end
    if GF.Remember(key, name, prof, wx, wy, from) then GF.got = GF.got + 1 return true end
    return false
  end
  function GF.Receive(msg, from)
    if not Sharing() or not msg or not from or from == UnitName("player") then return end
    local p = Split(msg, "^")
    local kind, loc, key = p[1], p[2], p[3]
    if loc ~= Locale() or not key or not string.find(key, "^%d+:%d+$") then return end
    if kind == "N" then
      GoodNode(key, p[4] or "", from)
    elseif kind == "D" then
      replies[key] = nil
      for _, t in ipairs(Split(p[4] or "", ";")) do GoodNode(key, t, from) end
    elseif kind == "F" then
      local z = Store()[key]
      local xi, yi, ax, cx, ay, cy = tonumber(p[4]), tonumber(p[5]), tonumber(p[6]), tonumber(p[7]), tonumber(p[8]), tonumber(p[9])
      if (not z or not z.fit) and ax and cx and ay and cy and ax ~= 0 and ay ~= 0
        and ((xi == 1 and yi == 2) or (xi == 2 and yi == 1)) and math.abs(ax) < 1 and math.abs(ay) < 1 then
        Zone(key).fit = { xi = xi, yi = yi, ax = ax, cx = cx, ay = ay, cy = cy, miss = 0, shared = from }
        GF.pinsDirty = true
      end
    elseif kind == "Q" then
      local z = Store()[key]
      if not z then return end
      local theirs, fit = tonumber(p[4]) or 0, p[5] == "1"
      local more = table.getn(z.nodes) > theirs
      if more or (z.fit and not fit) then
        replies[key] = { at = GetTime() + 1 + math.random() * 3, nodes = more, fit = z.fit and not fit }
      end
    end
  end
  function GF.ShareTick(now)
    if GF.askAt and now >= GF.askAt then
      GF.askAt = GF.Ask() and nil or (now + 5)
      if not Sharing() then GF.askAt = nil end
    end
    for key, r in pairs(replies) do
      if now >= r.at then
        replies[key] = nil
        local list = GF.Pack(key, r.fit)
        for _, m in ipairs(list) do
          if r.nodes or string.sub(m, 1, 1) == "F" then Queue(m) end
        end
        break
      end
    end
    if out[1] and now >= sendAt then
      sendAt = now + GAP
      local msg = table.remove(out, 1)
      for _, chan in ipairs(Channels()) do SendAddonMessage(PREFIX, msg, chan) end
    end
  end
  local share = CreateFrame("Frame")
  share:RegisterEvent("CHAT_MSG_ADDON")
  share:SetScript("OnEvent", function() if arg1 == PREFIX then GF.Receive(arg2, arg4) end end)
  share:SetScript("OnUpdate", function() GF.ShareTick(GetTime()) end)

  -- ---------------------------------------------------------------- marks on the map, switched on the map
  -- (15 Nov 2026; user: remembered herbs "are not hideable ... can we add toggles in the map frame for all
  -- these commands which are hard saved".) A "Marks" button on the world map opens a list of switches:
  -- our remembered nodes by kind (C.gather.pinherbs / pinore / pinfish) and every pfQuest tracking list
  -- (/db track <list>: pfDatabase:TrackMeta, kept by pfQuest in pfQuest_track). All stay as set.
  local PINKEY = { [HERB] = "pinherbs", [ORE] = "pinore", [FISH] = "pinfish" }
  function GF.PinKind(prof)
    local key = PINKEY[prof]
    return not key or G()[key] ~= "0"
  end
  GF.TRACKS = {
    { "herbs", "Herbs" }, { "mines", "Ore veins" }, { "fish", "Fishing pools" }, { "chests", "Chests" }, { "trees", "Trees" },
    { "rares", "Rare mobs" }, { "flight", "Flight masters" }, { "innkeeper", "Innkeepers" }, { "mailbox", "Mailboxes" },
    { "vendor", "Vendors" }, { "repair", "Repair" }, { "banker", "Bankers" }, { "auctioneer", "Auctioneers" },
    { "stablemaster", "Stable masters" }, { "battlemaster", "Battlemasters" }, { "meetingstone", "Meeting stones" },
    { "spirithealer", "Spirit healers" },
  }
  local function QuestDB() return rawget(_G, "pfDatabase"), rawget(_G, "pfDB"), rawget(_G, "pfQuest_track") end
  -- the switches: { key, label, icon, on (function), set (function) }
  function GF.MarkList()
    local list = {}
    -- one click for a clean map: every switch below off
    table.insert(list, { label = "Hide everything", action = function()
      for _, d in ipairs(GF.MarkList()) do
        if d.set and d.on() then d.set(false) end
      end
    end })
    table.insert(list, { head = "Seen by you and your guild" })
    for _, d in ipairs({ { "pinherbs", "Herbs", "Interface\\Icons\\INV_Misc_Flower_02" }, { "pinore", "Ore veins", "Interface\\Icons\\Trade_Mining" },
                         { "pinfish", "Fishing pools", "Interface\\Icons\\Trade_Fishing" } }) do
      local key = d[1]
      table.insert(list, { key = key, label = d[2], icon = d[3],
        on = function() return G().mappins == "1" and G()[key] ~= "0" end,
        set = function(v)
          G()[key] = v and "1" or "0"
          if v then G().mappins = "1" end
          GF.pinsDirty = true
        end })
    end
    local db, data, track = QuestDB()
    if type(db) == "table" and type(db.TrackMeta) == "function" and type(data) == "table" and type(data.meta) == "table" then
      table.insert(list, { head = "From the quest database" })
      local seen = {}
      local function Add(name, label)
        if seen[name] or not data.meta[name] then return end
        seen[name] = true
        local cfg = rawget(_G, "pfQuestConfig")
        local icon = (db.metaTrackingIcons and db.metaTrackingIcons[name]) or (((cfg and cfg.path) or "Interface\\AddOns\\pfUI\\pfquest") .. "\\img\\tracking\\" .. name)
        table.insert(list, { key = "db:" .. name, label = label, icon = icon,
          on = function() local t = rawget(_G, "pfQuest_track") return type(t) == "table" and t[name] and true or false end,
          set = function(v) pcall(db.TrackMeta, db, name, v and true or false) end })
      end
      for _, t in ipairs(GF.TRACKS) do Add(t[1], t[2]) end
      local rest = {}
      for name in pairs(data.meta) do if not seen[name] then table.insert(rest, name) end end
      table.sort(rest)
      for _, name in ipairs(rest) do Add(name, string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)) end
    end
    return list
  end
  local marks
  local function MarkRow(i)
    local r = marks.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, marks)
    r:SetHeight(18)
    r:SetPoint("TOPLEFT", marks, "TOPLEFT", 4, -4 - (i - 1) * 18)
    r:SetPoint("RIGHT", marks, "RIGHT", -4, 0)
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints(r)
    r.hl:SetTexture(1, 1, 1, .1)
    r.hl:Hide()
    r.box = r:CreateTexture(nil, "ARTWORK")
    r.box:SetWidth(10)
    r.box:SetHeight(10)
    r.box:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(14)
    r.icon:SetHeight(14)
    r.icon:SetPoint("LEFT", r, "LEFT", 20, 0)
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetFont(pfUI.font_default, 11, "OUTLINE")
    r.text:SetPoint("LEFT", r, "LEFT", 40, 0)
    r:SetScript("OnEnter", function() if this.d and not this.d.head then this.hl:Show() end end)
    r:SetScript("OnLeave", function() this.hl:Hide() end)
    r:SetScript("OnClick", function()
      local d = this.d
      if not d or d.head then return end
      if d.action then d.action() else d.set(not d.on()) end
      GF.PaintMarks()
    end)
    marks.rows[i] = r
    return r
  end
  function GF.PaintMarks()
    if not marks then return end
    local list = GF.MarkList()
    for i, d in ipairs(list) do
      local r = MarkRow(i)
      r.d = d
      if d.head then
        r.box:Hide() r.icon:Hide()
        r.text:ClearAllPoints()
        r.text:SetPoint("LEFT", r, "LEFT", 4, 0)
        r.text:SetText(d.head)
        r.text:SetTextColor(.6, .75, 1)
      elseif d.action then
        r.box:Hide() r.icon:Hide()
        r.text:ClearAllPoints()
        r.text:SetPoint("LEFT", r, "LEFT", 4, 0)
        r.text:SetText(d.label)
        r.text:SetTextColor(1, .45, .4)
      else
        local on = d.on()
        r.box:SetTexture(on and .3 or .5, on and .9 or .2, on and .4 or .2, 1)
        r.box:Show()
        r.icon:SetTexture(d.icon)
        if r.icon.SetDesaturated then r.icon:SetDesaturated(not on) end
        r.icon:SetAlpha(on and 1 or .5)
        r.icon:Show()
        r.text:ClearAllPoints()
        r.text:SetPoint("LEFT", r, "LEFT", 40, 0)
        r.text:SetText(d.label)
        if on then r.text:SetTextColor(1, 1, 1) else r.text:SetTextColor(.55, .55, .55) end
      end
      r:Show()
    end
    for i = table.getn(list) + 1, table.getn(marks.rows) do marks.rows[i]:Hide() end
    marks:SetHeight(table.getn(list) * 18 + 8)
    return list
  end
  if WorldMapButton then
    local btn = CreateFrame("Button", "pfMapMarksButton", WorldMapButton)
    GF.marksButton = btn
    btn:SetWidth(64)
    btn:SetHeight(20)
    -- (bottom left: the top left has Zoom Out, the top right pfQuest's menus, the bottom right the coordinates)
    btn:SetPoint("BOTTOMLEFT", WorldMapButton, "BOTTOMLEFT", 8, 8)
    btn:SetFrameLevel((WorldMapButton:GetFrameLevel() or 1) + 20)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btn:SetBackdropColor(0, 0, 0, .7)
    btn:SetBackdropBorderColor(.3, .3, .35, 1)
    btn.text = btn:CreateFontString(nil, "OVERLAY")
    btn.text:SetFont(pfUI.font_default, 11, "OUTLINE")
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.text:SetText("Marks")
    marks = CreateFrame("Frame", "pfMapMarks", btn)
    GF.marks = marks
    marks.rows = {}
    marks:SetWidth(190)
    marks:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
    marks:SetFrameLevel(btn:GetFrameLevel() + 2)
    marks:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    marks:SetBackdropColor(0, 0, 0, .85)
    marks:SetBackdropBorderColor(.3, .3, .35, 1)
    marks:EnableMouse(true)
    marks:Hide()
    btn:SetScript("OnClick", function()
      if marks:IsShown() then marks:Hide() else GF.PaintMarks() marks:Show() end
    end)
    btn:SetScript("OnEnter", function()
      WorldMapTooltip:SetOwner(this, "ANCHOR_RIGHT")
      WorldMapTooltip:AddLine("Marks on the map")
      WorldMapTooltip:AddLine("Switch herbs, ore, vendors and the rest on or off. They stay as you set them.", .7, .7, .7, 1)
      WorldMapTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() WorldMapTooltip:Hide() end)
    btn:SetScript("OnUpdate", function()
      local want = G().mapbutton ~= "0"
      if want ~= this.shownAs then
        this.shownAs = want
        this:SetAlpha(want and 1 or 0)
        this:EnableMouse(want)
        if not want then marks:Hide() end
      end
    end)
  end

  -- /gather probe: the raw answers, to check this client's call
  function GF.Probe()
    local out = DEFAULT_CHAT_FRAME
    if not out then return end
    if not Finder() then out:AddMessage("|cff33ffccGather:|r ClosestGameObjectPosition not found (needs ClassicAPI).") return end
    local px, py, pz = Pos()
    out:AddMessage("|cff33ffccGather:|r you at " .. tostring(px) .. ", " .. tostring(py) .. ", " .. tostring(pz)
      .. "  facing " .. tostring(GF.Facing()) .. "  swap " .. tostring(GF.swap) .. "  axis " .. GF.axis)
    local list, shown = GF.Wanted(GetTime()), 0
    for i = 1, table.getn(list) do
      local ok, a, b, c, d = pcall(Finder(), list[i].id)
      if ok and a ~= nil then
        out:AddMessage("  " .. list[i].name .. " (" .. list[i].id .. "): " .. tostring(a) .. ", " .. tostring(b) .. ", " .. tostring(c) .. ", " .. tostring(d))
        shown = shown + 1
        if shown >= 8 then break end
      end
    end
    if shown == 0 then out:AddMessage("  nothing you gather is in sight") end
  end

  _G.SLASH_PFGATHER1 = "/gather"
  _G.SlashCmdList["PFGATHER"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "probe" then GF.Probe()
    elseif msg == "on" then G().enable = "1"
    elseif msg == "off" then G().enable = "0"
    else
      local O = pfUI.octoui and pfUI.octoui.Options
      if O and O.Open then O:Open("gather") end
    end
  end
end)
