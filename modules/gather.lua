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
    { "Peacebloom", HERB, 1, { 1618 } },
    { "Silverleaf", HERB, 1, { 1617 } },
    { "Earthroot", HERB, 15, { 1619 } },
    { "Mageroyal", HERB, 50, { 1620 } },
    { "Briarthorn", HERB, 70, { 1621 } },
    { "Stranglekelp", HERB, 85, { 2045 } },
    { "Bruiseweed", HERB, 100, { 1622 } },
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
  function GF.ResetSkills() skillAt = -10 end

  -- the list asked for: { node, id, name } entries passing the rules
  function GF.Wanted(now)
    local list = {}
    local mine = On("skill")
    for i = 1, table.getn(GF.NODES) do
      local n = GF.NODES[i]
      local state = GF.State(n[1])
      local prof = n[2]
      local ok = state ~= "off" and ((prof == HERB and On("herbs")) or (prof == ORE and On("ore")))
      if ok and mine then
        local s = GF.Skill(prof, now)
        ok = s and s >= n[3]
      end
      if ok then
        for j = 1, table.getn(n[4]) do table.insert(list, { id = n[4][j], name = n[1], prof = prof, prio = state == "prio" }) end
      end
    end
    local ex = GF.Extra()
    for i = 1, table.getn(ex) do
      table.insert(list, { id = ex[i].id, name = ex[i].name or GF.ObjectName(ex[i].id) or ("Object " .. ex[i].id), extra = true })
    end
    return list
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
    c = tonumber(c) or pz
    if GF.swap == nil then
      local d1 = (a - px) * (a - px) + (b - py) * (b - py)
      local d2 = (b - px) * (b - px) + (a - py) * (a - py)
      if d1 <= RANGE * RANGE then GF.swap = false
      elseif d2 <= RANGE * RANGE then GF.swap = true end
    end
    if GF.swap then a, b = b, a end
    local dx, dy, dz = a - px, b - py, c - pz
    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
    if d > RANGE then return nil end
    return d, dx, dy
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
    local list = GF.Wanted(now)
    for i = 1, table.getn(list) do
      local w = list[i]
      local d, dx, dy = GF.Locate(w.id, px, py, pz)
      if d then
        local cur = best[w.name]
        if not cur or d < cur.dist then
          best[w.name] = { name = w.name, prof = w.prof, prio = w.prio, extra = w.extra, dist = d, turn = GF.Turn(dx, dy, facing) }
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
        r.dist:SetText(math.floor(e.dist + .5) .. " yd")
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
  driver:SetScript("OnUpdate", function() GF.Tick(GetTime()) end)
  driver:RegisterEvent("SKILL_LINES_CHANGED")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:SetScript("OnEvent", function()
    GF.ResetSkills()
    if event == "PLAYER_ENTERING_WORLD" then GF.swap = nil end
  end)

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

  SLASH_PFGATHER1 = "/gather"
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
