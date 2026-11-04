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

  function AL.Run(now)
    now = now or GetTime()
    st.want, st.due = nil, nil
    st.walking, st.walkAt = true, now
    st.walkItems, st.walkMoney = 0, 0
    local ok, started = pcall(_G.C_Loot.LootAllCorpses)
    if not (ok and started) then st.walking = false end
    st.runs = (st.runs or 0) + 1
    return ok and started and true or false
  end

  local function Done(now)
    now = now or GetTime()
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
    elseif e == "LOOT_SCAN_COMPLETED" then if st.walking then Done() end
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
  SLASH_PFAUTOLOOT1 = "/autoloot"
  SLASH_PFAUTOLOOT2 = "/pfal"
  _G.SlashCmdList["PFAUTOLOOT"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "on" or msg == "off" then
      G().enable = msg == "on" and "1" or "0"
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccAuto loot:|r " .. msg)
    elseif msg == "log" then
      if AL.ShowLog then AL.ShowLog() end
    elseif msg == "status" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccAuto loot:|r " .. (On("enable") and "on" or "off") .. ", "
        .. (AL.Available() and "ClassicAPI loot found" or "ClassicAPI loot MISSING") .. ", "
        .. (AL.Blocked() and ("waiting: " .. AL.Blocked()) or "ready") .. ", passes " .. (st.runs or 0))
    else
      if pfUI.octoui and pfUI.octoui.Options and pfUI.octoui.Options.Open then pfUI.octoui.Options:Open("autoloot") end
    end
  end
end)
