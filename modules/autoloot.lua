pfUI:RegisterModule("autoloot", "vanilla", function ()
  -- pfUI Octo :: automatic area looting (4 Nov 2026; user: the AutoAreaLoot
  -- addon "same features ... but make it better", in our UI). AutoAreaLoot has
  -- no licence, so this is written fresh from its feature list: ClassicAPI's
  -- C_Loot.LootAllCorpses does the looting; this module decides WHEN.
  --   triggers  a mob dies within loot range (nampower UNIT_DIED, else the
  --             combat log's death line), you stop moving, combat ends
  --   waits     while you move, cast, channel, are dead, hold a loot window
  --             open yourself, or a scan is still running; one request per
  --             burst (the strongest reason wins), a settle time after a scan
  --   log       items from your own loot messages + money gained, in a small
  --             window (pfAutoLootLog) with combine / timestamps / tooltips
  -- Settings: C.autoloot (strings "1" / "0", numbers); page "Auto Loot".
  local AL = {}
  pfUI.autoloot = AL
  local st = { events = {}, items = {}, money = 0, count = 0, settleUntil = 0, recordUntil = 0 }
  AL.state = st
  local function G() return C.autoloot end
  local function On(key) return G()[key] == "1" end
  local function Num(key, d) return tonumber(G()[key]) or d end

  local PRIORITY = { retry = 1, stop = 2, death = 3 }
  local SETTLE_MIN, SETTLE_MAX = .35, 1.25
  local WALK_TIMEOUT = 6

  -- ------------------------------------------------------------ what is there
  function AL.Available() return type(_G.C_Loot) == "table" and type(_G.C_Loot.LootAllCorpses) == "function" end
  local function Scanning()
    local c = _G.C_Loot
    if type(c) ~= "table" or type(c.IsScanInProgress) ~= "function" then return false end
    local ok, r = pcall(c.IsScanInProgress)
    return ok and r and true or false
  end
  local function Pos(unit)
    if type(_G.UnitPosition) ~= "function" then return nil end
    local ok, x, y, z = pcall(_G.UnitPosition, unit)
    x, y, z = tonumber(x), tonumber(y), tonumber(z) or 0
    if ok and x and y then return x, y, z end
  end
  local function Dist(a, b, c, x, y, z)
    if not a or not x then return nil end
    return math.sqrt((a - x) * (a - x) + (b - y) * (b - y) + (c - z) * (c - z))
  end
  -- movement: the client's speed (ClassicAPI) when there, else the position
  -- changing between two looks
  local lastX, lastY, lastZ
  local function Moving()
    if type(_G.GetUnitSpeed) == "function" then
      local ok, s = pcall(_G.GetUnitSpeed, "player")
      s = tonumber(s)
      if ok and s then return s > .01 end
    end
    local x, y, z = Pos("player")
    local m = false
    if x and lastX and Dist(x, y, z, lastX, lastY, lastZ) > .05 then m = true end
    lastX, lastY, lastZ = x, y, z
    return m
  end
  local function Dead() return _G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost("player") and true or false end
  local function Combat() return _G.UnitAffectingCombat and _G.UnitAffectingCombat("player") and true or false end
  local function Busy(now)
    if st.cast and (now or GetTime()) - st.cast < 15 then return true end
    return false
  end
  local function SettleTime()
    local lat
    if type(_G.GetNetStats) == "function" then
      local _, _, a, b = _G.GetNetStats()
      lat = tonumber(b) or tonumber(a)
    end
    local d = SETTLE_MIN
    if lat and lat >= 0 then d = .25 + lat / 1000 * 2 end
    if d < SETTLE_MIN then d = SETTLE_MIN end
    if d > SETTLE_MAX then d = SETTLE_MAX end
    return d
  end

  -- ----------------------------------------------------------------- the log
  local function Money(c)
    c = c or 0
    local g, s, k = math.floor(c / 10000), math.floor(math.mod(c, 10000) / 100), math.mod(c, 100)
    local out = ""
    if g > 0 then out = out .. "|cffffd700" .. g .. "g|r " end
    if s > 0 or g > 0 then out = out .. "|cffc7c7cf" .. s .. "s|r " end
    return out .. "|cffeda55f" .. k .. "c|r"
  end
  AL.Money = Money
  local function Add(ev)
    ev.t = ev.t or time()
    table.insert(st.events, ev)
    if table.getn(st.events) > 500 then table.remove(st.events, 1) end
    if ev.kind == "money" then
      st.money = st.money + ev.amount
    else
      local k = ev.name
      local e = st.items[k]
      if not e then e = { name = ev.name, link = ev.link, tex = ev.tex, count = 0 } st.items[k] = e end
      e.count = e.count + ev.count
      st.count = st.count + ev.count
    end
    st.walkItems = (st.walkItems or 0) + (ev.kind == "money" and 0 or ev.count)
    st.walkMoney = (st.walkMoney or 0) + (ev.kind == "money" and ev.amount or 0)
    if AL.RefreshLog then AL.RefreshLog() end
  end
  function AL.Clear()
    st.events, st.items, st.money, st.count = {}, {}, 0, 0
    if AL.RefreshLog then AL.RefreshLog() end
  end

  -- "You receive loot: %s." etc, turned into patterns
  local patterns
  local function Patterns()
    if patterns then return patterns end
    patterns = {}
    for _, g in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF" }) do
      local f = _G[g]
      if type(f) == "string" then
        local p = string.gsub(f, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        p = string.gsub(p, "%%%%s", "(.+)")
        p = string.gsub(p, "%%%%d", "(%%d+)")
        table.insert(patterns, { "^" .. p .. "$", string.find(f, "%%d") and true or false })
      end
    end
    return patterns
  end
  local function ItemTexture(link)
    local _, _, id = string.find(link, "item:(%d+)")
    if not id then return nil end
    local a, b, c, d, e, f, g, h, i, j = _G.GetItemInfo(tonumber(id))
    if type(j) == "string" and string.find(j, "Interface") then return j end
    if type(i) == "string" and string.find(i, "Interface") then return i end
  end
  function AL.OnLootMessage(msg)
    if type(msg) ~= "string" then return end
    local link, count
    for _, p in ipairs(Patterns()) do
      local a, b, c1, c2 = string.find(msg, p[1])
      if a then
        link, count = c1, c2
        break
      end
    end
    if not link then return end
    local _, _, name = string.find(link, "%[(.-)%]")
    if not name then return end
    Add({ kind = "item", link = link, name = name, count = tonumber(count) or 1, tex = ItemTexture(link) })
  end

  -- ------------------------------------------------------------ what to do
  -- Want: ask for a pass; the strongest reason is kept, and the wait is how
  -- long after the trigger it may start
  function AL.Want(reason, delay)
    if (PRIORITY[reason] or 0) >= (PRIORITY[st.want] or 0) then st.want = reason end
    local due = GetTime() + (delay or .1)
    if not st.due or due < st.due then st.due = due end
  end

  function AL.Blocked(now)
    now = now or GetTime()
    if not On("enable") or st.conflict then return "off" end
    if not AL.Available() then return "no ClassicAPI" end
    if Dead() then return "dead" end
    if Busy(now) or st.lost then return "casting" end
    if st.manual then return "your loot window is open" end
    if st.walking or Scanning() then return "a scan is running" end
    if now < st.settleUntil then return "settling" end
    if Combat() and not On("combat") then return "combat" end
  end

  -- ------------------------------------------------- item by item (9 Nov 2026)
  -- Upsilon: "when masterlooting it is struggling a little and confuses itself
  -- with item quality". In a group with master loot, group loot or need
  -- before greed, items at or over the loot threshold are not yours to take:
  -- the master looter hands them out or they are rolled for. LootAllCorpses
  -- goes for everything. So in a group (and whenever the loot filter has
  -- rules) a pass scans first (C_Loot.ScanNearbyLoot), then takes each item
  -- that may and should be taken (C_Loot.LootUnitItem); a corpse whose every
  -- item is taken is looted whole (C_Loot.LootUnit, coins too).
  local function Grouped()
    local raid = _G.GetNumRaidMembers and _G.GetNumRaidMembers() or 0
    local party = _G.GetNumPartyMembers and _G.GetNumPartyMembers() or 0
    return raid > 0 or party > 0
  end
  -- the loot threshold in force, nil when every item is yours to take
  function AL.Threshold()
    if not Grouped() or type(_G.GetLootMethod) ~= "function" then return nil end
    local method = _G.GetLootMethod()
    if not method or method == "freeforall" then return nil end
    return tonumber(_G.GetLootThreshold and _G.GetLootThreshold()) or 2
  end
  function AL.ItemMode()
    if AL.Threshold() then return true end
    local LF = pfUI.lootfilter
    return LF and LF.Active and LF.Active() and true or false
  end
  local QCOL = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }
  local function QualityOf(e)
    local q = tonumber(e.quality or e.rarity or e.itemQuality)
    if q then return q end
    if type(e.link) == "string" then
      local _, _, hex = string.find(e.link, "|c%x%x(%x%x%x%x%x%x)")
      if hex and QCOL[string.lower(hex)] then return QCOL[string.lower(hex)] end
    end
    if e.id and type(_G.GetItemInfo) == "function" then
      local _, _, q2 = _G.GetItemInfo(e.id)
      return tonumber(q2)
    end
  end
  -- whatever shape the scan answers in, as { { guid, id, link, count, quality } }
  -- plus the corpses: { [guid] = { n = items, money = copper } }
  function AL.Normalize(res)
    local items, units = {}, {}
    local function Unit(g)
      units[g] = units[g] or { n = 0 }
      return units[g]
    end
    local function Item(g, e)
      if type(e) ~= "table" then return end
      local link = e.link or e.itemLink or e.hyperlink
      local id = tonumber(e.itemID or e.itemId or e.id or e.item)
      if not id and type(link) == "string" then
        local _, _, x = string.find(link, "item:(%d+)")
        id = tonumber(x)
      end
      g = g or e.guid or e.unit or e.unitGUID or e.corpse or e.source
      if not g then return end
      local u = Unit(g)
      if (tonumber(e.money or e.copper) or 0) > 0 and not id then u.money = (u.money or 0) + tonumber(e.money or e.copper) return end
      if not id then return end
      local it = { guid = g, id = id, link = link, count = tonumber(e.count or e.quantity or e.stackCount) or 1 }
      it.quality = QualityOf({ quality = e.quality or e.rarity or e.itemQuality, link = link, id = id })
      u.n = u.n + 1
      table.insert(items, it)
    end
    if type(res) ~= "table" then return items, units end
    for k, v in pairs(res) do
      if type(v) == "table" then
        local list = v.items or v.loot
        if type(list) == "table" then
          local g = v.guid or v.unit or v.unitGUID or (type(k) == "string" and k) or nil
          if g then
            local u = Unit(g)
            if (tonumber(v.money or v.copper) or 0) > 0 then u.money = (u.money or 0) + tonumber(v.money or v.copper) end
          end
          for _, e in pairs(list) do Item(g, e) end
        elseif type(k) == "string" and v[1] then
          for _, e in ipairs(v) do Item(k, e) end
        else
          Item(nil, v)
        end
      end
    end
    return items, units
  end
  -- may this item be taken, and should it? -> keep, why
  function AL.Decide(it, threshold)
    if threshold and it.quality and it.quality >= threshold then return false, "group" end
    local LF = pfUI.lootfilter
    if LF and LF.Active and LF.Active() then
      local keep, name = LF.Keep(it)
      if not keep then return false, name or "filter" end
    end
    return true
  end
  function AL.TakeItems(res)
    local C_Loot = _G.C_Loot
    local items, units = AL.Normalize(res)
    local threshold = AL.Threshold()
    local take, left = {}, {}
    for i = 1, table.getn(items) do
      local it = items[i]
      local keep, why = AL.Decide(it, threshold)
      if keep then
        take[it.guid] = take[it.guid] or {}
        table.insert(take[it.guid], it)
      else
        left[it.guid] = true
        st.skipped = (st.skipped or 0) + 1
        st.lastSkip = { name = it.link or ("item " .. it.id), why = why }
      end
    end
    local calls = 0
    for g, u in pairs(units) do
      local mine = take[g]
      if not left[g] and type(C_Loot.LootUnit) == "function" and (mine or (u.money or 0) > 0) then
        -- nothing to leave behind: the whole corpse, coins included
        if pcall(C_Loot.LootUnit, g) then calls = calls + 1 end
      elseif mine and type(C_Loot.LootUnitItem) == "function" then
        for j = 1, table.getn(mine) do
          if pcall(C_Loot.LootUnitItem, g, mine[j].id) then calls = calls + 1 end
        end
      end
    end
    st.itemCalls = (st.itemCalls or 0) + calls
    return calls
  end

  function AL.Run(now)
    now = now or GetTime()
    st.want, st.due = nil, nil
    st.walking, st.walkAt = true, now
    st.walkItems, st.walkMoney = 0, 0
    local C_Loot = _G.C_Loot
    local ok, started
    if AL.ItemMode() and type(C_Loot.ScanNearbyLoot) == "function" and type(C_Loot.LootUnitItem) == "function" then
      st.itemScan = true
      ok, started = pcall(C_Loot.ScanNearbyLoot)
      if ok and started == nil then started = true end
    else
      st.itemScan = nil
      ok, started = pcall(C_Loot.LootAllCorpses)
    end
    if not (ok and started) then st.walking, st.itemScan = false, nil end
    st.runs = (st.runs or 0) + 1
    return ok and started and true or false
  end

  local function Done(now, res)
    now = now or GetTime()
    if st.itemScan then
      -- the scan is in: take what may and should be taken, then wait for it
      st.itemScan = nil
      if res == nil and type(_G.C_Loot.GetLastScanResults) == "function" then
        local ok, r = pcall(_G.C_Loot.GetLastScanResults)
        if ok then res = r end
      end
      st.lastScan = res
      if AL.TakeItems(res) > 0 then
        st.walkAt = now
        return
      end
    end
    st.walking = false
    st.settleUntil = now + SettleTime()
    st.recordUntil = now + 3
    st.summary = On("chat") and true or nil
  end

  -- the heart: called every .05 s (and by the tests with a time)
  function AL.Step(now, moving)
    if moving == nil then moving = Moving() end
    if moving then
      st.due = nil
      st.wasMoving = true
    else
      if st.wasMoving then
        st.wasMoving = false
        if On("stop") then
          local x, y, z = Pos("player")
          local far = Dist(x, y, z, st.stopX, st.stopY, st.stopZ)
          local near = (not far or far < 5) and st.stopAt and now - st.stopAt < .5
          if not near then
            st.stopAt, st.stopX, st.stopY, st.stopZ = now, x, y, z
            AL.Want(far and far >= 5 and "stop" or "retry", Num("stopdelay", .15))
          end
        elseif st.want then
          st.due = now + Num("stopdelay", .15)
        end
      elseif st.want and not st.due then
        st.due = now + Num("stopdelay", .15)
      end
    end
    -- a scan that finished without telling us
    if st.walking and (now - st.walkAt > WALK_TIMEOUT or (now - st.walkAt > .3 and not Scanning())) then Done(now) end
    if st.want and st.due and now >= st.due and not moving and not AL.Blocked(now) then AL.Run(now) end
    if st.summary and now >= st.recordUntil and not st.walking then
      st.summary = nil
      if (st.walkItems or 0) > 0 or (st.walkMoney or 0) > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccAuto loot:|r " .. (st.walkItems or 0) .. " items, " .. Money(st.walkMoney or 0))
      end
    end
  end

  -- a death near you: only mobs within loot range count
  function AL.OnDeath(guid)
    if not On("death") then return end
    if type(guid) == "string" then
      local d
      if type(_G.UnitDistanceSquared) == "function" then
        local ok, sq, checked = pcall(_G.UnitDistanceSquared, guid)
        sq = tonumber(sq)
        if ok and checked and sq and sq >= 0 then d = math.sqrt(sq) end
      end
      if not d then
        local x, y, z = Pos(guid)
        local a, b, c = Pos("player")
        d = Dist(x, y, z, a, b, c)
      end
      if d and d > Num("deathdist", 8) then return end
    end
    AL.Want("death", Num("deathdelay", .25))
  end

  -- --------------------------------------------------------------- events
  local f = CreateFrame("Frame", "pfAutoLootDriver", UIParent)
  AL.driver = f
  local events = { "LOOT_OPENED", "LOOT_CLOSED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_REGEN_ENABLED",
    "CHAT_MSG_LOOT", "PLAYER_MONEY", "SPELLCAST_START", "SPELLCAST_CHANNEL_START", "SPELLCAST_STOP", "SPELLCAST_CHANNEL_STOP",
    "SPELLCAST_INTERRUPTED", "SPELLCAST_FAILED" }
  for _, e in ipairs(events) do f:RegisterEvent(e) end
  local function Valid(e) return _G.C_EventUtils and type(_G.C_EventUtils.IsEventValid) == "function" and _G.C_EventUtils.IsEventValid(e) end
  if Valid("UNIT_DIED") then f:RegisterEvent("UNIT_DIED") else f:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH") end
  if Valid("LOOT_SCAN_COMPLETED") then f:RegisterEvent("LOOT_SCAN_COMPLETED") end
  if Valid("PLAYER_CONTROL_LOST") then f:RegisterEvent("PLAYER_CONTROL_LOST") f:RegisterEvent("PLAYER_CONTROL_GAINED") end

  f:SetScript("OnEvent", function()
    local e = _G.event
    if e == "UNIT_DIED" then AL.OnDeath(_G.arg1)
    elseif e == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then AL.OnDeath(nil)
    elseif e == "LOOT_OPENED" then
      if st.walking or GetTime() < st.settleUntil - .2 then
        if On("closewin") and type(_G.CloseLoot) == "function" then _G.CloseLoot() else st.manual = true end
      else
        st.manual = true
      end
    elseif e == "LOOT_CLOSED" then st.manual = false
    elseif e == "LOOT_SCAN_COMPLETED" then if st.walking then Done(nil, type(_G.arg1) == "table" and _G.arg1 or nil) end
    elseif e == "CHAT_MSG_LOOT" then
      if On("log") and (st.walking or GetTime() < st.recordUntil) then AL.OnLootMessage(_G.arg1) end
    elseif e == "PLAYER_MONEY" then
      local m = _G.GetMoney and _G.GetMoney() or 0
      if st.moneyBase and m > st.moneyBase and On("log") and (st.walking or GetTime() < st.recordUntil) then
        Add({ kind = "money", amount = m - st.moneyBase })
      end
      st.moneyBase = m
    elseif e == "SPELLCAST_START" or e == "SPELLCAST_CHANNEL_START" then st.cast = GetTime()
    elseif e == "SPELLCAST_STOP" or e == "SPELLCAST_CHANNEL_STOP" or e == "SPELLCAST_INTERRUPTED" or e == "SPELLCAST_FAILED" then
      st.cast = nil
    elseif e == "PLAYER_CONTROL_LOST" then st.lost = true
    elseif e == "PLAYER_CONTROL_GAINED" then st.lost = nil
    elseif e == "PLAYER_REGEN_ENABLED" then
      -- one last pass after the fight
      if st.want or On("death") then AL.Want("retry", .5) end
    elseif e == "PLAYER_LEAVING_WORLD" then
      st.want, st.due, st.walking, st.manual, st.cast, st.lost, st.wasMoving = nil, nil, nil, nil, nil, nil, nil
    elseif e == "PLAYER_ENTERING_WORLD" then
      st.moneyBase = _G.GetMoney and _G.GetMoney() or 0
      lastX = nil
      -- the AutoAreaLoot addon does the same job: only one may loot
      st.conflict = _G.IsAddOnLoaded and _G.IsAddOnLoaded("AutoAreaLoot") and On("enable") and true or nil
      if st.conflict and not st.warned then
        st.warned = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo:|r the AutoAreaLoot addon is on too, so pfUI's Auto Loot stands aside. Switch one off.")
      end
      if On("loginopen") and AL.ShowLog then AL.ShowLog(true) end
    end
  end)
  local acc = 0
  f:SetScript("OnUpdate", function()
    acc = acc + (_G.arg1 or 0)
    if acc < .05 then return end
    acc = 0
    AL.Step(GetTime())
  end)

  -- sample rows for the options and tests
  function AL.Sample()
    Add({ kind = "item", name = "Linen Cloth", link = "|cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r", count = 3, tex = "Interface\\Icons\\INV_Fabric_Linen_01" })
    Add({ kind = "item", name = "Copper Bar", link = "|cffffffff|Hitem:2840:0:0:0|h[Copper Bar]|h|r", count = 1, tex = "Interface\\Icons\\INV_Ingot_02" })
    Add({ kind = "item", name = "Tough Jerky", link = "|cff1eff00|Hitem:117:0:0:0|h[Tough Jerky]|h|r", count = 2, tex = "Interface\\Icons\\INV_Misc_Food_54" })
    Add({ kind = "money", amount = 1234 })
  end

  -- /autoloot
  _G.SLASH_PFAUTOLOOT1 = "/autoloot"
  _G.SLASH_PFAUTOLOOT2 = "/pfal"
  _G.SlashCmdList["PFAUTOLOOT"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "on" or msg == "off" then
      G().enable = msg == "on" and "1" or "0"
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccAuto loot:|r " .. msg)
    elseif msg == "log" then
      if AL.ShowLog then AL.ShowLog() end
    elseif msg == "scan" then
      -- the raw shape of the last scan (ClassicAPI does not document it)
      local out = DEFAULT_CHAT_FRAME
      local res = st.lastScan
      if res == nil and _G.C_Loot and type(_G.C_Loot.GetLastScanResults) == "function" then
        local ok, r = pcall(_G.C_Loot.GetLastScanResults)
        if ok then res = r end
      end
      local lines = 0
      local function Dump(v, pre, depth)
        if lines > 25 then return end
        if type(v) ~= "table" or depth > 3 then
          out:AddMessage(pre .. tostring(v)) lines = lines + 1 return
        end
        for k, x in pairs(v) do
          if type(x) == "table" then
            out:AddMessage(pre .. tostring(k) .. " =") lines = lines + 1
            Dump(x, pre .. "  ", depth + 1)
          else
            out:AddMessage(pre .. tostring(k) .. " = " .. tostring(x)) lines = lines + 1
          end
          if lines > 25 then return end
        end
      end
      out:AddMessage("|cff33ffccAuto loot:|r last scan (" .. (AL.ItemMode() and "item by item" or "whole corpses")
        .. ", threshold " .. tostring(AL.Threshold()) .. "):")
      Dump(res, "  ", 0)
      local items = AL.Normalize(res)
      out:AddMessage("  read as " .. table.getn(items) .. " items; skipped this session: " .. (st.skipped or 0))
    elseif msg == "status" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccAuto loot:|r " .. (On("enable") and "on" or "off") .. ", "
        .. (AL.Available() and "ClassicAPI loot found" or "ClassicAPI loot MISSING") .. ", "
        .. (AL.Blocked() and ("waiting: " .. AL.Blocked()) or "ready") .. ", passes " .. (st.runs or 0))
    else
      if pfUI.octoui and pfUI.octoui.Options and pfUI.octoui.Options.Open then pfUI.octoui.Options:Open("autoloot") end
    end
  end
end)
