pfUI:RegisterModule("octoboards", "vanilla", function ()
  -- pfUI Octo :: OctoBoards, the leaderboards (26 Nov 2026; user: "a pfui leaderboard ... showing some fun data", then
  -- picked all three layouts as tabs: "i want amazing art work and text clean").
  --   Awards   tonight's raid or dungeon: a podium for damage, then award cards (kick champion, cleanse champion, floor
  --            inspector, biggest crit, iron wall, lifesaver). Every raider sees the same combat log, so these come from
  --            the meters' own fights - nothing has to be sent.
  --   Boards   counts kept by pfUI Octo itself from the day it is installed (kills, deaths, gold looted, flights, jumps...)
  --            per character, this week and all time, shared with other pfUI Octo users in your guild / raid over the
  --            addon channel (prefix pfLB, "^"-separated, never "|"); scopes Guild / Raid / Friends.
  --   Player   one player's card: their numbers, their rank in each, crowns for every board they lead this week.
  -- This 1.12 client has no statistics calls (checked WoW.exe and ClassicAPI): what the game does know is read where it
  -- can be - honourable kills (GetPVPLifetimeStats), quests done (ClassicAPI GetQuestsCompleted).
  -- Data: pfUI_cache.boards (per account): me[Name-Realm] = { class, level, all = {}, wk, week = {} }, others[name],
  -- night (this raid / dungeon), nights (the last 5). /boards [name], /lb.
  local LB = {}
  pfUI.boards = LB
  local W = pfUI.octoui and pfUI.octoui.W
  local PAL = (W and W.C) or { bg = { .067, .071, .078 }, panel = { .094, .098, .11 }, card = { .125, .13, .145 },
    line = { .23, .24, .27 }, text = { .92, .92, .93 }, dim = { .6, .61, .65 }, accent = { .2, .7, 1 }, label = { .52, .53, .57 } }
  local ICON = "Interface\\Icons\\"
  local GLUE = "Interface\\Glues\\LoadingScreens\\"
  local FONT = "Interface\\AddOns\\pfUI\\fonts\\"
  local floor, fmt = math.floor, string.format
  local function Now() return GetTime and GetTime() or 0 end
  local function T() return time and time() or 0 end

  -- ------------------------------------------------------------------ what is counted
  -- key (short: it goes over the addon channel), label, icon, board, kind (sum | max | set), how it reads
  LB.STATS = {
    { "kl", "Creatures killed", "Ability_DualWield", "combat", "sum" },
    { "kb", "Killing blows", "Ability_Rogue_Eviscerate", "combat", "sum" },
    { "dm", "Damage done", "Spell_Fire_Fireball02", "combat", "sum", "big" },
    { "bc", "Biggest crit", "Spell_Nature_Lightning", "combat", "max" },
    { "it", "Interrupts", "Ability_Kick", "combat", "sum" },
    { "dt", "Deaths", "INV_Misc_Bone_HumanSkull_01", "combat", "sum" },
    { "hl", "Healing done", "Spell_Holy_Heal", "healing", "sum", "big" },
    { "bh", "Biggest heal", "Spell_Holy_PrayerOfHealing02", "healing", "max" },
    { "dp", "Dispels", "Spell_Holy_DispelMagic", "healing", "sum" },
    { "bd", "Bandages used", "INV_Misc_Bandage_15", "healing", "sum" },
    { "gl", "Gold looted", "INV_Misc_Coin_01", "wealth", "sum", "money" },
    { "mg", "Most gold held", "INV_Misc_Coin_02", "wealth", "max", "money" },
    { "ep", "Epic items looted", "INV_Jewelry_Talisman_07", "wealth", "sum" },
    { "qd", "Quests completed", "INV_Misc_Note_01", "wealth", "sum" },
    { "fl", "Flights taken", "Ability_Mount_Gryphon_01", "travel", "sum" },
    { "hs", "Hearthstones", "Spell_Arcane_TeleportStormwind", "travel", "sum" },
    { "hb", "Herbs gathered", "INV_Misc_Herb_10", "travel", "sum" },
    { "or", "Ore mined", "INV_Ore_Copper_01", "travel", "sum" },
    { "fi", "Fish caught", "INV_Misc_Fish_02", "travel", "sum" },
    { "hk", "Honourable kills", "INV_BannerPVP_02", "pvp", "set" },
    { "dw", "Duels won", "INV_Sword_39", "pvp", "sum" },
    { "dl", "Duels lost", "INV_Shield_06", "pvp", "sum" },
    { "jp", "Jumps", "Ability_Rogue_Sprint", "silly", "sum" },
    { "fa", "Fall damage taken", "INV_Feather_01", "silly", "sum" },
    { "em", "Emotes", "Spell_Nature_Polymorph", "silly", "sum" },
    { "ws", "Whispers sent", "INV_Misc_Book_09", "silly", "sum" },
    { "af", "Time AFK", "Spell_Nature_Sleep", "silly", "sum", "time" },
  }
  LB.BY = {}
  for _, s in ipairs(LB.STATS) do LB.BY[s[1]] = s end
  LB.CATS = {
    { "combat", "Combat", "Ability_DualWield" }, { "healing", "Healing", "Spell_Holy_Heal" },
    { "wealth", "Wealth", "INV_Misc_Coin_01" }, { "travel", "Travel and gathering", "Ability_Mount_Gryphon_01" },
    { "pvp", "PvP", "INV_BannerPVP_02" }, { "silly", "Just for fun", "Spell_Nature_Polymorph" },
  }

  -- ------------------------------------------------------------------ storage
  local function DB()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.boards = pfUI_cache.boards or {}
    local d = pfUI_cache.boards
    d.me, d.others, d.nights = d.me or {}, d.others or {}, d.nights or {}
    return d
  end
  LB.DB = DB
  function LB.Week() return date and date("%Y-%W") or "0" end
  function LB.MeName() return (UnitName and (UnitName("player"))) or "?" end
  function LB.Me()
    local d = DB()
    local key = LB.MeName() .. "-" .. ((GetRealmName and GetRealmName()) or "")
    local m = d.me[key]
    if not m then m = { all = {}, week = {}, wk = LB.Week() } d.me[key] = m end
    local _, class = UnitClass("player")
    m.name, m.class, m.level = LB.MeName(), class, UnitLevel and UnitLevel("player")
    if m.wk ~= LB.Week() then m.wk, m.week = LB.Week(), {} end
    return m
  end
  -- counting: sum adds, max keeps the highest, set replaces (numbers the game itself keeps)
  function LB.Add(key, n)
    local s = LB.BY[key]
    if not s or not n or n == 0 then return end
    if LB.Quiet() then return end
    local m = LB.Me()
    local kind = s[5]
    for _, t in ipairs({ m.all, m.week }) do
      if kind == "max" then
        if n > (t[key] or 0) then t[key] = n end
      elseif kind == "set" then
        if t == m.all then t[key] = n end
      else
        t[key] = (t[key] or 0) + n
      end
    end
    LB.dirty = true
  end
  -- the demo, the stress test and the meters' test fight count nothing
  function LB.Quiet()
    if pfUI.demo and pfUI.demo.on then return true end
    if pfUI.perf and pfUI.perf.stress then return true end
    local M = pfUI.meters
    return M and M.testOn and true or false
  end

  -- ------------------------------------------------------------------ reading the game
  local function Pat(g)
    local s = rawget(_G, g)
    if type(s) ~= "string" then return nil end
    s = string.gsub(s, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    s = string.gsub(s, "%%%%%d%%%$s", "(.+)")
    s = string.gsub(s, "%%%%%d%%%$d", "(%%d+)")
    s = string.gsub(s, "%%%%s", "(.+)")
    s = string.gsub(s, "%%%%d", "(%%d+)")
    return "^" .. s .. "$"
  end
  local PATS = {}
  local function P(g) if PATS[g] == nil then PATS[g] = Pat(g) or false end return PATS[g] end
  LB.Pat = P
  -- the last number in a line
  local function LastNum(a, b, c)
    return tonumber(c) or tonumber(b) or tonumber(a)
  end
  local function Match(msg, g)
    local p = P(g)
    if not p or type(msg) ~= "string" then return nil end
    return string.find(msg, p)
  end
  -- copper from "You loot 2 Gold, 13 Silver, 5 Copper"
  function LB.Coins(msg)
    local c = 0
    local G, S2, Cu = string.lower(rawget(_G, "GOLD") or "gold"), string.lower(rawget(_G, "SILVER") or "silver"),
      string.lower(rawget(_G, "COPPER") or "copper")
    for n, w in string.gfind(msg or "", "(%d+) (%a+)") do
      w = string.lower(w)
      if w == G then c = c + n * 10000 elseif w == S2 then c = c + n * 100 elseif w == Cu then c = c + n end
    end
    return c
  end
  local gatherAt, gatherKey = 0, nil
  LB.GATHER = { ["Herb Gathering"] = "hb", ["Mining"] = "or", ["Fishing"] = "fi" }
  function LB.OnEvent(e, a1)
    if e == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
      if Match(a1, "SELFKILLOTHER") then LB.Add("kl", 1) LB.Add("kb", 1) end
    elseif e == "PLAYER_DEAD" then LB.Add("dt", 1)
    elseif e == "CHAT_MSG_COMBAT_SELF_HITS" or e == "CHAT_MSG_SPELL_SELF_DAMAGE" then
      local a, b, c, d = Match(a1, "COMBATHITCRITSELFOTHER")
      if not a then a, b, c, d = Match(a1, "SPELLLOGCRITSELFOTHER") end
      if not a then a, b, c, d = Match(a1, "SPELLLOGCRITSCHOOLSELFOTHER") end
      if a then LB.Add("bc", LastNum(c, d)) end
      if Match(a1, "VSENVIRONMENTALDAMAGE_FALLING_SELF") then LB.Add("fa", 1) end
    elseif e == "CHAT_MSG_SPELL_SELF_BUFF" then
      local a, b, c, d, x = Match(a1, "HEALEDCRITSELFOTHER")
      if not a then a, b, c, d, x = Match(a1, "HEALEDCRITSELFSELF") end
      if not a then a, b, c, d, x = Match(a1, "HEALEDSELFOTHER") end
      if not a then a, b, c, d, x = Match(a1, "HEALEDSELFSELF") end
      if a then LB.Add("bh", LastNum(c, d, x)) end
    elseif e == "CHAT_MSG_MONEY" then
      LB.Add("gl", LB.Coins(a1))
    elseif e == "PLAYER_MONEY" then
      LB.Add("mg", GetMoney and GetMoney() or 0)
    elseif e == "CHAT_MSG_LOOT" then
      local a, b, link, count = Match(a1, "LOOT_ITEM_SELF_MULTIPLE")
      if not a then a, b, link = Match(a1, "LOOT_ITEM_SELF") end
      if not a then a, b, link, count = Match(a1, "LOOT_ITEM_PUSHED_SELF_MULTIPLE") end
      if not a then a, b, link = Match(a1, "LOOT_ITEM_PUSHED_SELF") end
      if a then
        if type(link) == "string" and string.find(link, "|cffa335ee") then LB.Add("ep", 1) end
        if gatherKey and Now() - gatherAt < 8 then LB.Add(gatherKey, tonumber(count) or 1) end
      end
    elseif e == "SPELLCAST_START" then
      if a1 == "Hearthstone" then LB.Add("hs", 1) end
      if a1 == "First Aid" or (type(a1) == "string" and string.find(a1, "Bandage")) then LB.Add("bd", 1) end
      if LB.GATHER[a1 or ""] then gatherKey, gatherAt = LB.GATHER[a1], Now() end
    elseif e == "SPELLCAST_CHANNEL_START" then
      if a1 == "First Aid" then LB.Add("bd", 1) end
      if LB.GATHER[_G.arg2 or ""] then gatherKey, gatherAt = LB.GATHER[_G.arg2], Now() end
    elseif e == "CHAT_MSG_SYSTEM" then
      local a, b, win, lose = Match(a1, "DUEL_WINNER_KNOCKOUT")
      if not a then a, b, win, lose = Match(a1, "DUEL_WINNER_RETREAT") end
      if a then
        local me = LB.MeName()
        if win == me then LB.Add("dw", 1) elseif lose == me then LB.Add("dl", 1) end
      end
    elseif e == "PLAYER_ENTERING_WORLD" then
      LB.ReadGame()
    elseif e == "CHAT_MSG_ADDON" then
      if a1 == LB.PREFIX then LB.Receive(_G.arg2, _G.arg3, _G.arg4) end
    end
  end
  -- (26 Nov 2026, user: "make sure data doesn't pile up") players not heard from in 60 days are forgotten, and at most
  -- 400 are kept (the longest unseen go first); nights are already capped at 5
  LB.KEEP_DAYS, LB.KEEP_MAX = 60, 400
  function LB.Prune()
    local d = DB()
    local now, list = T(), {}
    for name, o in pairs(d.others) do
      if not o.t or now - o.t > LB.KEEP_DAYS * 86400 then d.others[name] = nil else table.insert(list, { name, o.t }) end
    end
    if table.getn(list) > LB.KEEP_MAX then
      table.sort(list, function(a, b) return a[2] > b[2] end)
      for i = LB.KEEP_MAX + 1, table.getn(list) do d.others[list[i][1]] = nil end
    end
    while table.getn(d.nights) > 5 do table.remove(d.nights) end
  end
  -- numbers the game itself keeps
  function LB.ReadGame()
    LB.Prune()
    if GetPVPLifetimeStats then
      local ok, hk = pcall(GetPVPLifetimeStats)
      if ok and tonumber(hk) then LB.Add("hk", tonumber(hk)) end
    end
    LB.Add("mg", GetMoney and GetMoney() or 0)
    local gq = rawget(_G, "GetQuestsCompleted")
    if type(gq) == "function" then
      local ok, t = pcall(gq)
      if ok and type(t) == "table" then
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        local m = LB.Me()
        -- (all time: the game's own count when it is higher; the week keeps counting turn-ins)
        if n > (m.all.qd or 0) then m.all.qd = n end
      end
    end
  end

  local ev = CreateFrame("Frame", "pfOctoBoardsEvents")
  LB.events = ev
  for _, e in ipairs({ "CHAT_MSG_COMBAT_HOSTILE_DEATH", "PLAYER_DEAD", "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_SPELL_SELF_DAMAGE",
    "CHAT_MSG_SPELL_SELF_BUFF", "CHAT_MSG_MONEY", "PLAYER_MONEY", "CHAT_MSG_LOOT", "SPELLCAST_START", "SPELLCAST_CHANNEL_START",
    "CHAT_MSG_SYSTEM", "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON" }) do ev:RegisterEvent(e) end
  ev:SetScript("OnEvent", function() LB.OnEvent(event, arg1) end)

  -- the game's own calls: flights, quest turn-ins, jumps, emotes, whispers
  local function After(name, fn)
    local orig = rawget(_G, name)
    if type(orig) ~= "function" then return end
    _G[name] = function(a, b, c, d, e) local r1, r2 = orig(a, b, c, d, e) pcall(fn, a, b, c, d, e) return r1, r2 end
  end
  After("TakeTaxiNode", function() LB.Add("fl", 1) end)
  After("GetQuestReward", function() LB.Add("qd", 1) end)
  After("JumpOrAscendStart", function() LB.Add("jp", 1) end)
  After("DoEmote", function() LB.Add("em", 1) end)
  After("SendChatMessage", function(msg, chan) if chan == "WHISPER" then LB.Add("ws", 1) end end)

  -- the meters' fights: your damage / healing / interrupts / dispels, and tonight's awards for everyone
  local M = pfUI.meters
  if M and M.EndFight then
    local endFight = M.EndFight
    M.EndFight = function()
      local seg = M.current
      endFight()
      if seg then pcall(LB.Fight, seg) end
    end
  end
  function LB.Fight(seg)
    if LB.Quiet() or not seg or not seg.actors then return end
    local me = seg.actors[LB.MeName()]
    if me then
      LB.Add("dm", floor(me.damage or 0))
      LB.Add("hl", floor(me.heal or 0))
      LB.Add("it", me.interrupts or 0)
      LB.Add("dp", me.dispels or 0)
    end
    LB.Night(seg)
  end
  -- a raid or dungeon night: one per instance visit (a new one after 4 hours away or in another place)
  function LB.Night(seg)
    local inside, kind = false, nil
    if IsInInstance then inside, kind = IsInInstance() end
    if not inside or (kind ~= "raid" and kind ~= "party") then return end
    local d = DB()
    local zone = (GetRealZoneText and GetRealZoneText()) or "?"
    local n = d.night
    if not n or n.zone ~= zone or T() - (n.last or 0) > 4 * 3600 then
      if n then
        table.insert(d.nights, 1, n)
        while table.getn(d.nights) > 5 do table.remove(d.nights) end
      end
      n = { zone = zone, kind = kind, start = T(), last = T(), bosses = 0, fights = 0, p = {}, bossList = {} }
      d.night = n
    end
    n.last, n.fights = T(), n.fights + 1
    if seg.boss then n.bosses = n.bosses + 1 table.insert(n.bossList, seg.boss) end
    for name, a in pairs(seg.actors) do
      if a.class then
        local p = n.p[name] or { class = a.class, dm = 0, hl = 0, it = 0, dp = 0, dt = 0, tk = 0, bc = 0 }
        n.p[name] = p
        p.dm, p.hl, p.tk = p.dm + floor(a.damage or 0), p.hl + floor(a.heal or 0), p.tk + floor(a.taken or 0)
        p.it, p.dp, p.dt = p.it + (a.interrupts or 0), p.dp + (a.dispels or 0), p.dt + (a.deaths or 0)
        for _, s in pairs(a.spells or {}) do if (s.cmax or 0) > p.bc then p.bc, p.bcs = s.cmax, s.name end end
      end
    end
    LB.dirty = true
  end

  -- AFK time, counted every 5 s
  local tick = CreateFrame("Frame")
  tick.at = 0
  tick:SetScript("OnUpdate", function()
    if Now() < this.at then return end
    this.at = Now() + 5
    if UnitIsAFK and UnitIsAFK("player") then LB.Add("af", 5) end
    LB.ShareTick()
  end)

  -- ------------------------------------------------------------------ sharing
  -- "A^class^level^k=v,k=v" (all time) and "W^week^k=v,..." (this week); "Q" asks everyone for theirs. To GUILD
  -- 30 s after login and every 15 min when something changed; to RAID once when you join one.
  LB.PREFIX = "pfLB"
  local function Pack(t)
    local parts = {}
    for _, s in ipairs(LB.STATS) do
      local v = t[s[1]]
      if v and v > 0 then table.insert(parts, s[1] .. "=" .. floor(v)) end
    end
    return table.concat(parts, ",")
  end
  local function Unpack(s, into)
    for k, v in string.gfind(s or "", "(%a%a)=(%d+)") do into[k] = tonumber(v) end
    return into
  end
  LB.Pack, LB.Unpack = Pack, Unpack
  function LB.Lines()
    local m = LB.Me()
    return { "A^" .. (m.class or "") .. "^" .. (m.level or 0) .. "^" .. Pack(m.all), "W^" .. m.wk .. "^" .. Pack(m.week) }
  end
  -- (27 Nov 2026) one addon message, paced through OctoShare's governor so the feeds together never trip the chat
  -- throttle, and to the realm channel when one is set; plain send as the fallback
  local function OSend(msg, chan)
    local os = pfUI.octoshare
    if os and os.Send then os.Send(LB.PREFIX, msg, chan)
    elseif SendAddonMessage then pcall(SendAddonMessage, LB.PREFIX, msg, chan) end
    local x = os and os.ExtraChannel and os.ExtraChannel()
    if x and os and os.Send then os.Send(LB.PREFIX, msg, x[1], x[2]) end
  end
  local function Send(chan)
    for _, l in ipairs(LB.Lines()) do OSend(l, chan) end
  end
  LB.Send = Send
  local shared = { login = nil, at = 0, raid = nil, asked = 0, answer = nil }
  function LB.ShareTick()
    local now = Now()
    if not shared.login then shared.login = now + 30 end
    local guild = IsInGuild and IsInGuild()
    if guild and shared.login and now >= shared.login then
      shared.login = false
      Send("GUILD")
      OSend("Q", "GUILD")
      shared.at = now
    elseif guild and LB.dirty and now - shared.at > 900 then
      LB.dirty = nil
      Send("GUILD")
      shared.at = now
    end
    local raid = GetNumRaidMembers and GetNumRaidMembers() > 0
    if raid and not shared.raid then shared.raid = true Send("RAID") OSend("Q", "RAID")
    elseif not raid then shared.raid = nil end
    if shared.answer and now >= shared.answer.at then
      Send(shared.answer.chan)
      shared.answer = nil
    end
  end
  function LB.Receive(msg, chan, who)
    if type(msg) ~= "string" or not who or who == LB.MeName() then return end
    if msg == "Q" then
      -- answered a few seconds later, at most once a minute
      if Now() - shared.asked > 60 then shared.asked = Now() shared.answer = { chan = chan, at = Now() + 2 + math.random() * 6 } end
      return
    end
    local d = DB()
    local o = d.others[who] or { all = {}, week = {} }
    d.others[who] = o
    o.t = T()
    if chan == "GUILD" then o.guild = true end
    if chan == "RAID" or chan == "PARTY" then o.raid = T() end
    local _, _, kind, a, b, rest = string.find(msg, "^(%a)%^([^%^]*)%^([^%^]*)%^?(.*)$")
    if kind == "A" then
      o.class, o.level = a ~= "" and a or o.class, tonumber(b) or o.level
      o.all = Unpack(rest, {})
    elseif kind == "W" then
      o.wk, o.week = a, Unpack(b, {})
    end
  end

  -- ------------------------------------------------------------------ the boards
  -- scope guild | raid | friends | all; period week | all -> { { name, class, value, me } } best first
  function LB.InScope(name, o, scope)
    if scope == "all" then return true end
    if scope == "guild" then return o and o.guild end
    if scope == "raid" then
      for i = 1, (GetNumRaidMembers and GetNumRaidMembers() or 0) do if UnitName("raid" .. i) == name then return true end end
      for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do if UnitName("party" .. i) == name then return true end end
      return false
    end
    if scope == "friends" then
      for i = 1, (GetNumFriends and GetNumFriends() or 0) do if GetFriendInfo(i) == name then return true end end
      return false
    end
    return true
  end
  function LB.Board(key, scope, period)
    local rows = {}
    local m = LB.Me()
    local mine = (period == "week" and m.week or m.all)[key] or 0
    table.insert(rows, { name = m.name, class = m.class, value = mine, me = true })
    local wk = LB.Week()
    for name, o in pairs(DB().others) do
      if LB.InScope(name, o, scope) then
        local t = period == "week" and (o.wk == wk and o.week or {}) or o.all
        local v = t and t[key]
        if v and v > 0 then table.insert(rows, { name = name, class = o.class, value = v }) end
      end
    end
    table.sort(rows, function(x, y) if x.value ~= y.value then return x.value > y.value end return x.name < y.name end)
    for i, r in ipairs(rows) do r.rank = i end
    return rows
  end
  -- a player's numbers and their rank on each board (guild, week)
  function LB.Player(name)
    local m = LB.Me()
    local o = (name == nil or name == m.name) and { all = m.all, week = m.week, class = m.class, level = m.level, me = true }
      or DB().others[name]
    return o
  end
  function LB.Rank(name, key, scope, period)
    for _, r in ipairs(LB.Board(key, scope, period)) do if r.name == name then return r.rank, r.value end end
  end
  -- tonight's awards from a night table: { key, title, icon, who, class, value text, line }
  LB.AWARDS = {
    { "dm", "Top damage", "Spell_Fire_Fireball02", "big" },
    { "hl", "Top healing", "Spell_Holy_Heal", "big" },
    { "it", "Kick champion", "Ability_Kick", "n" },
    { "dp", "Cleanse champion", "Spell_Holy_DispelMagic", "n" },
    { "bc", "Biggest crit", "Spell_Nature_Lightning", "n" },
    { "tk", "Iron wall", "Ability_Warrior_DefensiveStance", "big" },
    { "dt", "Floor inspector", "INV_Misc_Bone_HumanSkull_01", "n" },
  }
  function LB.Awards(n)
    local out = {}
    if not n then return out end
    for _, a in ipairs(LB.AWARDS) do
      local best, bv, bc, extra = nil, 0, nil, nil
      for name, p in pairs(n.p) do
        local v = p[a[1]] or 0
        if v > bv then best, bv, bc, extra = name, v, p.class, a[1] == "bc" and p.bcs or nil end
      end
      if best then table.insert(out, { key = a[1], title = a[2], icon = a[3], who = best, class = bc, value = bv,
        text = LB.Num(bv, a[4]) .. (extra and (" " .. extra) or "") .. (a[1] == "dt" and " deaths" or "") }) end
    end
    return out
  end
  function LB.Podium(n)
    local list = {}
    if not n then return list end
    for name, p in pairs(n.p) do table.insert(list, { name = name, class = p.class, value = p.dm }) end
    table.sort(list, function(x, y) return x.value > y.value end)
    return list
  end

  -- ------------------------------------------------------------------ words for numbers
  function LB.Num(v, how)
    v = tonumber(v) or 0
    if how == "money" then
      local g = floor(v / 10000)
      if g >= 1 then return (g >= 1000 and fmt("%d,%03d", floor(g / 1000), math.mod(g, 1000)) or g) .. "g" end
      return floor(v / 100) .. "s"
    elseif how == "time" then
      local h = floor(v / 3600)
      return h > 0 and (h .. "h " .. floor(math.mod(v, 3600) / 60) .. "m") or (floor(v / 60) .. "m")
    elseif how == "big" or v >= 100000 then
      if v >= 1000000 then return fmt("%.2fM", v / 1000000) end
      if v >= 10000 then return fmt("%.1fk", v / 1000) end
    end
    if v >= 1000 then return fmt("%d,%03d", floor(v / 1000), math.mod(floor(v), 1000)) end
    return tostring(floor(v))
  end
  function LB.Value(key, v) local s = LB.BY[key] return LB.Num(v, s and s[6]) end
  function LB.ClassColor(class)
    local c = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return .85, .85, .87
  end
  function LB.ClassHex(class)
    local r, g, b = LB.ClassColor(class)
    return fmt("%02x%02x%02x", r * 255, g * 255, b * 255)
  end
  -- Discord text of tonight
  function LB.DiscordText(n)
    if not n then return "" end
    local lines = { ":trophy: **" .. n.zone .. "** - " .. n.bosses .. " bosses, " .. n.fights .. " fights" }
    local pod = LB.Podium(n)
    local medal = { ":first_place:", ":second_place:", ":third_place:" }
    for i = 1, math.min(3, table.getn(pod)) do
      table.insert(lines, medal[i] .. " " .. pod[i].name .. " - " .. LB.Num(pod[i].value, "big") .. " damage")
    end
    for _, a in ipairs(LB.Awards(n)) do
      if a.key ~= "dm" then table.insert(lines, ":small_orange_diamond: " .. a.title .. ": **" .. a.who .. "** (" .. a.text .. ")") end
    end
    return table.concat(lines, "\n")
  end

  -- sample night and players, for the window before any data and for the tests
  function LB.SampleNight()
    local p = {}
    local roster = { { "Isolde", "MAGE" }, { "Lucan", "WARLOCK" }, { "Gideon", "ROGUE" }, { "Brenna", "WARRIOR" },
      { "Mirelle", "PRIEST" }, { "Varek", "WARRIOR" }, { "Zorik", "HUNTER" }, { "Kael", "MAGE" }, { "Thrall", "SHAMAN" } }
    for i, r in ipairs(roster) do
      p[r[1]] = { class = r[2], dm = 1600000 - i * 120000, hl = (r[2] == "PRIEST" or r[2] == "SHAMAN") and 2100000 - i * 90000 or 20000,
        it = r[2] == "WARRIOR" and 31 - i or 2, dp = r[2] == "PRIEST" and 64 or 3, dt = r[1] == "Zorik" and 6 or 1,
        tk = r[2] == "WARRIOR" and 900000 - i * 10000 or 80000, bc = 3000 + i * 150, bcs = "Fireball" }
    end
    return { zone = "Molten Core", kind = "raid", start = T() - 9660, last = T(), bosses = 10, fights = 34, p = p, sample = true }
  end

  _G.SLASH_PFBOARDS1, _G.SLASH_PFBOARDS2, _G.SLASH_PFBOARDS3 = "/boards", "/lb", "/octoboards"
  _G.SlashCmdList.PFBOARDS = function(msg)
    msg = msg or ""
    if LB.Show then
      if msg ~= "" then LB.Show("player", (string.gsub(msg, "^%l", string.upper))) else LB.Show() end
    end
  end
end)
