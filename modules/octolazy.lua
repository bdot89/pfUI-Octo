pfUI:RegisterModule("octolazy", "vanilla", function ()
  -- pfUI Octo :: OctoLazy (16 Nov 2026; user, with the _LazyPig add-on: "copy it like for like add
  -- more rules and make it ALOT better ... full control over what we want to need and what we want
  -- to greed or pass automatically"; "call it octolazy in our tabs make it user friendly").
  -- _LazyPig has no licence, so this is written fresh from its feature list:
  --   rolls    a list of roll rules (libs/librules.lua checks + an item box + where), top to bottom,
  --            the first that matches decides Need / Greed / Pass / Ask me; a wait before rolling,
  --            the bind-on-pickup question answered, Shift = leave this roll to me, a history;
  --            Ctrl+Alt rolls every open green item (LazyPig's key)
  --   groups   invites (guild / friends / anyone, not in a battleground), summons (now, after a
  --            wait, or just before it runs out), resurrections, duels, guild invites
  --   bgs      enter when the queue pops, leave when it ends, release when you die, queue at the
  --            battle master (as a group when you lead), no shared quests, the enemy flag carrier
  --   npcs     gossip skipped for flight masters, vendors, bankers, battle masters (Ctrl shows the
  --            menu), quests taken / handed in (with Shift or always), the last quest repeated
  --   bags     right-click a bag item into trade or mail, Shift + right-click = make stacks of N
  --   chat     others' roll and junk loot lines hidden, the World channel quiet in instances
  --   more     Salvation off for tanks, camera distance, key combinations, key bindings
  -- Things pfUI Octo already does (sell greys, repair, loot at the mouse, leave a form or mount
  -- for a spell) are its own switches, shown on the pages too. Not taken: LazyPig's ".save"
  -- (a chat command the server may not know - it would be said out loud).
  -- Settings: C.octolazy (strings "1" / "0", numbers, and the roll list).
  local R = pfUI.rules
  if not R then return end
  local LZ = { history = {}, pending = {}, open = {}, mine = {}, tried = {}, last = {}, bgAt = {}, stats = { rolls = 0, invites = 0, summons = 0 } }
  pfUI.octolazy = LZ
  local lower, find, gsub = string.lower, string.find, string.gsub
  local function G() return C.octolazy end
  local function On(k) return G()[k] == "1" end
  local function Num(k, d) return tonumber(G()[k]) or d end
  local function Now() return GetTime and GetTime() or 0 end
  function LZ.Say(msg) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoLazy|r " .. msg) end end
  function LZ.Note(msg) if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, .2, .8, 1, 1) end end
  local Say, Note = LZ.Say, LZ.Note

  -- the old add-on itself: if it is on, it keeps the work and we stand aside
  function LZ.Other()
    if type(_G.IsAddOnLoaded) == "function" and (_G.IsAddOnLoaded("_LazyPig") or _G.IsAddOnLoaded("LazyPig")) then return "_LazyPig" end
  end

  -- ================================================================ loot rolls
  LZ.ROLL = { pass = 0, need = 1, greed = 2 }
  LZ.ACTS = { { key = "need", label = "Need" }, { key = "greed", label = "Greed" }, { key = "pass", label = "Pass" }, { key = "ask", label = "Ask me (no roll)" } }
  LZ.ACTCOL = { need = "|cff55ff55", greed = "|cffffd24d", pass = "|cffaaaaaa", ask = "|cff33ccff" }
  LZ.ACTNAME = { need = "Need", greed = "Greed", pass = "Pass", ask = "Ask me" }
  LZ.WHERE = { { key = "any", label = "Anywhere" }, { key = "raid", label = "Raids" }, { key = "dungeon", label = "Dungeons" },
    { key = "instance", label = "Raids and dungeons" }, { key = "world", label = "Outside instances" } }
  LZ.WHERELABEL = {}
  for _, w in ipairs(LZ.WHERE) do LZ.WHERELABEL[w.key] = w.label end
  -- (16 Nov 2026, user: "the dungeon option for example black morass should have full control of the rep
  -- items etc, bijous everything like this that lazy pig had but full control") each of _LazyPig's
  -- items is a rule of its own - its own roll, its own zone - so each one can be Need, Greed, Pass or Ask
  LZ.DEFAULTS = {
    { on = "1", act = "need", where = "any", zone = "Zul'Gurub", name = "Zul'Gurub: Hakkari Bijous", rule = 'Name("Hakkari Bijou")' },
    { on = "1", act = "need", where = "any", zone = "Zul'Gurub", name = "Zul'Gurub: coins", rule = 'Name(" Coin")' },
    { on = "1", act = "greed", where = "any", zone = "The Black Morass", name = "The Black Morass: Corrupted Sand", rule = 'NameIs("Corrupted Sand")' },
    { on = "1", act = "greed", where = "any", zone = "", name = "Naxxramas and the Scourge: Necrotic Runes", rule = 'NameIs("Necrotic Rune")' },
    { on = "0", act = "greed", where = "any", zone = "Ahn'Qiraj", name = "Ahn'Qiraj: idols and scarabs", rule = 'Name("Idol", "Scarab") and not Equip()' },
    { on = "0", act = "greed", where = "raid", zone = "", name = "Raids: Nexus Crystals and Large Brilliant Shards", rule = 'NameIs("Nexus Crystal", "Large Brilliant Shard")' },
    { on = "0", act = "pass", where = "any", name = "Recipes I already know", rule = 'Known()' },
    { on = "0", act = "need", where = "any", name = "Upgrades I can use", rule = 'Equip() and Usable() and Upgrade() and MinQuality("uncommon")' },
    { on = "0", act = "greed", where = "any", name = "Gear I cannot use", rule = 'Equip() and not Usable()' },
    { on = "0", act = "greed", where = "any", name = "Green items", rule = 'Quality("uncommon")' },
    { on = "0", act = "greed", where = "any", name = "Grey and white items", rule = 'MaxQuality("common")' },
  }
  local function Copy(t)
    local out = {}
    for i = 1, table.getn(t) do
      local r = t[i]
      out[i] = { on = r.on, act = r.act, where = r.where, zone = r.zone, name = r.name, rule = r.rule, items = {} }
    end
    return out
  end
  function LZ.Rules()
    if type(G().rolllist) ~= "table" then G().rolllist = Copy(LZ.DEFAULTS) end
    return G().rolllist
  end
  function LZ.ResetRules() G().rolllist = Copy(LZ.DEFAULTS) end
  function LZ.AddRule(act, name, items)
    table.insert(LZ.Rules(), 1, { on = "1", act = act or "greed", where = "any", zone = "", name = name or "New rule", rule = "", items = items or {} })
  end
  function LZ.RemoveRule(i) table.remove(LZ.Rules(), i) end
  function LZ.MoveRule(i, by)
    local list = LZ.Rules()
    local j = i + by
    if j < 1 or j > table.getn(list) then return end
    list[i], list[j] = list[j], list[i]
  end

  function LZ.WhereOk(w)
    if not w or w == "any" then return true end
    local here = R.InstanceType()
    if w == "instance" then return here == "raid" or here == "dungeon" end
    return here == w
  end
  -- a rule's "Only in" box: zone names split by commas (part of a name is enough); empty = everywhere
  function LZ.ZoneOk(text)
    if not text or not find(text, "%S") then return true end
    local zone = lower((_G.GetRealZoneText and _G.GetRealZoneText() or "") .. "\n" .. (_G.GetSubZoneText and _G.GetSubZoneText() or ""))
    for w in string.gfind(text, "[^,;]+") do
      w = gsub(gsub(w, "^%s+", ""), "%s+$", "")
      if w ~= "" and find(zone, lower(w), 1, true) then return true end
    end
    return false
  end
  -- the zones the dungeon list offers (rep and token items), for the "Only in" box
  LZ.ZONES = { "Zul'Gurub", "The Black Morass", "Naxxramas", "Ahn'Qiraj", "Ruins of Ahn'Qiraj", "Molten Core", "Blackwing Lair",
    "Onyxia's Lair", "Blackrock Spire", "Blackrock Depths", "Stratholme", "Scholomance", "Dire Maul", "Karazhan", "Emerald Sanctum",
    "Gilneas City", "Hateforge Quarry", "Stormwind Vault", "Crescent Grove", "Caverns of Time" }

  -- the item of a roll, as the rules read it
  function LZ.RollInfo(id)
    local _, name, count, quality, bop = _G.GetLootRollItemInfo(id)
    local link = _G.GetLootRollItemLink and _G.GetLootRollItemLink(id)
    local iid = _G.GetLootRollItemID and _G.GetLootRollItemID(id)
    local info = R.Info(link or iid or name, nil, nil, count)
    info.roll = id
    info.name = info.name or name
    info.link = link or info.link
    if info.quality == nil then info.quality = tonumber(quality) end
    info.bop = bop
    return info
  end

  -- -> act, rule name (nil: no rule matched)
  function LZ.Decide(info)
    local list = LZ.Rules()
    for i = 1, table.getn(list) do
      local r = list[i]
      if r.on == "1" and LZ.WhereOk(r.where) and LZ.ZoneOk(r.zone) then
        local hit = false
        if type(r.items) == "table" and info.id then
          for j = 1, table.getn(r.items) do if tonumber(r.items[j]) == info.id then hit = true break end end
        end
        if not hit and r.rule and r.rule ~= "" then
          local fn = R.Compile(r.rule)
          hit = fn and R.Match(fn, info) or false
        end
        if hit then
          local act = r.act or "ask"
          -- never Need what you cannot use (Need is for those who can)
          if act == "need" and On("needsafe") and not R.Match(R.Compile("Usable()"), info) then act = "greed" end
          return act, r.name or "rule " .. i
        end
      end
    end
  end

  -- a roll frame of the game's or pfUI's for this roll: hidden once we rolled
  local function HideFrames(id)
    for i = 1, (_G.NUM_GROUP_LOOT_FRAMES or 4) do
      local f = _G["GroupLootFrame" .. i]
      if f and f.rollID == id and f.Hide then f:Hide() end
    end
    local pr = pfUI.roll and pfUI.roll.frames
    if type(pr) == "table" then
      for _, f in pairs(pr) do if type(f) == "table" and f.rollID == id and f.Hide then f:Hide() end end
    end
  end

  function LZ.Roll(id, act, why)
    local n = LZ.ROLL[act]
    if not n then return end
    local link = (_G.GetLootRollItemLink and _G.GetLootRollItemLink(id)) or (LZ.open[id] and LZ.open[id].link) or "?"
    LZ.mine[id] = n
    LZ.pending[id] = nil
    _G.RollOnLoot(id, n)
    HideFrames(id)
    LZ.open[id] = nil
    LZ.stats.rolls = LZ.stats.rolls + 1
    table.insert(LZ.history, 1, { t = _G.time and _G.time() or 0, link = link, act = act, why = why })
    while table.getn(LZ.history) > 40 do table.remove(LZ.history) end
    if On("rollchat") then Say(LZ.ACTCOL[act] .. LZ.ACTNAME[act] .. "|r " .. link .. "  |cff888888(" .. (why or "?") .. ")|r") end
  end

  function LZ.OnRoll(id, secs)
    local _, _, _, quality = _G.GetLootRollItemInfo(id)
    local info = LZ.RollInfo(id)
    LZ.open[id] = { link = info.link, quality = info.quality or tonumber(quality) or 0, ends = Now() + (tonumber(secs) or 60000) / 1000 }
    if not On("rolls") then return end
    if On("rollshift") and IsShiftKeyDown() then Note("OctoLazy: this roll is yours (Shift)") return end
    local act, why = LZ.Decide(info)
    if not act or act == "ask" then return act, why end
    if (info.quality or 0) > Num("rollmax", 4) then
      Say("left to you: " .. (info.link or info.name or "?") .. " |cff888888(over the quality you let it roll)|r")
      return "ask", why
    end
    local wait = Num("rolldelay", 0)
    if wait <= 0 then LZ.Roll(id, act, why) else LZ.pending[id] = { at = Now() + wait, act = act, why = why } end
    return act, why
  end

  -- Ctrl + Alt: every open green item, with the roll picked for it
  function LZ.GreenKey()
    local act, done = G().greenroll or "greed", false
    for id, o in pairs(LZ.open) do
      if o.quality == 2 then LZ.Roll(id, act, "Ctrl + Alt") done = true end
    end
    return done
  end

  -- the "are you sure" of a bind-on-pickup roll, for rolls we made
  function LZ.OnConfirmRoll(id, roll)
    if not LZ.mine[id] or not On("rollconfirm") then return end
    if type(_G.ConfirmLootRoll) == "function" then _G.ConfirmLootRoll(id, roll or LZ.mine[id]) end
    if _G.StaticPopup_Hide then _G.StaticPopup_Hide("CONFIRM_LOOT_ROLL") end
  end

  -- ================================================================ groups
  function LZ.IsFriend(name)
    if not name then return false end
    for i = 1, (_G.GetNumFriends and _G.GetNumFriends() or 0) do
      local n = _G.GetFriendInfo(i)
      if n and lower(n) == lower(name) then return true end
    end
    return false
  end
  function LZ.IsGuild(name)
    if not name or not (_G.IsInGuild and _G.IsInGuild()) then return false end
    for i = 1, (_G.GetNumGuildMembers and _G.GetNumGuildMembers() or 0) do
      local n = _G.GetGuildRosterInfo(i)
      if n and lower(n) == lower(name) then return true end
    end
    return false
  end
  function LZ.Who(name)
    if LZ.IsGuild(name) then return "guild" end
    if LZ.IsFriend(name) then return "friend" end
    return "stranger"
  end
  function LZ.InBGOrQueue()
    if R.InstanceType() == "pvp" then return true end
    for i = 1, (_G.MAX_BATTLEFIELD_QUEUES or 3) do
      local s = _G.GetBattlefieldStatus and _G.GetBattlefieldStatus(i)
      if s == "queued" or s == "confirm" or s == "active" then return true end
    end
    return false
  end

  -- -> what was done ("accept", "decline", or nil: the window stays for you)
  function LZ.OnInvite(name)
    if On("invbg") and LZ.InBGOrQueue() then return nil end
    local who = LZ.Who(name)
    if (who == "guild" and On("invguild")) or (who == "friend" and On("invfriend")) or (who == "stranger" and On("invstranger")) then
      _G.AcceptGroup()
      if _G.StaticPopup_Hide then _G.StaticPopup_Hide("PARTY_INVITE") end
      LZ.stats.invites = LZ.stats.invites + 1
      Note("OctoLazy: joined " .. tostring(name) .. "'s group")
      return "accept"
    end
    if who == "stranger" and On("invdecline") then
      _G.DeclineGroup()
      if _G.StaticPopup_Hide then _G.StaticPopup_Hide("PARTY_INVITE") end
      Say("said no to a group invite from " .. tostring(name) .. " (not a friend or guild member)")
      return "decline"
    end
  end

  -- summons and battleground entry: now, after a wait, or a few seconds before it runs out
  LZ.WHEN = { { key = "now", label = "At once" }, { key = "wait", label = "After a few seconds" }, { key = "late", label = "Just before it runs out" } }
  local function When(mode, left, wait)
    if mode == "now" then return 1 end
    if mode == "wait" then return math.min(wait, math.max(1, left - 3)) end
    return math.max(1, left - 4)
  end

  function LZ.OnSummon()
    if not On("summon") then return end
    local left = _G.GetSummonConfirmTimeLeft and _G.GetSummonConfirmTimeLeft() or 0
    if left <= 0 then return end
    local secs = When(G().summonmode, left, Num("summonwait", 5))
    LZ.summonAt = Now() + secs
    Say("taking the summon in " .. math.floor(secs + .5) .. " s |cff888888(say no on its window to stop it)|r")
  end
  function LZ.DoSummon()
    LZ.summonAt = nil
    local left = _G.GetSummonConfirmTimeLeft and _G.GetSummonConfirmTimeLeft() or 0
    if left <= 0 then return end
    if On("summoncombat") and UnitAffectingCombat("player") and left > 2 then LZ.summonAt = Now() + 1 return end
    _G.ConfirmSummon()
    if _G.StaticPopup_Hide then _G.StaticPopup_Hide("CONFIRM_SUMMON") end
    LZ.stats.summons = LZ.stats.summons + 1
  end

  local function UnitOf(name)
    if not name then return nil end
    for i = 1, (_G.GetNumRaidMembers and _G.GetNumRaidMembers() or 0) do
      if UnitName("raid" .. i) == name then return "raid" .. i end
    end
    for i = 1, (_G.GetNumPartyMembers and _G.GetNumPartyMembers() or 0) do
      if UnitName("party" .. i) == name then return "party" .. i end
    end
  end
  function LZ.OnRez(name)
    if not On("rez") then return end
    if G().rezwhere ~= "any" and R.InstanceType() == "world" then return end
    local u = UnitOf(name)
    if On("rezcombat") and u and UnitAffectingCombat(u) then
      Say(tostring(name) .. " is in combat: the resurrection is yours to take")
      return
    end
    local wait = _G.GetCorpseRecoveryDelay and _G.GetCorpseRecoveryDelay() or 0
    if wait > 0 then LZ.rezAt = Now() + wait + .2 return end
    _G.AcceptResurrect()
    if _G.StaticPopup_Hide then
      _G.StaticPopup_Hide("RESURRECT") _G.StaticPopup_Hide("RESURRECT_NO_SICKNESS") _G.StaticPopup_Hide("RESURRECT_NO_TIMER")
    end
    Note("OctoLazy: resurrected by " .. tostring(name))
    return true
  end

  function LZ.OnDuel(name)
    if not On("duel") or IsShiftKeyDown() then return end
    if On("duelfriends") and (LZ.IsFriend(name) or LZ.IsGuild(name)) then return end
    _G.CancelDuel()
    if _G.StaticPopup_Hide then _G.StaticPopup_Hide("DUEL_REQUESTED") end
    Note("OctoLazy: duel from " .. tostring(name) .. " turned down (hold Shift to see them)")
    return true
  end

  -- ================================================================ battlegrounds
  function LZ.OnBattlefield()
    local now = Now()
    for i = 1, (_G.MAX_BATTLEFIELD_QUEUES or 3) do
      local s, map = _G.GetBattlefieldStatus(i)
      if s == "confirm" and On("bgenter") and not LZ.bgAt[i] and not (On("bgafk") and _G.UnitIsAFK and _G.UnitIsAFK("player")) then
        local left = (_G.GetBattlefieldPortExpiration and _G.GetBattlefieldPortExpiration(i) or 60000) / 1000
        local secs = When(G().bgentermode, left, Num("bgwait", 5))
        LZ.bgAt[i] = now + secs
        Say("entering " .. tostring(map) .. " in " .. math.floor(secs + .5) .. " s |cff888888(Leave Queue on its window to stop it)|r")
      elseif s ~= "confirm" then
        LZ.bgAt[i] = nil
      end
      if s == "queued" and LZ.queuedAs == "group" and On("bgannounce") and not LZ.announced then
        LZ.announced = true
        local chan = (_G.GetNumRaidMembers and _G.GetNumRaidMembers() or 0) > 0 and "RAID" or "PARTY"
        _G.SendChatMessage("Queued for " .. tostring(map) .. " as a group.", chan)
      end
    end
    if On("bgleave") and _G.GetBattlefieldWinner and _G.GetBattlefieldWinner() and not LZ.leaveAt then
      LZ.leaveAt = now + Num("bgleavewait", 5)
      Say("the battle is over: leaving in " .. Num("bgleavewait", 5) .. " s")
    end
  end
  function LZ.EnterBG(i)
    LZ.bgAt[i] = nil
    local s = _G.GetBattlefieldStatus(i)
    if s ~= "confirm" then return end
    _G.AcceptBattlefieldPort(i, 1)
    if _G.StaticPopup_Hide then _G.StaticPopup_Hide("CONFIRM_BATTLEFIELD_ENTRY") end
  end

  function LZ.OnBattleMaster()
    if not On("bgqueue") or IsShiftKeyDown() then return end
    local group = (_G.GetNumRaidMembers() > 0 or _G.GetNumPartyMembers() > 0) and _G.IsPartyLeader and _G.IsPartyLeader()
    LZ.queuedAs, LZ.announced = group and "group" or "solo", nil
    if group then _G.JoinBattlefield(0, 1) else _G.JoinBattlefield(0) end
    if _G.HideUIPanel and _G.BattlefieldFrame then _G.HideUIPanel(_G.BattlefieldFrame) end
    Note("OctoLazy: queued" .. (group and " as a group" or "") .. " (hold Shift at the battle master to pick yourself)")
    return true
  end

  -- the enemy flag carrier (carries YOUR side's flag) and your own
  function LZ.OnFlagLine(msg)
    if not msg then return end
    local _, _, side, who = find(msg, "^The (%a+) [Ff]lag was picked up by (.+)!$")
    local mine = _G.UnitFactionGroup and _G.UnitFactionGroup("player")
    if side and who then
      if side == mine then LZ.efc = who else LZ.fc = who end
      return
    end
    local _, _, side2 = find(msg, "^The (%a+) [Ff]lag was dropped")
    local cap = find(msg, "captured the (%a+) flag") or find(msg, "captured the (%a+) Flag")
    if side2 == mine or (cap and find(msg, mine or "?")) then LZ.efc = nil end
    if side2 and side2 ~= mine then LZ.fc = nil end
    if cap then LZ.efc, LZ.fc = nil, nil end
  end
  function LZ.TargetEFC()
    if not LZ.efc then Note("OctoLazy: no one carries your flag") return end
    _G.TargetByName(LZ.efc, true)
    if not UnitExists("target") or UnitName("target") ~= LZ.efc then Note("Flag carrier out of range: " .. LZ.efc) end
  end

  -- buffs by name (the tooltip): the flag and slow falls
  local function CancelBuffs(words)
    local scan = pfUI.api and pfUI.api.libtipscan and pfUI.api.libtipscan:GetScanner("octolazy")
    if not scan or not _G.GetPlayerBuff then return 0 end
    local n = 0
    for i = 0, 31 do
      local idx = _G.GetPlayerBuff(i, "HELPFUL")
      if idx and idx >= 0 then
        scan:SetPlayerBuff(idx)
        local name = scan:Line(1)
        for j = 1, table.getn(words) do
          if name and find(lower(name), words[j], 1, true) then _G.CancelPlayerBuff(idx) n = n + 1 break end
        end
      end
    end
    return n
  end
  function LZ.DropFlag() return CancelBuffs({ "warsong flag", "silverwing flag", "slow fall", "levitate", "feather fall" }) end

  function LZ.DuelKey()
    if _G.GetRealZoneText and _G.GetRealZoneText() == "Warsong Gulch" then return LZ.TargetEFC() end
    if LZ.dueling then _G.CancelDuel() return end
    if UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player", "target") then _G.StartDuel("target") end
  end

  -- ================================================================ npcs and quests
  function LZ.QuestOn()
    local m = G().quests
    return m == "always" or (m == "shift" and IsShiftKeyDown())
  end
  local function Completed(title)
    if not title or not _G.GetNumQuestLogEntries then return false end
    for i = 1, _G.GetNumQuestLogEntries() do
      local t, _, _, header, _, done = _G.GetQuestLogTitle(i)
      if not header and t == title then return done == 1 end
    end
    return false
  end
  -- pairs list (title, level, title, level ...) -> titles
  local function Titles(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t)
    local all, out = { a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t }, {}
    for x = 1, 19, 2 do if all[x] then table.insert(out, all[x]) end end
    return out
  end
  local function Pick(active, available)
    local npc = UnitName("npc") or "?"
    local again = On("questrepeat") and LZ.last[npc]
    if again then
      for i = 1, table.getn(active) do if active[i] == again and not LZ.tried[again] then return "active", i end end
      for i = 1, table.getn(available) do if available[i] == again and not LZ.tried[again] then return "available", i end end
    end
    for i = 1, table.getn(active) do if Completed(active[i]) and not LZ.tried[active[i]] then return "active", i end end
    if On("questaccept") then
      for i = 1, table.getn(available) do if not LZ.tried[available[i]] then return "available", i end end
    end
  end
  LZ.Pick = Pick

  LZ.KINDS = { taxi = "gtaxi", vendor = "gvendor", banker = "gbank", battlemaster = "gbattle", trainer = "gtrainer" }
  function LZ.Words()
    local out = {}
    local text = G().gtext or ""
    for w in string.gfind(text, "[^,;]+") do
      w = gsub(gsub(w, "^%s+", ""), "%s+$", "")
      if w ~= "" then table.insert(out, lower(w)) end
    end
    return out
  end

  function LZ.OnGossip()
    if LZ.QuestOn() then
      local active = Titles(_G.GetGossipActiveQuests())
      local available = Titles(_G.GetGossipAvailableQuests())
      local kind, i = Pick(active, available)
      if kind then
        local title = kind == "active" and active[i] or available[i]
        LZ.tried[title] = true
        if kind == "active" then _G.SelectGossipActiveQuest(i) else _G.SelectGossipAvailableQuest(i) end
        return "quest"
      end
    end
    if not On("gossip") or IsControlKeyDown() then return end
    local o = { _G.GetGossipOptions() }
    local hasQuest = _G.GetGossipActiveQuests() or _G.GetGossipAvailableQuests()
    -- your own lines first (e.g. "Teleport me to the Molten Core")
    local words = LZ.Words()
    for x = 1, table.getn(o), 2 do
      local t = o[x] and lower(o[x])
      for w = 1, table.getn(words) do
        if t and find(t, words[w], 1, true) then _G.SelectGossipOption((x + 1) / 2) return "line" end
      end
    end
    if hasQuest then return end
    local pick, count = nil, 0
    for x = 1, table.getn(o), 2 do
      local key = LZ.KINDS[o[x + 1] or ""]
      if key and On(key) then pick, count = (x + 1) / 2, count + 1 end
    end
    if count == 1 then _G.SelectGossipOption(pick) return "skip" end
  end

  function LZ.OnGreeting()
    if not LZ.QuestOn() then return end
    local active, available = {}, {}
    for i = 1, (_G.GetNumActiveQuests and _G.GetNumActiveQuests() or 0) do active[i] = _G.GetActiveTitle(i) end
    for i = 1, (_G.GetNumAvailableQuests and _G.GetNumAvailableQuests() or 0) do available[i] = _G.GetAvailableTitle(i) end
    local kind, i = Pick(active, available)
    if not kind then return end
    local title = kind == "active" and active[i] or available[i]
    LZ.tried[title] = true
    if kind == "active" then _G.SelectActiveQuest(i) else _G.SelectAvailableQuest(i) end
    return kind
  end

  function LZ.OnQuestDetail()
    -- a quest shared by a player inside a battleground ("Empty Stables")
    if On("bgquest") and R.InstanceType() == "pvp" and UnitIsPlayer("npc") then
      _G.DeclineQuest()
      Note("OctoLazy: shared battleground quest turned down")
      return "declined"
    end
    if LZ.QuestOn() and On("questaccept") then _G.AcceptQuest() return "accepted" end
  end
  function LZ.OnQuestProgress()
    if LZ.QuestOn() and _G.IsQuestCompletable and _G.IsQuestCompletable() then _G.CompleteQuest() return true end
  end
  function LZ.OnQuestComplete()
    if not LZ.QuestOn() then return end
    local n = _G.GetNumQuestChoices and _G.GetNumQuestChoices() or 0
    local choice
    if n <= 1 then
      choice = n
    elseif G().questchoice == "value" then
      local best, at = -1, nil
      for i = 1, n do
        local info = R.ItemInfo(R.IdOf(_G.GetQuestItemLink and _G.GetQuestItemLink("choice", i)))
        if not info or not info.value then at = nil break end
        if info.value > best then best, at = info.value, i end
      end
      choice = at
    end
    if not choice then return end
    LZ.last[UnitName("npc") or "?"] = _G.GetTitleText and _G.GetTitleText()
    _G.GetQuestReward(choice)
    return true
  end

  -- ================================================================ bags
  local function Tradeable(bag, slot)
    local scan = pfUI.api and pfUI.api.libtipscan and pfUI.api.libtipscan:GetScanner("octolazy")
    if not scan then return true end
    scan:SetBagItem(bag, slot)
    for _, w in ipairs({ _G.ITEM_SOULBOUND or "Soulbound", _G.ITEM_BIND_QUEST or "Quest Item", _G.ITEM_CONJURED or "Conjured Item" }) do
      if scan:Find(w, true) then return false end
    end
    return true
  end
  local function Shown(name) local f = _G[name] return f and f.IsVisible and f:IsVisible() end

  -- right-click in bags; true = handled here (the game's click is skipped)
  function LZ.BagClick(bag, slot)
    local shift, ctrl, alt = IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown()
    if _G.CursorHasItem and _G.CursorHasItem() then return false end
    if On("split") and shift and not ctrl and not alt and not Shown("MerchantFrame") then
      local _, count = _G.GetContainerItemInfo(bag, slot)
      if (tonumber(count) or 1) > 1 then LZ.OpenSplit(bag, slot) return true end
      return false
    end
    if not On("rightclick") or shift or ctrl or alt then return false end
    if Shown("TradeFrame") then
      if not Tradeable(bag, slot) then Note("OctoLazy: that item cannot be traded") return true end
      local free = _G.TradeFrame_GetAvailableSlot and _G.TradeFrame_GetAvailableSlot()
      if not free then return true end
      _G.PickupContainerItem(bag, slot)
      _G.ClickTradeButton(free)
      if _G.CursorHasItem() then _G.ClearCursor() end
      return true
    end
    -- (pfUI Octo's own mail window has its own right-click: that one goes first)
    if Shown("MailFrame") and not (pfUI.mail and pfUI.mail.open and Shown("pfMail")) then
      if not Tradeable(bag, slot) then Note("OctoLazy: that item cannot be mailed") return true end
      if not Shown("SendMailFrame") and _G.MailFrameTab_OnClick then _G.MailFrameTab_OnClick(2) end
      _G.PickupContainerItem(bag, slot)
      _G.ClickSendMailItemButton()
      if _G.CursorHasItem() then _G.ClearCursor() end
      return true
    end
    return false
  end

  -- make stacks of N: each split waits until the stack is free again
  function LZ.FreeSlots()
    local out = {}
    for b = 0, 4 do
      local kind = b > 0 and _G.GetBagName and _G.GetBagName(b)
      for s = 1, (_G.GetContainerNumSlots(b) or 0) do
        if not _G.GetContainerItemLink(b, s) then table.insert(out, { b, s, kind }) end
      end
    end
    return out
  end
  function LZ.Split(bag, slot, size)
    local _, count = _G.GetContainerItemInfo(bag, slot)
    count, size = tonumber(count) or 1, math.floor(tonumber(size) or 0)
    if size < 1 or size >= count then return 0 end
    local want = math.floor((count - 1) / size)
    local free = LZ.FreeSlots()
    local moves = {}
    for i = 1, math.min(want, table.getn(free)) do table.insert(moves, { bag, slot, free[i][1], free[i][2], size }) end
    LZ.splits = moves
    if table.getn(moves) < want then Note("OctoLazy: only " .. table.getn(moves) .. " free bag slots") end
    return table.getn(moves)
  end
  function LZ.SplitTick()
    local m = LZ.splits and LZ.splits[1]
    if not m then LZ.splits = nil return end
    local _, _, locked = _G.GetContainerItemInfo(m[1], m[2])
    local _, _, dlocked = _G.GetContainerItemInfo(m[3], m[4])
    if locked or dlocked or (_G.CursorHasItem and _G.CursorHasItem()) then return end
    local _, left = _G.GetContainerItemInfo(m[1], m[2])
    if not left or (tonumber(left) or 0) <= m[5] then LZ.splits = nil return end
    table.remove(LZ.splits, 1)
    if _G.C_Container and type(_G.C_Container.MoveItem) == "function" then
      _G.C_Container.MoveItem(m[1], m[2], m[3], m[4], m[5])
    else
      _G.SplitContainerItem(m[1], m[2], m[5])
      _G.PickupContainerItem(m[3], m[4])
    end
  end

  -- the small split window
  function LZ.OpenSplit(bag, slot)
    local W = pfUI.octoui and pfUI.octoui.W
    if not W then return end
    local f = LZ.splitFrame
    if not f then
      local K = W.C
      f = CreateFrame("Frame", "pfOctoLazySplit", UIParent)
      f:SetWidth(250) f:SetHeight(112)
      f:SetFrameStrata("DIALOG")
      f:EnableMouse(true)
      f:SetMovable(true)
      f:RegisterForDrag("LeftButton")
      f:SetScript("OnDragStart", function() this:StartMoving() end)
      f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
      W.Flat(f, K.panel or K.btn, .97, K.accent)
      f.title = W.Font(f:CreateFontString(nil, "OVERLAY"), 12, 1, 1, 1)
      f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
      f.title:SetPoint("RIGHT", f, "RIGHT", -10, 0)
      f.title:SetJustifyH("LEFT")
      f.hint = W.Font(f:CreateFontString(nil, "OVERLAY"), 10, K.dim[1], K.dim[2], K.dim[3])
      f.hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
      f.hint:SetText("Stacks of how many?")
      f.box = W.EditBox(f, 56, "pfOctoLazySplitSize")
      f.box:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -46)
      f.box:SetNumeric(true)
      f.box:SetJustifyH("CENTER")
      local function Step(by)
        local v = math.max(1, (tonumber(f.box:GetText()) or 1) + by)
        f.box:SetText(v)
      end
      local minus = W.Button(f, "-", 24, 20)
      minus:SetPoint("RIGHT", f.box, "LEFT", -4, 0)
      minus:SetScript("OnClick", function() Step(IsShiftKeyDown() and -5 or -1) end)
      local plus = W.Button(f, "+", 24, 20)
      plus:SetPoint("LEFT", f.box, "RIGHT", 4, 0)
      plus:SetScript("OnClick", function() Step(IsShiftKeyDown() and 5 or 1) end)
      local half = W.Button(f, "Half", 52, 20)
      half:SetPoint("LEFT", plus, "RIGHT", 6, 0)
      half:SetScript("OnClick", function() f.box:SetText(math.max(1, math.floor((f.count or 2) / 2))) end)
      local go = W.Button(f, "Make stacks", 110, 22)
      go:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
      local function Go()
        local n = tonumber(f.box:GetText())
        G().splitsize = tostring(n or 1)
        local made = LZ.Split(f.bag, f.slot, n)
        if made > 0 then Note("OctoLazy: making " .. made .. " stacks of " .. n) end
        f:Hide()
      end
      go:SetScript("OnClick", Go)
      f.box:SetScript("OnEnterPressed", Go)
      local one = W.Button(f, "One to the cursor", 110, 22)
      one:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
      one:SetScript("OnClick", function()
        local n = tonumber(f.box:GetText()) or 1
        G().splitsize = tostring(n)
        _G.SplitContainerItem(f.bag, f.slot, n)
        f:Hide()
      end)
      f.box:SetScript("OnEscapePressed", function() f:Hide() end)
      tinsert(UISpecialFrames, "pfOctoLazySplit")
      LZ.splitFrame = f
    end
    local link = _G.GetContainerItemLink(bag, slot)
    local _, count = _G.GetContainerItemInfo(bag, slot)
    f.bag, f.slot, f.count = bag, slot, tonumber(count) or 1
    f.title:SetText("Split " .. (link or "stack") .. " |cffaaaaaa(" .. f.count .. ")|r")
    f.box:SetText(G().splitsize or "1")
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s - 125, y / s + 16)
    f:Show()
    f.box:SetFocus()
    f.box:HighlightText()
  end

  -- ================================================================ chat
  local function Pat(fmt)
    if type(fmt) ~= "string" then return nil end
    fmt = gsub(fmt, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    fmt = gsub(fmt, "%%s", ".+")
    fmt = gsub(fmt, "%%d", "%%d+")
    return "^" .. fmt
  end
  LZ.Pat = Pat
  function LZ.MuteWorldHere()
    if On("worldalways") then return true end
    local here = R.InstanceType()
    return (here == "raid" and On("worldraid")) or (here == "dungeon" and On("worlddungeon")) or (here == "pvp" and On("worldbg"))
  end
  -- true = the line is not shown
  function LZ.ChatDrop(event, msg, a2, a3, a4, a5, a6, a7, a8, a9)
    if not msg then return false end
    if event == "CHAT_MSG_LOOT" then
      local you = find(msg, "^" .. (_G.YOU or "You") .. "[ r]")
      if On("chatrolls") and not you and (find(msg, "ff1eff00") or find(msg, "ff0070dd")) then
        for _, k in ipairs({ "LOOT_ROLL_NEED", "LOOT_ROLL_GREED", "LOOT_ROLL_PASSED", "LOOT_ROLL_ROLLED_NEED", "LOOT_ROLL_ROLLED_GREED" }) do
          local p = Pat(_G[k])
          if p and find(msg, p) then return true end
        end
      end
      if On("chatjunk") and not you and (find(msg, "ff9d9d9d") or find(msg, "ffffffff")) then
        local p = Pat(_G.LOOT_ITEM)
        local p2 = Pat(_G.LOOT_ITEM_MULTIPLE)
        if (p and find(msg, p)) or (p2 and find(msg, p2)) then return true end
      end
    elseif event == "CHAT_MSG_MONEY" then
      if On("chatmoney") then return true end
    elseif event == "CHAT_MSG_CHANNEL" and On("worldmute") then
      local w = lower(G().worldname or "World")
      local name = lower(tostring(a9 or "") .. " " .. tostring(a4 or ""))
      if w ~= "" and find(name, w, 1, true) and LZ.MuteWorldHere() then return true end
    end
    return false
  end

  -- ================================================================ more
  LZ.SALV = { "Spell_Holy_SealOfSalvation", "Spell_Holy_GreaterBlessingofSalvation" }
  function LZ.IsTank()
    local _, class = UnitClass("player")
    if class == "WARRIOR" then
      if _G.IsEquippedItemType and _G.IsEquippedItemType("Shields") then return true end
      local _, _, active = _G.GetShapeshiftFormInfo and _G.GetShapeshiftFormInfo(2)
      return active and true or false
    elseif class == "DRUID" then
      for i = 1, (_G.GetNumShapeshiftForms and _G.GetNumShapeshiftForms() or 0) do
        local _, name, active = _G.GetShapeshiftFormInfo(i)
        if active and name and find(lower(name), "bear", 1, true) then return true end
      end
    elseif class == "PALADIN" then
      for i = 0, 31 do
        local idx = _G.GetPlayerBuff(i, "HELPFUL")
        if idx and idx >= 0 then
          local tex = _G.GetPlayerBuffTexture(idx)
          if tex and find(tex, "SealOfFury", 1, true) then return true end
        end
      end
    end
    return false
  end
  function LZ.Salvation()
    local m = G().salva
    if m ~= "always" and not (m == "tank" and LZ.IsTank()) then return end
    for i = 0, 31 do
      local idx = _G.GetPlayerBuff(i, "HELPFUL")
      if idx and idx >= 0 then
        local tex = _G.GetPlayerBuffTexture(idx) or ""
        for j = 1, table.getn(LZ.SALV) do
          if find(tex, LZ.SALV[j], 1, true) then
            _G.CancelPlayerBuff(idx)
            Note("OctoLazy: Salvation removed")
            return true
          end
        end
      end
    end
  end

  function LZ.Camera()
    if On("camera") and _G.SetCVar then _G.SetCVar("cameraDistanceMax", Num("cameradist", 50)) end
  end

  -- key combinations, held for a moment
  function LZ.Combo()
    local s, c, a = IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown()
    if c and a and s then return On("keylogout") and "logout" or nil end
    if c and a then return "ctrlalt" end
    if c and s then return "ctrlshift" end
    if a and s then return "altshift" end
  end
  function LZ.DoCombo(k)
    if k == "logout" then _G.Logout() return end
    if k == "ctrlalt" then
      if On("greenkey") and LZ.GreenKey() then return end
      if not On("keys") then return end
      if Shown("TradeFrame") then _G.AcceptTrade() return end
      if UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player", "target") and not UnitIsUnit("player", "target")
        and CheckInteractDistance("target", 2) then _G.InitiateTrade("target") end
      return
    end
    if not On("keys") or not UnitExists("target") or not UnitIsPlayer("target") then return end
    if k == "ctrlshift" and UnitIsFriend("player", "target") then _G.FollowUnit("target") end
    if k == "altshift" then _G.InspectUnit("target") end
  end

  -- ================================================================ the game's calls
  LZ.Bind = function(which)
    if which == "efc" then LZ.TargetEFC() elseif which == "drop" then LZ.DropFlag() elseif which == "duel" then LZ.DuelKey()
    elseif which == "reload" then _G.ReloadUI() elseif which == "logout" then _G.Logout() end
  end
  _G.BINDING_HEADER_PFLAZY = "pfUI Octo: OctoLazy"
  _G.BINDING_NAME_PFLAZYEFC = "Target the enemy flag carrier"
  _G.BINDING_NAME_PFLAZYDROP = "Drop the flag / remove Slow Fall"
  _G.BINDING_NAME_PFLAZYDUEL = "Duel the target / cancel the duel (WSG: flag carrier)"
  _G.BINDING_NAME_PFLAZYRELOAD = "Reload the interface"
  _G.BINDING_NAME_PFLAZYLOGOUT = "Log out"

  if LZ.Other() then
    LZ.aside = true
    return
  end

  -- right-click in bags
  local useItem = _G.UseContainerItem
  LZ.rawUse = useItem
  _G.UseContainerItem = function(bag, slot, a, b)
    if LZ.BagClick(bag, slot) then return end
    return useItem(bag, slot, a, b)
  end
  -- chat lines
  local chatEvent = _G.ChatFrame_OnEvent
  if type(chatEvent) == "function" then
    _G.ChatFrame_OnEvent = function(e)
      if LZ.ChatDrop(e, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) then return end
      return chatEvent(e)
    end
  end

  local f = CreateFrame("Frame", "pfOctoLazy")
  LZ.frame = f
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CONFIRM_LOOT_ROLL", "LOOT_BIND_CONFIRM",
    "PARTY_INVITE_REQUEST", "CONFIRM_SUMMON", "RESURRECT_REQUEST", "DUEL_REQUESTED", "DUEL_FINISHED", "GUILD_INVITE_REQUEST",
    "UPDATE_BATTLEFIELD_STATUS", "BATTLEFIELDS_SHOW", "PLAYER_DEAD", "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE",
    "CHAT_MSG_BG_SYSTEM_NEUTRAL", "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
    "QUEST_COMPLETE", "QUEST_FINISHED", "PLAYER_AURAS_CHANGED", "UPDATE_SHAPESHIFT_FORMS", "UNIT_INVENTORY_CHANGED" }) do
    -- (an event this client does not have is skipped, not an error)
    pcall(f.RegisterEvent, f, e)
  end
  f:SetScript("OnEvent", function()
    local e = event
    if e == "START_LOOT_ROLL" then LZ.OnRoll(arg1, arg2)
    elseif e == "CANCEL_LOOT_ROLL" then LZ.open[arg1], LZ.pending[arg1], LZ.mine[arg1] = nil, nil, nil
    elseif e == "CONFIRM_LOOT_ROLL" then LZ.OnConfirmRoll(arg1, arg2)
    elseif e == "LOOT_BIND_CONFIRM" then
      if On("lootbind") and not R.env.InGroup() and _G.ConfirmLootSlot then
        _G.ConfirmLootSlot(arg1)
        if _G.StaticPopup_Hide then _G.StaticPopup_Hide("LOOT_BIND") end
      end
    elseif e == "PARTY_INVITE_REQUEST" then LZ.OnInvite(arg1)
    elseif e == "CONFIRM_SUMMON" then LZ.OnSummon()
    elseif e == "RESURRECT_REQUEST" then LZ.pendingRez = arg1 LZ.OnRez(arg1)
    elseif e == "DUEL_REQUESTED" then LZ.dueling = true LZ.OnDuel(arg1)
    elseif e == "DUEL_FINISHED" then LZ.dueling = nil
    elseif e == "GUILD_INVITE_REQUEST" then
      if On("guildinv") then
        _G.DeclineGuild()
        if _G.StaticPopup_Hide then _G.StaticPopup_Hide("GUILD_INVITE") end
        Say("turned down a guild invite from " .. tostring(arg1) .. " (" .. tostring(arg2) .. ")")
      end
    elseif e == "UPDATE_BATTLEFIELD_STATUS" or e == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then LZ.OnBattlefield()
    elseif e == "BATTLEFIELDS_SHOW" then LZ.OnBattleMaster()
    elseif e == "PLAYER_DEAD" then
      if On("bgrelease") and R.InstanceType() == "pvp" and not (_G.HasSoulstone and _G.HasSoulstone()) then _G.RepopMe() end
    elseif e == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or e == "CHAT_MSG_BG_SYSTEM_HORDE" then LZ.OnFlagLine(arg1)
    elseif e == "GOSSIP_SHOW" then LZ.OnGossip()
    elseif e == "GOSSIP_CLOSED" or e == "QUEST_FINISHED" then LZ.tried = {}
    elseif e == "QUEST_GREETING" then LZ.OnGreeting()
    elseif e == "QUEST_DETAIL" then LZ.OnQuestDetail()
    elseif e == "QUEST_PROGRESS" then LZ.OnQuestProgress()
    elseif e == "QUEST_COMPLETE" then LZ.OnQuestComplete()
    elseif e == "PLAYER_AURAS_CHANGED" or e == "UPDATE_SHAPESHIFT_FORMS" or (e == "UNIT_INVENTORY_CHANGED" and arg1 == "player") then
      if G().salva ~= "off" then LZ.Salvation() end
    elseif e == "PLAYER_ENTERING_WORLD" then
      LZ.Camera()
      LZ.efc, LZ.fc, LZ.leaveAt = nil, nil, nil
    end
  end)

  local roster, combo, comboAt, comboDone = 0, nil, 0, nil
  f:SetScript("OnUpdate", function()
    local now = Now()
    for id, p in pairs(LZ.pending) do if now >= p.at then LZ.Roll(id, p.act, p.why) end end
    for id, o in pairs(LZ.open) do if o.ends and now > o.ends + 5 then LZ.open[id] = nil end end
    if LZ.summonAt and now >= LZ.summonAt then LZ.DoSummon() end
    if LZ.rezAt and now >= LZ.rezAt then LZ.rezAt = nil LZ.OnRez(LZ.pendingRez) end
    for i, at in pairs(LZ.bgAt) do if now >= at then LZ.EnterBG(i) end end
    if LZ.leaveAt and now >= LZ.leaveAt then
      LZ.leaveAt = nil
      if _G.GetBattlefieldWinner and _G.GetBattlefieldWinner() then _G.LeaveBattlefield() end
    end
    if LZ.splits then LZ.SplitTick() end
    -- key combinations: held .35 s, once per press
    local k = LZ.Combo()
    if k ~= combo then combo, comboAt, comboDone = k, now, nil
    elseif k and not comboDone and now - comboAt > .35 then comboDone = true LZ.DoCombo(k) end
    -- the guild list, for invites from guild members
    if On("invguild") and now - roster > 60 and _G.IsInGuild and _G.IsInGuild() then roster = now _G.GuildRoster() end
  end)

  -- /lazy (and /lp while _LazyPig is not here)
  _G.SLASH_PFOCTOLAZY1 = "/lazy"
  _G.SLASH_PFOCTOLAZY2 = "/octolazy"
  if not _G.SLASH_LAZYPIG1 then _G.SLASH_PFOCTOLAZY3 = "/lp" end
  _G.SlashCmdList.PFOCTOLAZY = function()
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Open then O:Open("lzrolls") end
  end
end)
