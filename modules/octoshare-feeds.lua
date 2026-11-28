pfUI:RegisterModule("octoshare-feeds", "vanilla:tbc", function ()
  -- pfUI Octo :: OctoShare feeds (27 Nov 2026, phase 2). The NEW crowd data that nothing shared before, each one a tiny
  -- record through OctoShare.Emit (prefix pfOS) - so it rides the same throttle-safe governor (paced, silent in combat)
  -- and the same realm channel, and is collected by the master the same way. Off unless C.octoshare.enable = "1".
  --   bgq  a battleground queue popped: how long you waited  ->  "bgq^<map>^<faction>^<seconds>"
  --   bgr  a battleground ended: did your side win            ->  "bgr^<map>^<faction>^<1|0>"
  --   pop  where you are, now and then: an activity heatmap   ->  "pop^<zone>^<faction>"
  --   death  you died: where, your level, what hit you last   ->  "death^<zone>^<level>^<killer>"   (28 Nov 2026)
  --   crit   you beat your own biggest crit / crit heal       ->  "crit^<amount>^<spell>^<dmg|heal>"
  --   hb     heartbeat with the zone ping, realm data bot ONLY ->  "hb^<zone>^<level>^<class>^<ms>^<version>^<status>^<dlls>"
  --          (also sent when the realm bot pings the guild - emp's ping, 28 Nov 2026)
  --   sg     players seen nearby, realm data bot ONLY            ->  "sg^<zone>^<guilds>^<name.level.class.race.guild#,...>"
  -- The master turns these into "queues are fast now", realm PvP win rates and a where-is-everyone heatmap.
  local OS = pfUI.octoshare
  if not OS or not OS.Emit then return end

  local function Faction() return (UnitFactionGroup and UnitFactionGroup("player")) or "?" end
  local function Clean(s) return (string.gsub(s or "", "[%^|,`]", " ")) end   -- keep our separators out of a value

  -- ---------------------------------------------------------------- battlegrounds
  local F = { status = {}, reported = nil }
  OS.feeds = F

  -- queue pop: the moment a queue turns to "confirm", read how long it waited
  function F.CheckQueues()
    for i = 1, 3 do
      local ok, status, map = pcall(GetBattlefieldStatus, i)
      if not ok then status = nil end
      local was = F.status[i]
      if status == "confirm" and was ~= "confirm" then
        local secs = 0
        local ok2, ms = pcall(GetBattlefieldTimeWaited, i)
        if ok2 and ms and ms > 0 then secs = math.floor(ms / 1000) end
        if map and secs > 0 and secs < 36000 then
          OS.Emit("bgq", Clean(map) .. "^" .. Faction() .. "^" .. secs)
        end
      end
      F.status[i] = status
    end
  end

  -- result: when a battleground has a winner, report win / loss once for this match
  function F.CheckResult()
    local ok, winner = pcall(GetBattlefieldWinner)
    if not ok or winner == nil then F.reported = nil return end
    if F.reported then return end
    F.reported = true
    local map = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "?"
    -- winner: 0 = Horde, 1 = Alliance (vanilla). Our side won when it matches our faction.
    local mine = Faction() == "Alliance" and 1 or 0
    OS.Emit("bgr", Clean(map) .. "^" .. Faction() .. "^" .. (winner == mine and 1 or 0))
  end

  -- ---------------------------------------------------------------- population heatmap
  -- one small ping of your zone now and then (default every 6 min). The governor holds it in combat, so it only ever
  -- goes out while you are idle - never in a fight. The master counts pings per zone per hour.
  F.POP_EVERY = 360
  function F.Ping()
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText())
    if not zone or zone == "" then return end
    OS.Emit("pop", Clean(zone) .. "^" .. Faction())
    F.Heartbeat(zone)
  end

  -- ---------------------------------------------------------------- heartbeat (28 Nov 2026)
  -- User (after emp's SuperWoW "ping the guild, clients answer" test): every pfUI Octo player reports, realm-wide, to the
  -- realm's data bot only - pushed with the zone ping, never asked for. pfUI never takes commands from anyone: it only
  -- reports. No machine / account data, just what other players could see or ask: where, level, class, the game's own
  -- latency, the pfUI Octo version and a status.
  --   hb  ->  "hb^<zone>^<level>^<class>^<latency ms>^<pfUI Octo version>^<status>"   status = afk,dnd,bgq,inst or ""
  local function Try(fn, a) if type(fn) ~= "function" then return nil end local ok, r = pcall(fn, a) if ok then return r end end
  -- 1.12 has no UnitIsAFK / UnitIsDND (not in WoW.exe; a DLL may add them): the game's own system lines say it too
  F.afk, F.dnd = false, false
  function F.System(msg)
    if type(msg) ~= "string" then return end
    local m = string.lower(msg)
    if string.find(m, "you are now afk", 1, true) then F.afk = true
    elseif string.find(m, "no longer afk", 1, true) then F.afk = false
    elseif string.find(m, "you are now dnd", 1, true) then F.dnd = true
    elseif string.find(m, "no longer marked dnd", 1, true) or string.find(m, "no longer dnd", 1, true) then F.dnd = false end
  end
  function F.Status()
    local s = {}
    if F.afk or Try(UnitIsAFK, "player") then table.insert(s, "afk") end
    if F.dnd or Try(UnitIsDND, "player") then table.insert(s, "dnd") end
    for i = 1, 3 do
      local ok, st = pcall(GetBattlefieldStatus, i)
      if ok and (st == "queued" or st == "confirm") then table.insert(s, "bgq") break end
    end
    if Try(IsInInstance) then table.insert(s, "inst") end
    return table.concat(s, ",")
  end
  function F.Latency()
    if type(GetNetStats) ~= "function" then return "" end
    local ok, _, _, lat = pcall(GetNetStats)
    lat = ok and tonumber(lat)
    return lat and lat > 0 and lat < 100000 and tostring(math.floor(lat)) or ""
  end
  -- (28 Nov 2026) which client DLLs this game runs, as letters: S SuperWoW, N nampower, C ClassicAPI, U UnitXP SP3.
  -- Only "is it there" (no versions, paths or machine data) - so the boards can show who has what.
  function F.Dlls()
    local s = ""
    if rawget(_G, "SUPERWOW_VERSION") then s = s .. "S" end
    if rawget(_G, "GetNampowerVersion") then s = s .. "N" end
    if rawget(_G, "C_UnitAuras") then s = s .. "C" end
    local lc = pfUI.api and pfUI.api.libclient
    if lc and lc.hasSP3 == nil and lc.Distance then pcall(lc.Distance, "player") end
    if lc and lc.hasSP3 then s = s .. "U" end
    return s
  end
  F.hbAt = 0
  function F.Heartbeat(zone)
    if not OS.EmitBot then return end
    zone = zone or (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    local _, class
    if UnitClass then _, class = UnitClass("player") end
    local ver = pfUI.version and pfUI.version.octo or "?"
    F.hbAt = GetTime and GetTime() or 0
    -- the 7th field (DLL letters) is new in 1.2.90; older workers read only the first six
    OS.EmitBot("hb", Clean(zone) .. "^" .. (UnitLevel and UnitLevel("player") or 0) .. "^" .. Clean(class or "")
      .. "^" .. F.Latency() .. "^" .. Clean(tostring(ver)) .. "^" .. F.Status() .. "^" .. F.Dlls())
  end

  -- ---------------------------------------------------------------- emp's ping (28 Nov 2026)
  -- User: merge emp's "a ping goes out, clients answer" with the heartbeat. The realm data bot sends "ping^<n>" on the
  -- guild addon channel every few minutes; pfUI answers with a heartbeat. Rules: only the realm's hard-set bot is
  -- answered (OS.RealmBot - nobody else can make the guild send), at most once a minute, after a random 2-20 s so a
  -- whole guild does not answer at once, through the governor (never in combat). It only REPORTS: a ping can make pfUI
  -- do nothing else.
  F.pingDue = nil
  function F.Pinged(prefix, msg, chan, sender)
    if prefix ~= OS.PREFIX or chan ~= "GUILD" or type(msg) ~= "string" or string.sub(msg, 1, 5) ~= "ping^" then return end
    local bot = OS.RealmBot and OS.RealmBot()
    if not bot or sender ~= bot then return end
    local now = GetTime and GetTime() or 0
    if now - F.hbAt < 60 or F.pingDue then return end
    F.pingDue = now + 2 + math.random() * 18
  end

  -- ---------------------------------------------------------------- players seen nearby (28 Nov 2026)
  -- User / emp: pfUI players report the OTHER players their game sees, so the realm boards never miss anyone the bots'
  -- /who does not catch. Only what /who already shows: name, level, class, race, guild, and your zone - never positions,
  -- gear or anything inspected. From your target, mouseover and their target, your party, and (with SuperWoW) the
  -- nameplates on screen. Each name at most once per 5 min; sent to the realm data bot only (never guild / raid), in
  -- one compact line of up to ~12 players:
  --   "sg^<zone>^<guild1>;<guild2>...^<name>.<level>.<class>.<race>.<guild#>,<name>...."
  --   class 1-9 = WARRIOR PALADIN HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID; race 1-10 = Human Orc Dwarf NightElf
  --   Scourge Tauren Gnome Troll Goblin BloodElf (High Elf); 0 = unknown. guild# 0 = no guild.
  F.CLASS = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 6, MAGE = 7, WARLOCK = 8, DRUID = 9 }
  F.RACE = { Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Tauren = 6, Gnome = 7, Troll = 8, Goblin = 9,
    BloodElf = 10, HighElf = 10 }
  -- (28 Nov 2026, user: "scan them as players run past and collect data to send us quick ... no addon needed by the
  -- people getting scanned"): the scanned player needs nothing. The scanner's own DLLs find them: ClassicAPI's
  -- NAME_PLATE_UNIT_ADDED the moment a plate appears (and its plate list), SuperWoW's UNIT_CASTEVENT for anyone casting
  -- nearby (GUIDs work as units there), plus target / mouseover / party on a plain client. Sent after 45 s, or at once
  -- when the realm bot pings.
  F.SEEN_AGAIN = 300
  F.SG_MAX = 12
  F.SG_WAIT = 45          -- 45 s (user), not less: the server limits how fast anyone may whisper (a full batch of 12 goes at once)
  F.SG_GAP = 15           -- a full batch never goes sooner than this after the last one
  F.seen, F.seenG, F.sg, F.sgAt, F.sgSent = {}, {}, {}, nil, -1000
  local function Safe(s) return (string.gsub(s or "", "[%^|,`;%.~}]", " ")) end
  -- a GUID seen lately is skipped before any unit call (UNIT_CASTEVENT fires a lot in a fight)
  function F.SightGUID(guid)
    if type(guid) ~= "string" or guid == "" or guid == "0x0000000000000000" then return end
    local now = GetTime and GetTime() or 0
    if F.seenG[guid] and now - F.seenG[guid] < F.SEEN_AGAIN then return end
    F.seenG[guid] = now
    if F.Sight(guid) == "full" then F.seenG[guid] = nil end   -- the batch was full: look again next sweep
  end
  function F.Sight(unit)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitIsPlayer or not UnitIsPlayer(unit) then return end
    if UnitIsUnit and UnitIsUnit(unit, "player") then return end
    local name = UnitName and (UnitName(unit))
    if not name or name == "" or name == UNKNOWNOBJECT or name == "Unknown" then return end
    local now = GetTime and GetTime() or 0
    if F.seen[name] and now - F.seen[name] < F.SEEN_AGAIN then return end
    -- a full batch goes at once, but never sooner than SG_GAP after the last one: in a crowded city the rest simply
    -- wait (not marked seen, so the next sweep finds them again) - the whisper rate to the bot stays capped
    if table.getn(F.sg) >= F.SG_MAX then
      if now - F.sgSent < F.SG_GAP then return "full" end
      F.FlushSightings()
    end
    F.seen[name] = now
    local level = UnitLevel and UnitLevel(unit) or 0
    if level < 0 then level = 0 end
    local _, class, race
    if UnitClass then _, class = UnitClass(unit) end
    if UnitRace then _, race = UnitRace(unit) end           -- the English file name: "NightElf", "Scourge"...
    local guild = GetGuildInfo and (GetGuildInfo(unit)) or ""
    table.insert(F.sg, { Safe(name), level, F.CLASS[class or ""] or 0, F.RACE[race or ""] or 0, Safe(guild) })
    F.sgAt = F.sgAt or now
    if table.getn(F.sg) >= F.SG_MAX and now - F.sgSent >= F.SG_GAP then F.FlushSightings() end
  end
  function F.SightingsLine(zone, list)
    local guilds, gi, rows = {}, {}, {}
    for _, s in ipairs(list) do
      local g = 0
      if s[5] ~= "" then
        if not gi[s[5]] then table.insert(guilds, s[5]) gi[s[5]] = table.getn(guilds) end
        g = gi[s[5]]
      end
      table.insert(rows, s[1] .. "." .. s[2] .. "." .. s[3] .. "." .. s[4] .. "." .. g)
    end
    return Safe(zone) .. "^" .. table.concat(guilds, ";") .. "^" .. table.concat(rows, ",")
  end
  function F.FlushSightings()
    if table.getn(F.sg) == 0 then F.sgAt = nil return end
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    local list = F.sg
    F.sg, F.sgAt = {}, nil
    local now = GetTime and GetTime() or 0
    F.sgSent = now
    if OS.EmitBot then OS.EmitBot("sg", F.SightingsLine(zone, list)) end
    -- forget names not seen for a long while (the table stays small)
    for n, t in pairs(F.seen) do if now - t > F.SEEN_AGAIN * 3 then F.seen[n] = nil end end
    for g, t in pairs(F.seenG) do if now - t > F.SEEN_AGAIN * 3 then F.seenG[g] = nil end end
  end
  -- every nameplate on screen. SuperWoW: a GUID works as a unit - ClassicAPI's GUID list, else pfUI's own plates.
  -- ClassicAPI without SuperWoW: its "nameplateN" tokens.
  function F.ScanPlates()
    local sw = rawget(_G, "SUPERWOW_VERSION")
    local cnp = rawget(_G, "C_NamePlate")
    if sw and type(cnp) == "table" and type(cnp.GetNamePlateGUIDs) == "function" then
      local ok, list = pcall(cnp.GetNamePlateGUIDs)
      if ok and type(list) == "table" then
        for _, guid in pairs(list) do F.SightGUID(guid) end
        return
      end
    end
    if sw then
      local np = pfUI.nameplates
      if np and type(np.registry) == "table" then
        for plate in pairs(np.registry) do
          local parent = plate.parent
          if parent and parent.IsShown and parent:IsShown() and parent.GetName then
            local ok, guid = pcall(parent.GetName, parent, 1)
            if ok then F.SightGUID(guid) end
          end
        end
      end
      return
    end
    if type(cnp) == "table" then
      for i = 1, 40 do F.Sight("nameplate" .. i) end
    end
  end
  -- the realm bot's ping: look at everything around you now, and send it with the heartbeat
  function F.ScanNow()
    F.ScanPlates()
    F.ScanGroup()
    F.Sight("target")
    F.Sight("mouseover")
  end
  function F.ScanGroup()
    for i = 1, 4 do F.Sight("party" .. i) end
  end

  -- ---------------------------------------------------------------- deaths
  -- the last thing that hurt you (combat log, 1.12 English lines), kept 15 s; PLAYER_DEAD reports it. Sent through the
  -- governor, so it waits until you are out of combat like everything else.
  F.lastHit, F.lastHitAt = nil, 0
  function F.Hurt(msg)
    if type(msg) ~= "string" then return end
    local _, _, who = string.find(msg, "^(.+)'s .+ hits you for")
    if not who then _, _, who = string.find(msg, "^(.+)'s .+ crits you for") end
    if not who then _, _, who = string.find(msg, "^(.+) hits you for") end
    if not who then _, _, who = string.find(msg, "^(.+) crits you for") end
    if not who then _, _, who = string.find(msg, "^You suffer %d+ .- damage from (.+)'s ") end
    if who and string.len(who) < 60 then
      F.lastHit, F.lastHitAt = who, (GetTime and GetTime() or 0)
    end
  end
  function F.Died()
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "?"
    local killer = ""
    if F.lastHit and (GetTime and GetTime() or 0) - F.lastHitAt < 15 then killer = F.lastHit end
    OS.Emit("death", Clean(zone) .. "^" .. (UnitLevel and UnitLevel("player") or 0) .. "^" .. Clean(killer))
    F.lastHit = nil
  end

  -- ---------------------------------------------------------------- personal crit records
  -- only a NEW best is sent (kept in pfUI_cache.octoshare.rec), so this is rare: a handful of lines a week
  function F.Records()
    -- (never assign the saved variable itself here: modules run in pfUI's environment, so it would shadow the real one)
    if type(pfUI_cache) ~= "table" then F.recTmp = F.recTmp or {} return F.recTmp end
    if type(pfUI_cache.octoshare) ~= "table" then pfUI_cache.octoshare = {} end
    local d = pfUI_cache.octoshare
    d.rec = type(d.rec) == "table" and d.rec or {}
    return d.rec
  end
  function F.Crit(msg, heal)
    if type(msg) ~= "string" then return end
    local _, spell, amount
    if heal then
      _, _, spell, amount = string.find(msg, "^Your (.+) critically heals .- for (%d+)")
    else
      _, _, spell, amount = string.find(msg, "^Your (.+) crits .- for (%d+)")
      if not spell then
        _, _, amount = string.find(msg, "^You crit .- for (%d+)")
        if amount then spell = "Melee" end
      end
    end
    amount = tonumber(amount)
    if not spell or not amount or amount <= 0 or amount > 100000 then return end
    local kind = heal and "heal" or "dmg"
    local rec = F.Records()
    if amount <= (tonumber(rec[kind]) or 0) then return end
    rec[kind] = amount
    OS.Emit("crit", amount .. "^" .. Clean(spell) .. "^" .. kind)
  end

  -- ---------------------------------------------------------------- events + tick
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
  ev:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
  ev:RegisterEvent("PLAYER_DEAD")
  ev:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
  ev:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
  ev:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS")
  ev:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
  ev:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
  ev:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
  ev:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
  ev:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
  ev:RegisterEvent("CHAT_MSG_SYSTEM")
  ev:RegisterEvent("CHAT_MSG_ADDON")
  ev:RegisterEvent("PLAYER_TARGET_CHANGED")
  ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  ev:RegisterEvent("PARTY_MEMBERS_CHANGED")
  -- the DLLs' own events (a plain client has neither; registering an unknown event is harmless, pcall for safety)
  if rawget(_G, "C_NamePlate") then pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_ADDED") end
  if rawget(_G, "SUPERWOW_VERSION") then pcall(ev.RegisterEvent, ev, "UNIT_CASTEVENT") end
  ev:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SYSTEM" then F.System(arg1) return end
    if not OS.Enabled() then return end
    if event == "NAME_PLATE_UNIT_ADDED" then F.Sight(arg1)
    elseif event == "UNIT_CASTEVENT" then F.SightGUID(arg1) F.SightGUID(arg2)
    elseif event == "CHAT_MSG_ADDON" then F.Pinged(arg1, arg2, arg3, arg4)
    elseif event == "PLAYER_TARGET_CHANGED" then F.Sight("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then F.Sight("mouseover") F.Sight("mouseovertarget")
    elseif event == "PARTY_MEMBERS_CHANGED" then F.ScanGroup()
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then F.CheckQueues()
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then F.CheckResult()
    elseif event == "PLAYER_DEAD" then F.Died()
    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then F.Crit(arg1, false)
    elseif event == "CHAT_MSG_SPELL_SELF_BUFF" then F.Crit(arg1, true)
    else F.Hurt(arg1) end
  end)
  ev:SetScript("OnUpdate", function()
    if not OS.Enabled() then return end
    local now = GetTime and GetTime() or 0
    -- the bot's ping, answered after its random delay
    if F.pingDue and now >= F.pingDue then
      F.pingDue = nil
      F.ScanNow() F.FlushSightings() F.Heartbeat()
    end
    -- sightings: nameplates every 3 s out of combat, and whatever was collected goes out after 45 s
    if (this.plateAt or 0) <= now then
      this.plateAt = now + 3
      if not (UnitAffectingCombat and UnitAffectingCombat("player")) then F.ScanPlates() end
    end
    if F.sgAt and now - F.sgAt >= F.SG_WAIT then F.FlushSightings() end
    if (this.popAt or 0) > now then return end
    this.popAt = now + F.POP_EVERY + math.random() * 60   -- jitter so a whole guild logging in together does not ping at once
    F.Ping()
  end)
end)
